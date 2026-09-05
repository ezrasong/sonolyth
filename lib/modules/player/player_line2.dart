import 'package:flutter/gestures.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:sonolyth/components/links/artist_link.dart';
import 'package:sonolyth/extensions/context.dart';
import 'package:sonolyth/models/metadata/metadata.dart';

/// Line 2 of the AA scene — "artist, artist - album" — as **one** line.
///
/// It used to be a `Row` holding a `Flexible` [ArtistLink] beside a `Flexible`
/// album `Text`, and an `ArtistLink` is a **`Wrap`**. Given a long credit list
/// the two runs wrapped *independently*: "Junggigo, Crush, DEAN," stacked onto
/// three lines while "- ACROSS THE UNI…" floated beside the first of them, at
/// 100% as readily as at 200% (§42d). Poweramp's line 2 is a single ellipsised
/// line, and the artists have to stay tappable, so the line is one
/// `Text.rich`: a span per artist carrying its own recognizer, the album as a
/// plain span, `maxLines: 1`. One paragraph cannot disagree with itself about
/// where it ends.
class PlayerLine2 extends StatefulWidget {
  const PlayerLine2({
    super.key,
    required this.artists,
    required this.album,
    required this.style,
    required this.onArtistTap,
    required this.onOverflowTap,
  });

  final List<SonolythSimpleArtistObject> artists;
  final String album;
  final TextStyle style;

  /// Passed the artist's route, matching [ArtistLink.onRouteChange] — the
  /// player closes its scene before navigating.
  final void Function(String route) onArtistTap;
  final VoidCallback onOverflowTap;

  @override
  State<PlayerLine2> createState() => _PlayerLine2State();
}

class _PlayerLine2State extends State<PlayerLine2> {
  /// Held rather than built inline: a `TapGestureRecognizer` owns a timer and
  /// must be disposed, and building one per `build` leaks a recognizer per
  /// frame — the player rebuilds on every position tick.
  List<TapGestureRecognizer> _recognizers = const [];

  /// [ArtistLink] shows three names and folds the rest into "and N more".
  static const _visibleArtists = 3;

  int get _spanCount =>
      widget.artists.take(_visibleArtists).length +
      (widget.artists.length > _visibleArtists ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _buildRecognizers();
  }

  @override
  void didUpdateWidget(PlayerLine2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_spanCount != _recognizers.length) _buildRecognizers();
    _wireRecognizers();
  }

  void _buildRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers =
        List.generate(_spanCount, (_) => TapGestureRecognizer(), growable: false);
    _wireRecognizers();
  }

  /// The handlers close over the *current* track, so they are re-pointed on
  /// every update — the recognizers themselves survive a track change.
  void _wireRecognizers() {
    final visible = widget.artists.take(_visibleArtists).toList();
    for (var i = 0; i < _recognizers.length; i++) {
      _recognizers[i].onTap = i < visible.length
          ? () => widget.onArtistTap("/artist/${visible[i].id}")
          : widget.onOverflowTap;
    }
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visible = widget.artists.take(_visibleArtists).toList();

    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < visible.length; i++)
            TextSpan(
              // The separator belongs to the name before it, so a tap on the
              // comma is still a tap on that artist — the same run
              // `AnchorButton` carried.
              text: i == widget.artists.length - 1
                  ? visible[i].name
                  : "${visible[i].name}, ",
              recognizer: _recognizers[i],
            ),
          if (widget.artists.length > _visibleArtists)
            TextSpan(
              text: context.l10n.and_n_more(
                widget.artists.length - _visibleArtists,
              ),
              style: TextStyle(
                color: colorScheme.secondary,
                decoration: TextDecoration.underline,
              ),
              recognizer: _recognizers.last,
            ),
          if (widget.album.isNotEmpty)
            TextSpan(
              text: " - ${widget.album}",
              // A span carrying a recognizer becomes its own semantics node, so
              // the album is always announced as a separate fragment — and it
              // was being announced as "dash ACROSS THE UNIVERSE" (§43g). The
              // hyphen is a *visual* separator between two runs on one line;
              // spoken, it is only noise.
              semanticsLabel: widget.album,
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: widget.style,
    );
  }
}
