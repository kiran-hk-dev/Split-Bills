import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Cover artwork for a trip.
///
/// Real trips rarely have a `cover_image_url`, and the previous fallback was a
/// flat block of the primary colour, so most of the app was a wall of identical
/// rectangles. This derives a stable, attractive duotone from the trip itself
/// instead, so every trip is visually distinct and colourful while staying
/// inside the app's palette family.
///
/// The hue is deterministic: the same trip always gets the same cover, on any
/// device and across restarts, because it is derived from the country code and
/// name rather than anything random.
///
/// If a cover image *is* set, it is used and the duotone remains the fallback
/// while loading and if the network fails.
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
  });

  /// A photo for the trip, if the user has set one.
  final String? imageUrl;

  /// Stable identity for the trip, e.g. "JP:Tokyo". Drives the colour.
  final String? seed;

  final String? title;
  final String? subtitle;
  final String? leadingEmoji;

  final BorderRadius? borderRadius;

  /// Darkens the lower half so overlaid text stays readable over any photo.
  final bool showScrim;

  /// Curated duotones rather than a free hue.
  ///
  /// A hue derived straight from a hash produces muddy yellows and hot pinks
  /// that fight the navy/teal theme. These pairs are all similar in lightness,
  /// so any of them sits comfortably behind white text.
  static const List<List<Color>> _palettes = <List<Color>>[
    <Color>[Color(0xFF0B4F6C), Color(0xFF0E7490)], // lagoon
    <Color>[Color(0xFF134E4A), Color(0xFF0F766E)], // teal
    <Color>[Color(0xFF1E3A8A), Color(0xFF2563EB)], // deep sea
    <Color>[Color(0xFF4C1D95), Color(0xFF7E22CE)], // dusk
    <Color>[Color(0xFF7C2D12), Color(0xFFEA580C)], // sunset
    <Color>[Color(0xFF831843), Color(0xFFDB2777)], // blossom
    <Color>[Color(0xFF14532D), Color(0xFF16A34A)], // canopy
    <Color>[Color(0xFF3F3F46), Color(0xFF71717A)], // slate
  ];

  /// Deterministic palette index. FNV-1a: small, stable, well distributed.
  static int paletteIndex(String seed) {
    if (seed.isEmpty) return 0;
    int hash = 0x811c9dc5;
    for (final int unit in seed.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash % _palettes.length;
  }

  static List<Color> paletteFor(String seed) =>
      _palettes[paletteIndex(seed)];

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        borderRadius ?? BorderRadius.circular(AppRadius.md);

    final Widget gradient = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: paletteFor(seed ?? ''),
        ),
      ),
      child: const SizedBox.expand(),
    );

    Widget art = gradient;

    final String? url = imageUrl;
    if (url != null && url.isNotEmpty) {
      art = Image.network(
        url,
        fit: BoxFit.cover,
        // The duotone stays visible while loading and if the network fails, so
        // a trip never renders as an empty hole.
        loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? p) =>
            p == null ? child : gradient,
        errorBuilder: (_, _, _) => gradient,
      );
    }

    final bool hasOverlay =
        (title != null && title!.isNotEmpty) ||
        (leadingEmoji != null && leadingEmoji!.isNotEmpty);

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          art,
          if (hasOverlay || showScrim)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    if (!hasOverlay) Colors.transparent
                    else const Color(0x33000000),
                    if (hasOverlay) const Color(0xCC000000) else Colors.transparent,
                  ],
                  stops: const <double>[0.35, 1],
                ),
              ),
            ),
          if (hasOverlay)
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    if (leadingEmoji != null && leadingEmoji!.isNotEmpty) ...[
                      Text(leadingEmoji!, style: const TextStyle(fontSize: 20)),
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
                              ),
                            ),
                          if (subtitle != null && subtitle!.isNotEmpty)
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xDDFFFFFF),
                                fontSize: 12,
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