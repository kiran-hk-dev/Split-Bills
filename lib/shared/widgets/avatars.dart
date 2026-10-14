import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/expense.dart';
import 'motion.dart';

/// Compact avatar that shows initials when there is no image, so members are
/// always distinguishable without loading remote images.
///
/// The initials are always painted. They previously gave way to
/// [DecorationImage] the moment a URL was present, so a slow avatar was a
/// blank circle with no fill and no text, and a broken one stayed that way
/// forever — [DecorationImage.onError] was a no-op. Now the photo fades in
/// over the initials and, if it never arrives, the initials are what is left.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    this.initials,
    this.imageUrl,
    this.size = 40,
    this.highlight = false,
    this.semanticLabel,
  });

  final String? initials;
  final String? imageUrl;
  final double size;
  final bool highlight;

  /// Overrides the announced label. Without this every member announced as
  /// "Member avatar", which is useless on a screen listing six of them.
  final String? semanticLabel;

  /// Categorical avatar fills.
  ///
  /// All of these sit at 4.5:1 or better against the 14%-alpha tint drawn
  /// behind the initials in both light and dark mode, so the monogram stays
  /// legible whichever theme is active.
  static const List<Color> _palette = <Color>[
    Color(0xFF0F766E), // teal
    Color(0xFF1D4ED8), // blue
    Color(0xFFA44808), // amber
    Color(0xFF7C3AED), // violet
    Color(0xFF0E7490), // cyan
    Color(0xFFBE185D), // pink
  ];

  static Color _baseFor(String text) =>
      _palette[text.codeUnits.fold<int>(0, (int a, int b) => a + b) % _palette.length];

  /// Initials reduced to at most two characters, with an empty string mapped to
  /// a question mark so an unnamed member is still visible.
  static String _normalise(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.length <= 2 ? trimmed : trimmed.substring(0, 2);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String text = (initials ?? '').trim();
    final String shown = _normalise(text);
    final Color base = _baseFor(text.isEmpty ? '?' : text);
    final bool dark = theme.brightness == Brightness.dark;

    // In dark mode the 14% tint of a mid-tone hue over a near-black surface is
    // almost invisible, so the fill is lifted instead.
    final Color fill = dark
        ? Color.lerp(base, Colors.white, 0.22)!.withValues(alpha: 0.26)
        : base.withValues(alpha: 0.14);
    final Color foreground = dark
        ? Color.lerp(base, Colors.white, 0.45)!
        : base;

    final String? url = imageUrl;
    final bool hasImage = url != null && url.isNotEmpty;

    final Widget circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(
          color: highlight
              ? theme.colorScheme.primary
              : base.withValues(alpha: dark ? 0.45 : 0.28),
          width: highlight ? 2 : 1,
        ),
      ),
      alignment: Alignment.center,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: <Widget>[
          // Always present, under the photo.
          Center(
            child: Text(
              shown,
              style: theme.textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.36,
              ),
            ),
          ),
          if (hasImage)
            ClipOval(
              child: CrossfadeImage(url: url, fit: BoxFit.cover),
            ),
        ],
      ),
    );

    return Semantics(
      label: semanticLabel ?? (text.isEmpty ? 'Member' : text),
      image: true,
      child: circle,
    );
  }
}

/// Overlapping avatars with a "+N" overflow chip.
class MemberStack extends StatelessWidget {
  const MemberStack({
    super.key,
    required this.members,
    this.maxVisible = 4,
    this.size = 30,
  });

  final List<TripMember> members;
  final int maxVisible;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<TripMember> visible = members.take(maxVisible).toList();
    final int overflow = members.length - visible.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < visible.length; i++)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // The ring between overlapping avatars has to match whatever
                // surface is behind them, or in dark mode each avatar wears a
                // white halo.
                color: theme.colorScheme.surface,
              ),
              child: MemberAvatar(
                initials: visible[i].initials,
                size: size,
                semanticLabel: visible[i].fullName,
              ),
            ),
          ),
        if (overflow > 0)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text('+$overflow', style: theme.textTheme.labelSmall),
            ),
          ),
      ],
    );
  }
}

/// Circular monogram used for the signed-in user in headers.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.initials,
    this.size = 36,
    this.onTap,
  });

  final String initials;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget avatar = MemberAvatar(
      initials: initials,
      size: size,
      semanticLabel: 'Your profile',
    );
    if (onTap == null) return avatar;

    // The tap target is padded out to the 48dp minimum. At the default 36px
    // avatar plus 2px of padding it was a 40dp target, below the guideline the
    // rest of the theme is built to.
    final double target = size < AppHitTarget.minimum
        ? AppHitTarget.minimum
        : size + 4;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: target,
        height: target,
        child: Center(child: avatar),
      ),
    );
  }
}
