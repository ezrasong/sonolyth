import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:sonolyth/services/logger/logger.dart';
import 'package:xml/xml.dart';

/// TIDAL serves lossless tracks as a DASH (`.mpd`) manifest whose audio is a
/// fragmented-MP4 (fMP4) stream carrying FLAC — an init segment plus N media
/// segments. media_kit's bundled ffmpeg can't reliably open a tokenized `.mpd`
/// directly, so instead of handing mpv the manifest we fetch the segments here
/// and concatenate them (init first) into one continuous fMP4 byte stream,
/// which mpv plays like any ordinary MP4.
///
/// Resolution tags a DASH stream URL with [dashUrlMarker] so the playback
/// server knows to route it through the stitcher ([TidalDashStitcher]) rather
/// than proxying the raw `.mpd`.

/// Prefix stamped on a stream URL to mark it as a TIDAL DASH manifest that must
/// be stitched (not proxied) by the playback server. Not a real URL scheme —
/// it is stripped before the manifest is fetched.
const dashUrlMarker = "x-tidal-dash:";

/// Wraps an `.mpd` manifest URL so the server stitches it.
String markDashUrl(String mpdUrl) => "$dashUrlMarker$mpdUrl";

/// Whether [url] is a stitcher-marked TIDAL DASH manifest URL.
bool isDashUrl(String? url) => url != null && url.startsWith(dashUrlMarker);

/// Recovers the real `.mpd` URL from a [markDashUrl]-marked string.
String stripDashUrl(String url) =>
    url.startsWith(dashUrlMarker) ? url.substring(dashUrlMarker.length) : url;

/// Browser-ish UA for TIDAL manifest/segment fetches. TIDAL's CDN serves its
/// pre-signed URLs to web clients and rejects mpv/ffmpeg's default UA — which
/// is why handing mpv the raw `.mpd` failed. The playback server proxies every
/// segment with this UA so mpv (talking only to localhost) plays DASH natively.
const dashSegmentUserAgent =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/120.0 Safari/537.36";

/// Fetches the raw manifest XML for [mpdUrl] (a plain http(s) URL, or an inline
/// `data:...;base64,` manifest) and returns it with the base URI to resolve
/// segment refs against. Returns a null body when nothing usable was fetched.
Future<(String?, Uri)> loadDashManifestXml(
  Dio dio,
  String mpdUrl, {
  String userAgent = dashSegmentUserAgent,
}) async {
  if (mpdUrl.startsWith("data:")) {
    final comma = mpdUrl.indexOf(',');
    if (comma == -1) return (null, Uri.parse("https://tidal.com/"));
    final meta = mpdUrl.substring(5, comma);
    final payload = mpdUrl.substring(comma + 1);
    final decoded = meta.contains("base64")
        ? utf8.decode(base64.decode(Uri.decodeComponent(payload)))
        : Uri.decodeComponent(payload);
    return (decoded, Uri.parse("https://tidal.com/"));
  }

  final uri = Uri.parse(mpdUrl);
  final res = await dio.get<String>(
    mpdUrl,
    options: Options(
      responseType: ResponseType.plain,
      headers: {"User-Agent": userAgent},
      validateStatus: (s) => s != null && s < 400,
    ),
  );
  var body = res.data ?? "";
  // Some gateways return the manifest base64-wrapped rather than as XML.
  if (!body.contains("<MPD") && !body.trimLeft().startsWith("<")) {
    try {
      body = utf8.decode(base64.decode(body.trim()));
    } catch (_) {/* leave as-is; parse will fail soft */}
  }
  return (body, uri);
}

/// An ordered, absolute list of segment URLs for one DASH audio
/// representation — the init segment first, then the media segments in
/// playback order.
class DashManifest {
  /// Absolute segment URLs, init first. Concatenating their bodies in order
  /// yields a playable fMP4 stream.
  final List<String> segmentUrls;

  const DashManifest(this.segmentUrls);

  bool get isEmpty => segmentUrls.isEmpty;
  bool get isNotEmpty => segmentUrls.isNotEmpty;
}

/// Fetches a TIDAL DASH manifest, resolves its FLAC segment URLs and streams
/// the concatenated segment bytes.
class TidalDashStitcher {
  final Dio _dio;

  TidalDashStitcher([Dio? dio]) : _dio = dio ?? Dio();

  /// A browser-ish UA for the segment/manifest fetches — TIDAL's CDN serves the
  /// pre-signed URLs to web clients.
  static const _userAgent = dashSegmentUserAgent;

  /// Fetches and parses the manifest at [mpdUrl] (a plain http(s) URL, or a
  /// `data:...;base64,` inline manifest) into an ordered segment list. Returns
  /// an empty manifest if nothing usable could be parsed, so callers can fall
  /// through to another source instead of hard-failing playback.
  Future<DashManifest> fetchManifest(String mpdUrl) async {
    final (xmlText, baseUri) = await _loadManifestXml(mpdUrl);
    if (xmlText == null) return const DashManifest([]);
    try {
      final manifest = parseDashManifest(xmlText, baseUri);
      // Dump the raw manifest when we couldn't extract any segments so the
      // actual TIDAL MPD shape lands in .spotube_logs (the parser was written
      // against the common shapes; this surfaces anything unexpected).
      if (manifest.isEmpty) {
        AppLogger.reportError(
          "Tidal DASH parsed 0 segments. MPD:\n${_snippet(xmlText)}",
          StackTrace.current,
        );
      }
      return manifest;
    } catch (e, stack) {
      AppLogger.reportError(
        "Tidal DASH parse error: $e\nMPD:\n${_snippet(xmlText)}",
        stack,
      );
      return const DashManifest([]);
    }
  }

  static String _snippet(String s) =>
      s.length <= 2000 ? s : "${s.substring(0, 2000)}…";

  Future<(String?, Uri)> _loadManifestXml(String mpdUrl) =>
      loadDashManifestXml(_dio, mpdUrl, userAgent: _userAgent);

  /// Streams the concatenated bytes of every segment in [manifest], in order.
  /// Each segment is fetched then yielded, so memory stays at roughly one
  /// segment at a time rather than the whole track.
  Stream<List<int>> streamSegments(DashManifest manifest) async* {
    for (final url in manifest.segmentUrls) {
      final res = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {"User-Agent": _userAgent},
          validateStatus: (s) => s != null && s < 400,
        ),
      );
      final data = res.data;
      if (data != null && data.isNotEmpty) yield data;
    }
  }
}

/// Parses a DASH manifest [xmlText] into an ordered segment list, resolving
/// every URL against [baseUri] (the manifest's own URL) and any `<BaseURL>`.
///
/// Handles the shapes TIDAL emits for FLAC:
///  * `SegmentTemplate` + `SegmentTimeline` (the common multi-segment case);
///  * `SegmentTemplate` with a `duration` attribute (count derived from the
///    presentation duration);
///  * a single-file `Representation` with only a `<BaseURL>`.
DashManifest parseDashManifest(String xmlText, Uri baseUri) {
  final doc = XmlDocument.parse(xmlText);
  final mpd = doc.rootElement;

  // A document-level <BaseURL> rebases everything beneath it.
  Uri base = baseUri;
  final mpdBaseUrl = mpd.getElement("BaseURL")?.innerText.trim();
  if (mpdBaseUrl != null && mpdBaseUrl.isNotEmpty) {
    base = base.resolve(mpdBaseUrl);
  }

  // Pick the audio representation: prefer one whose codecs look like FLAC,
  // else the first representation under an audio AdaptationSet, else any.
  final representations = mpd.findAllElements("Representation").toList();
  if (representations.isEmpty) return const DashManifest([]);

  XmlElement repr = representations.firstWhere(
    (r) => (r.getAttribute("codecs") ?? "").toLowerCase().contains("flac"),
    orElse: () => representations.firstWhere(
      (r) => _adaptationMime(r).contains("audio"),
      orElse: () => representations.first,
    ),
  );

  // A <BaseURL> on the AdaptationSet/Representation rebases again.
  for (final ancestorBase in _baseUrlsFor(repr)) {
    base = base.resolve(ancestorBase);
  }

  final template = repr.getElement("SegmentTemplate") ??
      repr.parentElement?.getElement("SegmentTemplate");

  if (template == null) {
    // No template: a single-file representation served straight from BaseURL.
    return DashManifest([base.toString()]);
  }

  final repId = repr.getAttribute("id") ?? "";
  final bandwidth = repr.getAttribute("bandwidth") ?? "";
  final startNumber =
      int.tryParse(template.getAttribute("startNumber") ?? "1") ?? 1;

  final urls = <String>[];

  final initTemplate = template.getAttribute("initialization");
  if (initTemplate != null && initTemplate.isNotEmpty) {
    urls.add(base
        .resolve(_fillTemplate(initTemplate,
            repId: repId, bandwidth: bandwidth))
        .toString());
  }

  final mediaTemplate = template.getAttribute("media");
  if (mediaTemplate == null || mediaTemplate.isEmpty) {
    return DashManifest(urls);
  }

  // No $Number$/$Time$ placeholder → the media template is itself a single
  // segment URL.
  if (!mediaTemplate.contains(r"$Number")) {
    urls.add(base
        .resolve(
            _fillTemplate(mediaTemplate, repId: repId, bandwidth: bandwidth))
        .toString());
    return DashManifest(urls);
  }

  final segmentCount = _segmentCount(template);
  for (var i = 0; i < segmentCount; i++) {
    final number = startNumber + i;
    urls.add(base
        .resolve(_fillTemplate(
          mediaTemplate,
          repId: repId,
          bandwidth: bandwidth,
          number: number,
        ))
        .toString());
  }

  return DashManifest(urls);
}

/// Number of media segments described by [template] — summed from its
/// `<SegmentTimeline>` (`<S>` entries, honoring the `r` repeat count), or
/// derived from `duration`/`timescale` vs the presentation duration as a
/// fallback. Returns 1 when nothing is parseable (a lone segment).
int _segmentCount(XmlElement template) {
  final timeline = template.getElement("SegmentTimeline");
  if (timeline != null) {
    var count = 0;
    for (final s in timeline.findElements("S")) {
      // r is the number of *additional* repeats; the entry itself counts once.
      final r = int.tryParse(s.getAttribute("r") ?? "0") ?? 0;
      count += 1 + (r < 0 ? 0 : r);
    }
    if (count > 0) return count;
  }

  final duration = double.tryParse(template.getAttribute("duration") ?? "");
  final timescale =
      double.tryParse(template.getAttribute("timescale") ?? "1") ?? 1;
  final totalSeconds = _presentationDurationSeconds(template);
  if (duration != null && duration > 0 && totalSeconds != null) {
    final segSeconds = duration / (timescale == 0 ? 1 : timescale);
    if (segSeconds > 0) return (totalSeconds / segSeconds).ceil();
  }
  return 1;
}

double? _presentationDurationSeconds(XmlElement node) {
  XmlElement? mpd = node;
  while (mpd != null && mpd.name.local != "MPD") {
    mpd = mpd.parentElement;
  }
  final iso = mpd?.getAttribute("mediaPresentationDuration");
  return iso == null ? null : _parseIso8601Duration(iso);
}

/// Parses an ISO-8601 duration like `PT3M21.5S` into seconds.
double? _parseIso8601Duration(String value) {
  final match = RegExp(
    r"P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?",
  ).firstMatch(value);
  if (match == null) return null;
  final days = double.tryParse(match.group(1) ?? "0") ?? 0;
  final hours = double.tryParse(match.group(2) ?? "0") ?? 0;
  final minutes = double.tryParse(match.group(3) ?? "0") ?? 0;
  final seconds = double.tryParse(match.group(4) ?? "0") ?? 0;
  return days * 86400 + hours * 3600 + minutes * 60 + seconds;
}

/// Substitutes DASH `$Identifier$` placeholders. Supports `$RepresentationID$`,
/// `$Bandwidth$` and `$Number$` (including width-padded `$Number%05d$`), plus
/// the literal `$$` escape.
String _fillTemplate(
  String template, {
  required String repId,
  required String bandwidth,
  int? number,
}) {
  var out = template.replaceAll(r"$RepresentationID$", repId);
  out = out.replaceAll(r"$Bandwidth$", bandwidth);
  if (number != null) {
    out = out.replaceAllMapped(
      RegExp(r"\$Number(?:%0(\d+)d)?\$"),
      (m) {
        final width = int.tryParse(m.group(1) ?? "");
        final s = number.toString();
        return width == null ? s : s.padLeft(width, '0');
      },
    );
  }
  return out.replaceAll(r"$$", r"$");
}

String _adaptationMime(XmlElement repr) {
  final reprMime = repr.getAttribute("mimeType");
  if (reprMime != null) return reprMime.toLowerCase();
  return (repr.parentElement?.getAttribute("mimeType") ?? "").toLowerCase();
}

/// `<BaseURL>` values on the representation and its AdaptationSet ancestor,
/// outermost first, for stepwise URL resolution.
Iterable<String> _baseUrlsFor(XmlElement repr) sync* {
  final adaptation = repr.parentElement;
  final adaptationBase = adaptation?.getElement("BaseURL")?.innerText.trim();
  if (adaptationBase != null && adaptationBase.isNotEmpty) yield adaptationBase;
  final reprBase = repr.getElement("BaseURL")?.innerText.trim();
  if (reprBase != null && reprBase.isNotEmpty) yield reprBase;
}
