import 'package:flutter_svg/flutter_svg.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Proxima's own glyphs, rendered from the skin's vector drawables.
///
/// The transport glyphs are the skin's "pro buttons" — `probuttons_*_icon.xml`
/// in Proxima's `res/drawable`, viewport 24 — and their path data is copied
/// here verbatim. Each vector has both a fill (`ProButtonsStartColor`) and a
/// stroke (`ProButtonsStrokeStartColor`, `ProButtonsStrokeWidth` 2.0) and the
/// skin's "Pro Buttons Icon" option picks which is visible:
/// `probuttons_icon_solid` (the `@style/proxima` default) or
/// `probuttons_icon_stroke`. The Zenith screenshot the user pointed at runs
/// **stroke** — the play triangle is an outline with the page showing through
/// — so [ZenithProIcon.outlined] is what the player uses; the solid form stays
/// for anything that wants it. Sizes come from `ProButtonsScale` (0.5) of the
/// base button: play 40dp, prev/next 30dp, as measured off the picture.
///
/// The mini-player pair is `mini_play` / `mini_pause`: a 1.3-wide ring with
/// the glyph *outlined* inside it, which is why it is a separate widget.
///
/// The nav glyphs are `nv_nav_*`, viewport 14, filled `colorIconDisabled`
/// (#55ffffff) at rest and `colorIconPrimary` when their tab is active.
enum ZenithProGlyph { play, pause, prev, next }

class ZenithProIcon extends StatelessWidget {
  const ZenithProIcon(
    this.glyph, {
    super.key,
    required this.size,
    this.color,
    this.outlined = false,
  });

  final ZenithProGlyph glyph;
  final double size;
  final Color? color;

  /// `probuttons_icon_stroke`: transparent fill, the stroke in the glyph
  /// colour. `ProButtonsStrokeWidth` is 2.0 in the 24 viewport; the picture's
  /// strokes measure a shade heavier, which is the vector's round joins.
  final bool outlined;

  static const strokeWidth = 2.2;

  static const _paths = <ZenithProGlyph, String>{
    ZenithProGlyph.play:
        'M21.409,9.353a2.998,2.998 0,0 1,0 5.294L8.597,21.614C6.534,22.736 4,21.276 4,18.968V5.033c0,-2.31 2.534,-3.769 4.597,-2.648l12.812,6.968Z',
    ZenithProGlyph.pause:
        'M2,6c0,-1.886 0,-2.828 0.586,-3.414C3.172,2 4.114,2 6,2c1.886,0 2.828,0 3.414,0.586C10,3.172 10,4.114 10,6v12c0,1.886 0,2.828 -0.586,3.414C8.828,22 7.886,22 6,22c-1.886,0 -2.828,0 -3.414,-0.586C2,20.828 2,19.886 2,18L2,6ZM14,6c0,-1.886 0,-2.828 0.586,-3.414C15.172,2 16.114,2 18,2c1.886,0 2.828,0 3.414,0.586C22,3.172 22,4.114 22,6v12c0,1.886 0,2.828 -0.586,3.414C20.828,22 19.886,22 18,22c-1.886,0 -2.828,0 -3.414,-0.586C14,20.828 14,19.886 14,18L14,6Z',
    ZenithProGlyph.prev:
        'M22,17.574V6.426c0,-1.847 -1.6,-3.015 -2.903,-2.118L13,8.768V7.123c0,-1.616 -1.467,-2.638 -2.661,-1.853L2.92,10.147c-1.228,0.807 -1.228,2.899 0,3.706l7.418,4.877c1.194,0.785 2.661,-0.237 2.661,-1.853v-1.645l6.097,4.46c1.302,0.897 2.903,-0.27 2.903,-2.118Z',
    ZenithProGlyph.next:
        'M2,17.574V6.426C2,4.58 3.6,3.411 4.903,4.308L11,8.768V7.123c0,-1.616 1.467,-2.638 2.661,-1.853l7.417,4.877c1.229,0.807 1.229,2.899 0,3.706l-7.417,4.877c-1.194,0.785 -2.661,-0.237 -2.661,-1.853v-1.645l-6.097,4.46C3.601,20.589 2,19.422 2,17.574Z',
  };

  @override
  Widget build(BuildContext context) {
    final fill = color ?? Theme.of(context).colorScheme.primary;
    final path = outlined
        ? '<path d="${_paths[glyph]}" fill="none" stroke="#FFFFFF" '
            'stroke-width="$strokeWidth" stroke-linejoin="round"/>'
        : '<path d="${_paths[glyph]}" fill="#FFFFFF"/>';
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">$path</svg>',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(fill, BlendMode.srcIn),
    );
  }
}

/// `probuttons_dot_multipurpose_icon` — the small dot Proxima draws for the
/// buttons that flank the transport (its "10s" and "category" slots when set
/// to the dot style): a circle of radius 9.4 on a 34 viewport, stroked at
/// `ProButtonsCatStrokeWidth` 4.0. In the Zenith screenshot it sits at either
/// end of the transport row, dim, the size of a full stop.
class ZenithProDot extends StatelessWidget {
  const ZenithProDot({super.key, required this.size, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? Theme.of(context).colorScheme.primary;
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 34 34">'
      '<path d="M17,17m-9.413,0a9.413,9.413 0,1 1,18.826 0a9.413,9.413 0,1 1,-18.826 0" '
      'fill="#FFFFFF"/></svg>',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(fill, BlendMode.srcIn),
    );
  }
}

/// `header_shuffle` / `header_play` / `header_search` — Proxima's own glyphs
/// for the list header's button row (`ItemHeader*Button_scene_header`), each
/// on a 34 viewport: shuffle is filled, play and search are 3-wide strokes.
/// The picture shows exactly these — an outlined play triangle, a ring-and-tick
/// search — not the app's icon set.
enum ZenithHeaderGlyph { shuffle, play, search }

class ZenithHeaderIcon extends StatelessWidget {
  const ZenithHeaderIcon(
    this.glyph, {
    super.key,
    required this.size,
    required this.color,
  });

  final ZenithHeaderGlyph glyph;
  final double size;
  final Color color;

  static const _shuffle =
      'M27.592,24.316l-3.128,-2.063c-0.287,-0.188 -0.636,-0.205 -0.933,-0.044c-0.33,0.177 -0.534,0.533 -0.534,0.929v0.507c-2.194,-0.52 -4.101,-2.267 -5.016,-4.618l-0.822,-2.032l0.713,-2.017c1.037,-2.397 2.941,-4.107 5.125,-4.623v0.507c0,0.396 0.204,0.752 0.533,0.928c0.297,0.161 0.648,0.145 0.934,-0.043l3.128,-2.064c0.288,-0.19 0.46,-0.52 0.46,-0.885s-0.171,-0.695 -0.46,-0.886l-3.128,-2.064c-0.287,-0.188 -0.635,-0.204 -0.934,-0.043c-0.329,0.177 -0.533,0.533 -0.533,0.929v0.83c-3.182,0.628 -5.904,2.865 -7.241,5.929C14.157,9.781 10.739,7.41 6.899,7.41c-0.523,0 -0.951,0.46 -0.951,1.024v0.728c0,0.565 0.427,1.024 0.963,1.024c2.947,0 5.482,1.832 6.618,4.785L14.349,17l-0.82,2.028c-1.164,2.907 -3.761,4.785 -6.63,4.785c-0.523,0 -0.951,0.46 -0.951,1.023v0.729c0,0.563 0.427,1.023 0.963,1.023c3.726,0 7.217,-2.425 8.841,-6.088c1.374,3.181 4.098,5.424 7.244,5.941v0.823c0,0.396 0.204,0.752 0.533,0.928c0.136,0.074 0.284,0.111 0.43,0.111c0.174,0 0.348,-0.052 0.504,-0.155l3.128,-2.064c0.288,-0.19 0.46,-0.52 0.46,-0.885S27.879,24.506 27.592,24.316z';
  static const _play =
      'M25.891,14.359c1.459,0.776 2.012,2.587 1.237,4.046c-0.28,0.526 -0.711,0.957 -1.237,1.237l-12.783,6.951c-2.058,1.119 -4.587,-0.337 -4.587,-2.64V10.049c0,-2.304 2.528,-3.76 4.587,-2.642L25.891,14.359z';
  static const _searchRing =
      'M7.436,15.754c0,-4.636 3.758,-8.395 8.395,-8.395s8.395,3.758 8.395,8.395s-3.758,8.395 -8.395,8.395S7.436,20.391 7.436,15.754';
  static const _searchTick = 'M25.476,25.551l1.089,1.089';

  @override
  Widget build(BuildContext context) {
    final body = switch (glyph) {
      ZenithHeaderGlyph.shuffle => '<path d="$_shuffle" fill="#FFFFFF"/>',
      ZenithHeaderGlyph.play => '<path d="$_play" fill="none" '
          'stroke="#FFFFFF" stroke-width="3"/>',
      ZenithHeaderGlyph.search => '<path d="$_searchRing" fill="none" '
          'stroke="#FFFFFF" stroke-width="3"/>'
          '<path d="$_searchTick" fill="none" stroke="#FFFFFF" '
          'stroke-width="3" stroke-linecap="round"/>',
    };
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 34 34">$body</svg>',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

/// `mini_play` / `mini_pause` — Proxima's mini-player button: a circle stroked
/// at 1.3 with the play or pause glyph stroked inside it.
class ZenithMiniPlayIcon extends StatelessWidget {
  const ZenithMiniPlayIcon({
    super.key,
    required this.playing,
    required this.size,
    this.color,
  });

  final bool playing;
  final double size;
  final Color? color;

  static const _circle = 'M12,12m-10,0a10,10 0,1 1,20 0a10,10 0,1 1,-20 0';
  static const _play =
      'M15.414,10.941c0.781,0.462 0.781,1.656 0,2.118l-4.72,2.787C9.934,16.294 9,15.71 9,14.786V9.214c0,-0.924 0.934,-1.507 1.694,-1.059l4.72,2.787Z';
  static const _pause =
      'M8,9.5c0,-0.466 0,-0.699 0.076,-0.883a1,1 0,0 1,0.541 -0.54C8.801,8 9.034,8 9.5,8s0.699,0 0.883,0.076a1,1 0,0 1,0.54 0.541c0.077,0.184 0.077,0.417 0.077,0.883v5c0,0.466 0,0.699 -0.076,0.883a1,1 0,0 1,-0.541 0.54C10.199,16 9.966,16 9.5,16s-0.699,0 -0.883,-0.076a1,1 0,0 1,-0.54 -0.541C8,15.199 8,14.966 8,14.5v-5ZM13,9.5c0,-0.466 0,-0.699 0.076,-0.883a1,1 0,0 1,0.541 -0.54C13.801,8 14.034,8 14.5,8s0.699,0 0.883,0.076a1,1 0,0 1,0.54 0.541c0.077,0.184 0.077,0.417 0.077,0.883v5c0,0.466 0,0.699 -0.076,0.883a1,1 0,0 1,-0.541 0.54c-0.184,0.077 -0.417,0.077 -0.883,0.077s-0.699,0 -0.883,-0.076a1,1 0,0 1,-0.54 -0.541C13,15.199 13,14.966 13,14.5v-5Z';

  @override
  Widget build(BuildContext context) {
    final stroke = color ?? Theme.of(context).colorScheme.primary;
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
      'stroke="#FFFFFF" stroke-width="1.3" stroke-linejoin="round">'
      '<path d="$_circle"/><path d="${playing ? _pause : _play}"/></svg>',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(stroke, BlendMode.srcIn),
    );
  }
}

/// `nv_nav_*` — the navbar glyphs. Viewport 14.
enum ZenithNavGlyph { list, search, hamburger, equ }

class ZenithNavIcon extends StatelessWidget {
  const ZenithNavIcon(
    this.glyph, {
    super.key,
    required this.size,
    required this.color,
  });

  final ZenithNavGlyph glyph;
  final double size;
  final Color color;

  static const _paths = <ZenithNavGlyph, String>{
    ZenithNavGlyph.list:
        'M9.29,11.435c-1.182,0 -2.145,-0.962 -2.145,-2.144S8.108,7.146 9.29,7.146s2.144,0.962 2.144,2.145S10.473,11.435 9.29,11.435zM9.29,8.103c-0.654,0 -1.187,0.533 -1.187,1.187s0.533,1.187 1.187,1.187s1.187,-0.533 1.187,-1.187S9.945,8.103 9.29,8.103zM4.71,11.435c-1.183,0 -2.145,-0.962 -2.145,-2.144S3.527,7.146 4.71,7.146S6.854,8.108 6.854,9.29S5.892,11.435 4.71,11.435zM4.71,8.103c-0.654,0 -1.187,0.533 -1.187,1.187s0.532,1.187 1.187,1.187S5.897,9.945 5.897,9.29S5.364,8.103 4.71,8.103zM9.29,6.854c-1.182,0 -2.145,-0.962 -2.145,-2.145S8.108,2.565 9.29,2.565s2.144,0.962 2.144,2.145S10.473,6.854 9.29,6.854zM9.29,3.523c-0.654,0 -1.187,0.532 -1.187,1.187S8.636,5.897 9.29,5.897s1.187,-0.532 1.187,-1.187S9.945,3.523 9.29,3.523zM4.71,6.854c-1.183,0 -2.145,-0.962 -2.145,-2.145S3.527,2.565 4.71,2.565S6.854,3.527 6.854,4.71S5.892,6.854 4.71,6.854zM4.71,3.523c-0.654,0 -1.187,0.532 -1.187,1.187S4.055,5.897 4.71,5.897S5.897,5.364 5.897,4.71S5.364,3.523 4.71,3.523z',
    ZenithNavGlyph.search:
        'M6.537,10.449c-2.174,0 -3.942,-1.768 -3.942,-3.942c0,-2.173 1.768,-3.942 3.942,-3.942s3.942,1.768 3.942,3.942S8.711,10.449 6.537,10.449zM6.537,3.802c-1.492,0 -2.705,1.214 -2.705,2.705s1.214,2.705 2.705,2.705c1.492,0 2.705,-1.214 2.705,-2.705S8.029,3.802 6.537,3.802zM11.224,10.38l-0.431,-0.431c-0.241,-0.242 -0.633,-0.242 -0.874,0c-0.241,0.242 -0.241,0.633 0,0.874l0.431,0.431c0.121,0.121 0.279,0.181 0.437,0.181c0.158,0 0.316,-0.06 0.437,-0.181C11.465,11.012 11.465,10.621 11.224,10.38z',
    ZenithNavGlyph.hamburger:
        'M10.445,3.221h-6.89M10.445,3.877h-6.89c-0.362,0 -0.656,-0.294 -0.656,-0.656s0.294,-0.656 0.656,-0.656h6.889c0.362,0 0.656,0.294 0.656,0.656S10.807,3.877 10.445,3.877zM10.445,7h-6.89M10.445,7.656h-6.89C3.193,7.656 2.899,7.362 2.899,7s0.294,-0.656 0.656,-0.656h6.889C10.806,6.344 11.1,6.638 11.1,7C11.101,7.362 10.807,7.656 10.445,7.656zM10.445,10.779h-6.89M10.445,11.435h-6.89c-0.362,0 -0.656,-0.294 -0.656,-0.656s0.294,-0.656 0.656,-0.656h6.889c0.362,0 0.656,0.294 0.656,0.656S10.807,11.435 10.445,11.435z',
    ZenithNavGlyph.equ:
        'M10.356,10.826V5.289M10.356,11.435c-0.336,0 -0.609,-0.273 -0.609,-0.609V5.289c0,-0.336 0.273,-0.609 0.609,-0.609s0.609,0.273 0.609,0.609v5.536C10.965,11.162 10.693,11.435 10.356,11.435zM7,10.826V3.174M7,11.435c-0.336,0 -0.609,-0.273 -0.609,-0.609V3.174c0,-0.336 0.273,-0.609 0.609,-0.609c0.336,0 0.609,0.273 0.609,0.609v7.652C7.609,11.162 7.336,11.435 7,11.435zM3.644,10.826V7.284M3.644,11.435c-0.336,0 -0.609,-0.273 -0.609,-0.609V7.284c0,-0.336 0.273,-0.609 0.609,-0.609s0.609,0.273 0.609,0.609v3.542C4.253,11.162 3.98,11.435 3.644,11.435z',
  };

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 14 14">'
      '<path d="${_paths[glyph]}" fill="#FFFFFF"/></svg>',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

/// `lb_*` — Proxima's library category glyphs (viewport 24, stroked at 2, no
/// fill), and the `shape_*` tile they sit in.
enum ZenithLibraryGlyph { albums, playlists, artists, folders, allSongs, queue }

class ZenithLibraryIcon extends StatelessWidget {
  const ZenithLibraryIcon(
    this.glyph, {
    super.key,
    required this.size,
    required this.color,
  });

  final ZenithLibraryGlyph glyph;
  final double size;
  final Color color;

  static const _paths = <ZenithLibraryGlyph, List<String>>{
    ZenithLibraryGlyph.albums: [
      'M12,12m-3,0a3,3 0,1 1,6 0a3,3 0,1 1,-6 0',
      'M21.95,13c-0.501,5.054 -4.765,9 -9.95,9c-5.523,0 -10,-4.477 -10,-10c0,-5.185 3.947,-9.448 9,-9.95',
      'M15,2.457a10.024,10.024 0,0 1,6.542 6.542M15,12V2.456',
    ],
    ZenithLibraryGlyph.playlists: [
      'M15,6H3m10,4H3m6,4H3m5,4H3',
      'M17,16.5V8',
      'M14.5,16.5m-2.5,0a2.5,2.5 0,1 1,5 0a2.5,2.5 0,1 1,-5 0',
      'M21,12a4,4 0,0 1,-4 -4',
    ],
    ZenithLibraryGlyph.artists: [
      'M12,6m-4,0a4,4 0,1 1,8 0a4,4 0,1 1,-8 0',
      'M20,17.5c0,2.485 0,4.5 -8,4.5s-8,-2.015 -8,-4.5S7.582,13 12,13s8,2.015 8,4.5Z',
    ],
    ZenithLibraryGlyph.folders: [
      'M18,10h-5',
      'M2,6.95c0,-0.883 0,-1.324 0.07,-1.692A4,4 0,0 1,5.257 2.07C5.626,2 6.068,2 6.95,2c0.386,0 0.58,0 0.766,0.017a4,4 0,0 1,2.18 0.904c0.144,0.119 0.28,0.255 0.554,0.529L11,4c0.816,0.816 1.224,1.224 1.712,1.495a4,4 0,0 0,0.848 0.352C14.098,6 14.675,6 15.828,6h0.374c2.632,0 3.949,0 4.804,0.77c0.079,0.07 0.154,0.145 0.224,0.224c0.77,0.855 0.77,2.172 0.77,4.804V14c0,3.771 0,5.657 -1.172,6.828C19.657,22 17.771,22 14,22h-4c-3.771,0 -5.657,0 -6.828,-1.172C2,19.657 2,17.771 2,14V6.95Z',
    ],
    ZenithLibraryGlyph.allSongs: [
      'M12,18a4,4 0,1 1,-8 0a4,4 0,0 1,8 0Z',
      'M12,18V6',
      'm16.117,10.059l-2.634,-1.317c-0.365,-0.182 -0.547,-0.274 -0.698,-0.389a2,2 0,0 1,-0.75 -1.213C12,6.954 12,6.75 12,6.342c0,-0.971 0,-1.457 0.12,-1.787a2,2 0,0 1,2.112 -1.305c0.348,0.04 0.783,0.258 1.651,0.692l2.634,1.317c0.365,0.182 0.547,0.273 0.698,0.389a2,2 0,0 1,0.75 1.212c0.035,0.187 0.035,0.39 0.035,0.799c0,0.97 0,1.456 -0.12,1.786a2,2 0,0 1,-2.112 1.306c-0.348,-0.04 -0.783,-0.258 -1.651,-0.692Z',
    ],
    ZenithLibraryGlyph.queue: [
      'M15,6L3,6M13,10L3,10M9,14L3,14M8,18L3,18',
      'M17.875,14.118C19.529,15.073 20.355,15.551 20.477,16.239C20.507,16.411 20.507,16.588 20.477,16.76C20.356,17.45 19.529,17.927 17.875,18.881C16.221,19.836 15.395,20.314 14.737,20.075C14.573,20.015 14.42,19.927 14.286,19.814C13.75,19.364 13.75,18.41 13.75,16.5C13.75,14.59 13.75,13.635 14.286,13.186C14.42,13.074 14.573,12.986 14.737,12.926C15.394,12.686 16.221,13.164 17.875,14.118Z',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final paths = _paths[glyph]!.map((d) => '<path d="$d"/>').join();
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
      'stroke="#FFFFFF" stroke-width="2" stroke-linecap="round" '
      'stroke-linejoin="round">$paths</svg>',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

/// `shape_<category>` as `ItemTextAAImage` draws it: a 36dp tile (the 48dp
/// drawable scaled into the 36dp view) with the glyph inset 8/48 of it.
///
/// In `@style/proxima` the tile's gradient and the glyph's stroke are *both*
/// `GradientStartColor` (= `colorIconPrimary`, white), which only works with
/// one of the "Library Shape Style" overlays on top: the screenshots run the
/// **Faded** one (`LibraryShapeColorOverlayFaded` = `#cc000000`, black at 80%
/// over the accent), which is what leaves a dark tile with an accent-coloured
/// glyph. That is the tile here: the accent at 20% over black, glyph in the
/// accent. Corners follow the screenshots' rounded-square preset rather than
/// the default `libraryShapeCorners*` 30dp, which on a 36dp tile is a circle.
class ZenithLibraryTile extends StatelessWidget {
  const ZenithLibraryTile({super.key, required this.glyph});

  final ZenithLibraryGlyph glyph;

  static const size = 36.0;
  static const radius = 10.0;
  static const glyphSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          primary.withValues(alpha: 0.2),
          const Color(0xFF000000),
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: ZenithLibraryIcon(glyph, size: glyphSize, color: primary),
    );
  }
}

/// `header_library_back` — the list header's back decor: a thin ring (stroke
/// 0.75 of a 12 viewport, at 70%) with a chevron inside. Tinted the accent.
class ZenithHeaderBackIcon extends StatelessWidget {
  const ZenithHeaderBackIcon({
    super.key,
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 12 12" fill="none" '
      'stroke="#FFFFFF" stroke-width="0.75" stroke-linecap="round" '
      'stroke-linejoin="round">'
      '<path d="M6,6m-3.446,0a3.446,3.446 0,1 1,6.892 0a3.446,3.446 0,1 1,-6.892 0" '
      'stroke-opacity="0.7"/>'
      '<path d="M6.696,4.609L5.304,6l1.391,1.391"/></svg>',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

/// `meta_song` — the 12dp note that leads Poweramp's `ItemTrackMeta` line
/// ("♪ 3:23 | flac | 24 bit"): an open note head, its stem at 80% alpha and a
/// rounded flag, all stroked at 1dp on a 12 viewport. `ItemTrackMeta` sets
/// `drawableHeight` 12dp and tints it `colorTrackMeta`, the same 50% the text
/// beside it wears.
class ZenithMetaNoteIcon extends StatelessWidget {
  const ZenithMetaNoteIcon({
    super.key,
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 12 12" fill="none" '
      'stroke="#FFFFFF" stroke-width="1">'
      '<path d="M6,8.382c0,1.105 -0.895,2 -2,2s-2,-0.895 -2,-2s0.895,-2 2,-2S6,7.277 6,8.382z"/>'
      '<path d="M6,8.382v-6" stroke-opacity="0.8"/>'
      '<path d="M8.059,4.411L6.742,3.753C6.559,3.662 6.468,3.616 6.393,3.558C6.197,3.409 6.064,3.193 6.018,2.952C6,2.859 6,2.757 6,2.553c0,-0.486 0,-0.728 0.06,-0.893c0.158,-0.436 0.595,-0.706 1.056,-0.652c0.174,0.02 0.391,0.129 0.826,0.346l1.317,0.658c0.182,0.091 0.274,0.137 0.349,0.194c0.195,0.149 0.329,0.365 0.375,0.606C10,2.905 10,3.007 10,3.211c0,0.485 0,0.728 -0.06,0.893C9.782,4.541 9.345,4.811 8.884,4.757C8.71,4.737 8.493,4.628 8.059,4.411z" '
      'stroke-linecap="round"/></svg>',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

/// `header_menu` — the list header's menu glyph: two filled dots, one above
/// the other, on a 34 viewport. Tinted the accent.
class ZenithHeaderMenuIcon extends StatelessWidget {
  const ZenithHeaderMenuIcon({
    super.key,
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 34 34" fill="#FFFFFF">'
      '<path d="M17,23.084m-4.161,0a4.161,4.161 0,1 1,8.322 0a4.161,4.161 0,1 1,-8.322 0"/>'
      '<path d="M17,10.916m-4.161,0a4.161,4.161 0,1 1,8.322 0a4.161,4.161 0,1 1,-8.322 0"/></svg>',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
