import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'motion.dart';

/// Marks a bundled cover inside [TripCover.imageUrl].
///
/// Uploading a real photo needs a storage bucket and a migration that has not
/// been applied, which left every trip with painted artwork and no way to
/// choose anything. A bundled cover is just a string in the column that
/// already exists, so it works today and needs no schema change. The two forms
/// coexist: whichever the field holds, the cover renders it.
const String assetCoverPrefix = 'asset:';

/// The cover illustrations bundled with the app.
class TripCovers {
  const TripCovers._();

  /// Asset path and display name, in the order they are offered.
  static const List<({String path, String label})> options =
      <({String path, String label})>[
    (path: 'assets/covers/cover_dawn.jpg', label: 'Dawn'),
    (path: 'assets/covers/cover_dusk.jpg', label: 'Dusk'),
    (path: 'assets/covers/cover_desert.jpg', label: 'Desert'),
    (path: 'assets/covers/cover_coast.jpg', label: 'Coast'),
    (path: 'assets/covers/cover_forest.jpg', label: 'Forest'),
    (path: 'assets/covers/cover_rose.jpg', label: 'Rose'),
    (path: 'assets/covers/wonder_giza.jpg', label: 'Great Pyramid'),
    (path: 'assets/covers/wonder_babylon.jpg', label: 'Hanging Gardens'),
    (path: 'assets/covers/wonder_artemis.jpg', label: 'Temple of Artemis'),
    (path: 'assets/covers/wonder_zeus.jpg', label: 'Statue of Zeus'),
    (path: 'assets/covers/wonder_mausoleum.jpg', label: 'Mausoleum'),
    (path: 'assets/covers/wonder_colossus.jpg', label: 'Colossus of Rhodes'),
    (path: 'assets/covers/wonder_pharos.jpg', label: 'Lighthouse of Alexandria'),
  ];

  /// The value to store in `cover_image_url` for a bundled cover.
  static String urlFor(String assetPath) => '$assetCoverPrefix$assetPath';

  /// The asset path behind a stored cover value, or null if it is a photo URL.
  static String? bundledPathOf(String? coverImageUrl) {
    if (coverImageUrl == null ||
        !coverImageUrl.startsWith(assetCoverPrefix)) {
      return null;
    }
    return coverImageUrl.substring(assetCoverPrefix.length);
  }

  static String labelForPath(String assetPath) {
    for (final ({String path, String label}) o in options) {
      if (o.path == assetPath) return o.label;
    }
    return 'Cover';
  }
}

/// Cover artwork for a trip.
///
/// This is the fallback surface, shown when a trip has no
/// `cover_image_url`. A trip with a real photo lays that photo over the top of
/// this, so the artwork is never seen on one.
///
/// An earlier version fell back to a flat two-colour duotone, which read as
/// two clashing colours rather than one designed surface, and had no depth.
/// This version paints actual artwork:
///
///  * Every cover is a single hue, shaded only by lightness. Depth comes from
///    the ramp, not from a second colour.
///  * Soft overlapping blobs and a vignette give it composition, so an empty
///    cover still looks composed rather than blank.
///  * A slow drift animates the light, which keeps a list of static cards
///    from reading as a wall of dead rectangles. It respects the reduced-motion
///    preference, and thumbnails do not animate at all.
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

  /// One colour per trip, drawn from the warm ember family.
  ///
  /// Each cover used to be a gradient across a *pair* of hues. That was
  /// defended in a comment as "one colour that shifts", but from the outside a
  /// maroon-to-crimson cover is plainly two colours, and two colours on one
  /// surface is what made the grid look busy rather than varied. A trip now
  /// gets a single hue; the gradient below is built by shifting only that
  /// hue's lightness, so the cover still has depth and stays unmistakably one
  /// colour.
  ///
  /// Deliberately no green or amber: beside the blue brand those hues
  /// read as a second, unrelated colour rather than a shade of the same
  /// surface.
  ///
  /// Distinguishability comes from **lightness**, not hue: the whole warm arc
  /// is only about 60 degrees wide, so eight colours distinguished by hue
  /// alone would look identical. These range from near-espresso to bright
  /// amber.
  static const List<Color> _baseColors = <Color>[
    Color(0xFF0C4A6E), // deep navy
    Color(0xFF075985), // deep sky
    Color(0xFF0369A1), // sky
    Color(0xFF155E75), // cyan, deep
    Color(0xFF0E7490), // cyan
    Color(0xFF0284C7), // sky, bright
    Color(0xFF0EA5E9), // sky, light
    Color(0xFF1E40AF), // blue
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
    return h % _baseColors.length;
  }

  /// The trip's single colour.
  static Color colorFor(String seed) => _baseColors[paletteIndex(seed)];

  /// Lightness shades of [colorFor], darkest to lightest.
  ///
  /// Hue is held exactly constant across the stops, which is the point: the
  /// cover must read as one colour. Saturation eases off on the light stop so
  /// a deep base does not turn muddy when it is brightened.
  static List<Color> paletteFor(String seed) {
    final HSLColor hsl = HSLColor.fromColor(colorFor(seed));
    Color at(double delta) {
      final double saturation =
          delta > 0 ? hsl.saturation * 0.9 : hsl.saturation;
      return HSLColor.fromAHSL(
        hsl.alpha,
        hsl.hue,
        saturation,
        (hsl.lightness + delta).clamp(0.06, 0.86),
      ).toColor();
    }

    return <Color>[at(-0.11), at(0.0), at(0.15)];
  }

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

    // A subtitle counts as an overlay. It used not to, so a cover given only a
    // subtitle drew no scrim and no text at all — the date range on a trip card
    // was silently invisible.
    final bool hasOverlay =
        (title != null && title!.isNotEmpty) ||
        (subtitle != null && subtitle!.isNotEmpty) ||
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
            //
            // A bundled cover is stored with an "asset:" prefix rather than a
            // URL. That keeps the choice in the same column as an uploaded
            // photo, so one field covers both and neither needs a migration.
            Positioned.fill(
              child: imageUrl!.startsWith(assetCoverPrefix)
                  ? Image.asset(
                      imageUrl!.substring(assetCoverPrefix.length),
                      fit: BoxFit.cover,
                      // Bundled, so a miss is a packaging bug rather than a
                      // network problem; falling back keeps the cover usable.
                      errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
                          const SizedBox.shrink(),
                    )
                  : CrossfadeImage(url: imageUrl!),
            ),

          // Ghosted destination mark, scaled to the cover.
          //
          // It used to be a fixed 96px pinned off two edges. On a 700x300
          // dashboard hero that clipped the letters into two meaningless bars
          // in the corner, so it now scales with the cover and sits fully
          // inside it.
          if (imageUrl == null || imageUrl!.isEmpty)
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double markSize =
                    (constraints.biggest.shortestSide * 0.42).clamp(28, 132);
                return Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: IgnorePointer(
                      child: Text(
                        _monogram(s),
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: markSize,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          letterSpacing: -2,
                          color: Colors.white.withValues(alpha: 0.09),
                        ),
                      ),
                    ),
                  ),
                );
              },
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

  bool _animate = false;

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
          seed: widget.seed,
        ),
        isComplex: true,
        willChange: _animate,
      ),
    );
  }
}

/// Paints the fallback cover: a flat landscape in the trip's own hue.
///
/// This replaces a pile of radial gradient blobs. Those were meant to supply
/// depth and read instead as a coloured smudge — on a large dashboard hero a
/// single blob filled most of the card and looked like a rendering fault
/// rather than like artwork. A landscape is recognisable at a glance and
/// holds its character from a 56px thumbnail up to a 700px hero.
class _CoverPainter extends CustomPainter {
  _CoverPainter({
    required this.colors,
    required this.t,
    required this.seed,
  }) : _ridges = _buildRidges(seed);

  final List<Color> colors;

  /// Sweep position, 0 to 1.
  final double t;

  final String seed;

  /// Ridge heights per layer, 0 to 1.
  ///
  /// Built once in the constructor. Deriving them inside [paint] would reshuffle
  /// the landscape on every animation frame, because each frame would consume
  /// a fresh random sequence.
  final List<List<double>> _ridges;

  /// The trip's own hue, taken as the middle stop of its three-stop ramp.
  late final HSLColor base = HSLColor.fromColor(
    colors.length > 1 ? colors[colors.length ~/ 2] : colors.first,
  );

  static List<List<double>> _buildRidges(String seed) {
    const int points = 5;
    final List<List<double>> layers = <List<double>>[];
    for (int layer = 0; layer < 3; layer++) {
      final math.Random random = math.Random(
        seed.hashCode ^ (layer * 0x9E3779B1),
      );
      layers.add(<double>[
        for (int i = 0; i < points; i++) random.nextDouble(),
      ]);
    }
    return layers;
  }

  /// Scales the base hue's lightness by [factor].
  ///
  /// Multiplicative rather than additive on purpose. An additive offset has to
  /// be clamped to stay in range, and for the darker hues in the palette —
  /// crimson, rust, sepia — the clamp bound first, so the front ridge landed on
  /// the same near-black floor for three different trips and swallowed the
  /// bottom of the cover. Scaling keeps the depth identical across all eight
  /// hues without clamping at all.
  Color tint(double factor, {double saturation = 1}) => HSLColor.fromAHSL(
    base.alpha,
    base.hue,
    (base.saturation * saturation).clamp(0.0, 1.0),
    (base.lightness * factor).clamp(0.05, 0.96),
).toColor();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    // Sky: darker overhead, brightening towards the horizon.
    //
    // Brightening downwards rather than upwards is what makes this read as a
    // landscape. A top-light sky and a bottom-light set of ridges merge into
    // one dark mass, which is what the first version of this painter did.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            tint(1.02, saturation: 0.72),
            tint(1.30, saturation: 0.92),
            tint(1.62, saturation: 0.52),
          ],
          stops: const <double>[0.0, 0.62, 1.0],
        ).createShader(rect),
    );

    // Sun, drifting slowly. Moving it against the ridges is what makes the
    // drift read as depth rather than as a change of colour.
    final double sunX =
        size.width * (0.28 + 0.055 * math.sin(t * 2 * math.pi));
    final double sunY = size.height * 0.27;
    final double sunR = size.shortestSide * 0.145;
    canvas.drawCircle(
      Offset(sunX, sunY),
      sunR * 2.2,
      Paint()..color = tint(1.62, saturation: 0.5).withValues(alpha: 0.28),
    );
    canvas.drawCircle(
      Offset(sunX, sunY),
      sunR,
      Paint()..color = tint(2.05, saturation: 0.30),
    );

    // Three ridges: each sits lower and darker than the one behind it.
    final double phase = t * 2 * math.pi;
    for (int layer = 0; layer < _ridges.length; layer++) {
      final List<double> heights = _ridges[layer];
      final double baseline = size.height * (0.63 + layer * 0.105);
      final double amplitude = size.height * (0.12 - layer * 0.028);
      final double drift = math.sin(phase + layer * 1.3) * size.width * 0.010;

      final Path ridge = Path()..moveTo(-size.width * 0.08, size.height);
      for (int i = 0; i < heights.length; i++) {
        ridge.lineTo(
          -size.width * 0.08 +
              size.width * 1.16 * (i / (heights.length - 1)) +
              drift,
          baseline + (heights[i] - 0.5) * amplitude * 2,
        );
      }
      ridge
        ..lineTo(size.width * 1.16, size.height)
        ..close();

      canvas.drawPath(
        ridge,
        Paint()
          ..color = tint(
            0.88 - layer * 0.13,
            saturation: 1.08 - layer * 0.16,
          ),
      );
    }

    // Vignette, so overlaid text always has a reliably dark corner to sit on.
    // Kept light: the scrim above the artwork already darkens the bottom
    // third when there is text, and the dashboard card has no text on the
    // cover at all.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: <Color>[
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.16),
          ],
          stops: const <double>[0.58, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_CoverPainter old) =>
      old.t != t || old.colors != colors || old.seed != seed;
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
