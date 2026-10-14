import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'motion.dart';

/// Cover artwork for a trip.
///
/// Real trips rarely have a `cover_image_url`. The first attempt at a fallback
/// used eight saturated duotones and looked like a paint chart: hot purple,
/// bright green and burnt orange fought the navy/teal theme, and the hash put
/// two unrelated trips on the same colour.
///
/// This version is deliberately quiet:
///
///  * Every palette is dark and desaturated, so white overlay text is always
///    legible and the set reads as one family.
///  * Hues are drawn from a narrow band around the brand ramp — indigo,
///    violet, teal and cyan, plus a slate and a plum to break it up — rather
///    than the full wheel.
///  * A soft radial highlight and a large, low-opacity destination mark give
///    depth and per-trip identity without shouting.
///  * The palette index uses a finalising mix step, so adjacent-looking seeds
///    do not land on the same colour.
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

  /// Dark, desaturated duotones drawn from the brand ramp. All sit in a
  /// similar lightness range on purpose: that is what keeps white text
  /// readable and the set cohesive.
  static const List<List<Color>> _palettes = <List<Color>>[
    <Color>[Color(0xFF312E81), Color(0xFF4338CA)], // indigo
    <Color>[Color(0xFF4C1D95), Color(0xFF6D28D9)], // violet
    <Color>[Color(0xFF0F4C46), Color(0xFF0D7368)], // teal
    <Color>[Color(0xFF0C4A6E), Color(0xFF0E7490)], // cyan
    <Color>[Color(0xFF1E3A8A), Color(0xFF1D4ED8)], // royal
    <Color>[Color(0xFF4A2358), Color(0xFF6B3080)], // plum
    <Color>[Color(0xFF2B3350), Color(0xFF3C4668)], // slate
    <Color>[Color(0xFF064E3B), Color(0xFF047857)], // pine
  ];

  /// Deterministic palette index.
  ///
  /// FNV-1a alone clustered: several plausible trip names hashed into the same
  /// slot. The finalising multiply-xor spreads neighbouring inputs without
  /// making the mapping any less stable.
  static int paletteIndex(String seed) {
    if (seed.isEmpty) return 0;
    int h = 0x811c9dc5;
    for (final int unit in seed.codeUnits) {
      h ^= unit;
      h = (h * 0x01000193) & 0x7fffffff;
    }
    // Final avalanche step.
    h ^= h >> 15;
    h = (h * 0x2c1b3c6d) & 0x7fffffff;
    h ^= h >> 12;
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
    final BorderRadius radius = borderRadius ?? BorderRadius.circular(AppRadius.md);
    final List<Color> colors = paletteFor(seed ?? '');
    final String s = seed ?? '';

    Widget art = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: const SizedBox.expand(),
    );

    final String? url = imageUrl;
    if (url != null && url.isNotEmpty) {
      // CrossfadeImage renders nothing at all if the URL fails, so the duotone
      // underneath simply stays. The previous Image.network painted over it
      // with an error frame the moment it gave up.
      art = CrossfadeImage(url: url, fit: BoxFit.cover);
    }

    final bool hasOverlay =
        (title != null && title!.isNotEmpty) ||
        (leadingEmoji != null && leadingEmoji!.isNotEmpty);

    final Widget cover = ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          art,

          // Soft top-left highlight for depth. Keeps a flat duotone from
          // looking like an empty rectangle.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.7, -0.9),
                radius: 1.3,
                colors: <Color>[
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),

          // Large, faint destination mark. Identity without a photo.
          //
          // Initials, not the country flag: Windows has no flag emoji glyphs
          // and renders them as empty boxes, so a flag watermark looked broken
          // on exactly the platform this app is built on. Letters always render.
          if (imageUrl == null || imageUrl!.isEmpty)
            Positioned(
              right: -AppSpacing.sm,
              top: -AppSpacing.sm,
              child: IgnorePointer(
                child: Text(
                  _monogram(s),
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.09),
                  ),
                ),
              ),
            ),

          // Legibility scrim. Stronger than before: white text sat on bright
          // fills and was hard to read.
          if (showScrim || hasOverlay)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    if (!hasOverlay)
                      Colors.transparent
                    else
                      Colors.black.withValues(alpha: 0.18),
                    if (hasOverlay) Colors.black.withValues(alpha: 0.62) else Colors.transparent,
                  ],
                  stops: const <double>[0.30, 1],
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
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                height: 1.15,
                              ),
                            ),
                          if (subtitle != null && subtitle!.isNotEmpty)
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
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

    // Flies the artwork from the trip card into the detail page, so tapping a
    // trip reads as opening that trip rather than swapping one screen for
    // another.
    if (heroTag == null) return cover;
    return Hero(tag: heroTag!, child: cover);
  }
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
      ),
    );
  }
}