import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'motion.dart';

/// Cover artwork for a trip.
///
/// Most trips have no `cover_image_url`, and an earlier version fell back to a
/// flat two-colour duotone. That read badly in practice: the palette drifted
/// into teal and cyan next to indigo, so covers looked like two clashing
/// colours rather than one designed surface, and a flat fill has no depth at
/// all.
///
/// This version paints actual artwork:
///
///  * Every palette sits in one narrow violet/indigo/warm family. Trips stay
///    distinguishable from each other without any of them fighting the brand.
///  * Soft overlapping blobs and a vignette give depth, so an empty cover
///    still looks composed rather than blank.
///  * A slow drift animates the light across the artwork, which keeps a list
///    of static cards from reading as a wall of dead rectangles. It respects
///    the reduced-motion preference, and thumbnails do not animate at all.
class TripCover extends StatelessWidget {
  const TripCover({
    super.key,
    this.imageUrl,
    this.seed,
    this.title,
    this.subtitle,
    this.leadingEmoji,
    this.borderRadius,
    this.showScrim = true,
    this.heroTag,
    this.animate = true,
  });

  /// A photo for the trip, if the user has set one.
  final String? imageUrl;

  /// Stable identity for the trip, e.g. "JP:Tokyo". Drives the colour.
  final String? seed;

  final String? title;
  final String? subtitle;
  final String? leadingEmoji;

  final BorderRadius? borderRadius;

  /// Darkens the lower half so overlaid text stays readable over any artwork.
  final bool showScrim;

  /// When set, the cover flies from the list card into the detail page.
  final Object? heroTag;

  /// False for small thumbnails, where an animated painter is not worth the
  /// ticker.
  final bool animate;

  /// One palette per trip, all drawn from the same violet/indigo/warm family.
  ///
  /// Deliberately no teal, green or cyan: next to the indigo brand those hues
  /// read as a second, unrelated colour rather than a shade of the same
  /// surface. Pairs are analogous — neighbouring hues at different lightness —
  /// so the gradient stays one colour that shifts, not two colours that clash.
  static const List<List<Color>> _palettes = <List<Color>>[
    <Color>[Color(0xFF2E2A6E), Color(0xFF5B21B6)], // indigo -> violet
    <Color>[Color(0xFF4C1D95), Color(0xFF7E22CE)], // violet
    <Color>[Color(0xFF1E2F7A), Color(0xFF3B3E8C)], // royal -> indigo
    <Color>[Color(0xFF46205C), Color(0xFF7A2D6F)], // plum -> wine
    <Color>[Color(0xFF242A4A), Color(0xFF413C7A)], // slate -> indigo
    <Color>[Color(0xFF4A1F38), Color(0xFF8A3A5E)], // wine
    <Color>[Color(0xFF2A2352), Color(0xFF6D28D9)], // dusk -> violet
    <Color>[Color(0xFF3F2A46), Color(0xFF8A4B2E)], // ember (the warm one)
  ];

  /// Deterministic palette index.
  ///
  /// FNV-1a alone clustered badly: eight plausible trip names landed on only
  /// five of the eight palettes, so unrelated trips came out the same colour.
  /// The finaliser below is `lowbias32`, chosen because `% 8` reads only the
  /// low bits and FNV's own tail does not mix those well — an earlier xor-shift
  /// pass fixed the high bits but left the low ones still clustered.
  static int paletteIndex(String seed) {
    if (seed.isEmpty) return 0;
    int h = 0x811c9dc5;
    for (final int unit in seed.codeUnits) {
      h ^= unit;
      h = (h * 0x01000193) & 0x7fffffff;
    }
    // lowbias32 avalanche.
    h ^= h >> 16;
    h = (h * 0x7feb352d) & 0x7fffffff;
    h ^= h >> 15;
    h = (h * 0x846ca68b) & 0x7fffffff;
    h ^= h >> 16;
    return h % _palettes.length;
  }

  static List<Color> paletteFor(String seed) => _palettes[paletteIndex(seed)];

  /// A short typographic mark for the trip: the country code when the seed
  /// carries one, otherwise the first letter of the name.
  ///
  /// Always ASCII so it cannot fall back to tofu on a platform without the
  /// glyph.
  static String _monogram(String seed) {
    final String s = seed.trim();
    if (s.isEmpty) return '';

    final int colon = s.indexOf(':');
    final String head = (colon > 0 ? s.substring(0, colon) : s).trim();
    if (colon > 0 && head.length <= 3 && head == head.toUpperCase()) {
      return head;
    }
    return s.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        borderRadius ?? BorderRadius.circular(AppRadius.md);
    final List<Color> colors = paletteFor(seed ?? '');
    final String s = seed ?? '';

    final bool hasOverlay =
        (title != null && title!.isNotEmpty) ||
        (leadingEmoji != null && leadingEmoji!.isNotEmpty);

    final Widget cover = ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _CoverArtwork(colors: colors, seed: s, animate: animate),

          if (imageUrl != null && imageUrl!.isNotEmpty)
            // CrossfadeImage renders nothing if the URL fails, so the painted
            // artwork underneath simply stays rather than being replaced by an
            // error frame.
            Positioned.fill(child: CrossfadeImage(url: imageUrl!)),

          // Large, faint destination mark. Identity without a photo.
          //
          // Initials, not the country flag: Windows has no flag emoji glyphs
          // and renders them as empty boxes, so a flag watermark looked broken
          // on exactly the platform this app is built on.
          if (imageUrl == null || imageUrl!.isEmpty)
            Positioned(
              right: -AppSpacing.sm,
              bottom: -AppSpacing.lg,
              child: IgnorePointer(
                child: Text(
                  _monogram(s),
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 96,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: -4,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
            ),

          // Legibility scrim, only as strong as the overlay needs.
          if (showScrim || hasOverlay)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  // Stops must match the colour count exactly — a gradient
                  // with 3 stops and 2 colours throws at paint time.
                  colors: hasOverlay
                      ? <Color>[
                          Colors.black.withValues(alpha: 0.12),
                          Colors.black.withValues(alpha: 0.30),
                          Colors.black.withValues(alpha: 0.72),
                        ]
                      : <Color>[
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.28),
                        ],
                  stops: hasOverlay
                      ? const <double>[0.0, 0.45, 1.0]
                      : const <double>[0.4, 1.0],
                ),
              ),
            ),

          if (hasOverlay)
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    if (leadingEmoji != null && leadingEmoji!.isNotEmpty) ...[
                      Text(leadingEmoji!, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (title != null && title!.isNotEmpty)
                            Text(
                              title!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                height: 1.15,
                                shadows: <Shadow>[
                                  Shadow(
                                    color: Color(0x66000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          if (subtitle != null && subtitle!.isNotEmpty)
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xD9FFFFFF),
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    if (heroTag == null) return cover;
    return Hero(tag: heroTag!, child: cover);
  }
}

/// The painted fallback artwork shown when a trip has no photo.
///
/// Drawn rather than composed from containers, because overlapping soft-edged
/// blobs and a vignette need a shader — stacking DecoratedBoxes either shows
/// hard edges or costs a saveLayer per blob.
class _CoverArtwork extends StatefulWidget {
  const _CoverArtwork({
    required this.colors,
    required this.seed,
    required this.animate,
  });

  final List<Color> colors;
  final String seed;
  final bool animate;

  @override
  State<_CoverArtwork> createState() => _CoverArtworkState();
}

class _CoverArtworkState extends State<_CoverArtwork>
    with SingleTickerProviderStateMixin {
  /// One full sweep takes this long. Slow on purpose: the drift should be
  /// noticed only if you stare at a card, not read as a loading spinner.
  static const Duration _period = Duration(seconds: 14);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _period,
  );

  /// Deterministic per seed, and built once so the list identity is stable and
  /// [shouldRepaint] can compare it cheaply.
  late final List<_Blob> _blobs = _buildBlobs(widget.seed);

  bool _animate = false;

  static List<_Blob> _buildBlobs(String seed) {
    final math.Random random = math.Random(seed.hashCode);
    return <_Blob>[
      for (int i = 0; i < 3; i++)
        _Blob(
          dx: 0.18 + random.nextDouble() * 0.64,
          dy: 0.15 + random.nextDouble() * 0.6,
          radius: 0.34 + random.nextDouble() * 0.26,
          phase: random.nextDouble() * math.pi * 2,
          strength: 0.16 + random.nextDouble() * 0.12,
          tint: random.nextBool(),
        ),
    ];
  }

  @override
  void initState() {
    super.initState();
    // TickerMode and the reduced-motion flag are both inherited, and reading
    // either from initState registers a dependency Flutter forbids. Both are
    // checked in didChangeDependencies, which runs before the first build.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // TickerMode stops animations for widgets that are off-screen or behind
    // another route, which is exactly what a long trip list needs.
    final bool should =
        widget.animate &&
        !reduceMotionOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (should == _animate) return;
    _animate = should;
    if (_animate) {
      _controller.repeat();
    } else {
      _controller.stop();
      // Park at a flattering point in the sweep rather than at the flat start.
      _controller.value = 0.25;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) => CustomPaint(
        painter: _CoverPainter(
          colors: widget.colors,
          t: _controller.value,
          blobs: _blobs,
        ),
        isComplex: true,
        willChange: _animate,
      ),
    );
  }
}

class _Blob {
  const _Blob({
    required this.dx,
    required this.dy,
    required this.radius,
    required this.phase,
    required this.strength,
    required this.tint,
  });

  final double dx;
  final double dy;
  final double radius;
  final double phase;
  final double strength;

  /// Whether this blob leans toward the palette's light or dark stop.
  final bool tint;
}

class _CoverPainter extends CustomPainter {
  _CoverPainter({
    required this.colors,
    required this.t,
    required this.blobs,
  });

  final List<Color> colors;

  /// Sweep position, 0 to 1.
  final double t;

  final List<_Blob> blobs;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    // Base: one diagonal gradient across the pair.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(rect),
    );

    // Soft blobs. Each drifts on its own sine so they never move in lockstep.
    final double angle = t * 2 * math.pi;
    for (int i = 0; i < blobs.length; i++) {
      final _Blob b = blobs[i];
      final double wobble = math.sin(angle + b.phase) * 0.05;
      final Offset centre = Offset(
        size.width * (b.dx + wobble),
        size.height * (b.dy - wobble * 0.6),
      );
      final double r = size.shortestSide * b.radius;

      canvas.drawCircle(
        centre,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              (b.tint ? Colors.white : Colors.black).withValues(
                alpha: b.strength,
              ),
              (b.tint ? Colors.white : Colors.black).withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: centre, radius: r))
          ..blendMode = b.tint ? BlendMode.plus : BlendMode.srcOver,
      );
    }

    // A second, tighter highlight that sweeps the length of the cover.
    final double sweep = size.width * (t * 1.6 - 0.3);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(sweep / size.width - 0.6, -0.4),
          end: Alignment(sweep / size.width + 0.2, 0.4),
          colors: <Color>[
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const <double>[0.0, 0.5, 1.0],
        ).createShader(rect)
        ..blendMode = BlendMode.plus,
    );

    // Vignette, so overlaid text has a reliably dark corner to sit on.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: <Color>[
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.22),
          ],
          stops: const <double>[0.55, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_CoverPainter old) =>
      old.t != t || old.colors != colors || old.blobs != blobs;
}

/// Small square destination thumbnail, used in lists and detail rows.
class DestinationThumb extends StatelessWidget {
  const DestinationThumb({
    super.key,
    this.imageUrl,
    required this.seed,
    this.emoji,
    this.size = 56,
  });

  final String? imageUrl;
  final String seed;
  final String? emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TripCover(
        imageUrl: imageUrl,
        seed: seed,
        leadingEmoji: emoji,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        // No title: this is a thumbnail, and text at 56px is unreadable.
        showScrim: false,
        // A thumbnail is 56px. An animated painter at that size costs a
        // ticker per row and is invisible anyway.
        animate: false,
      ),
    );
  }
}
