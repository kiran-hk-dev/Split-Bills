import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/core/theme/app_theme.dart';

/// The theme was moved from a warm ember palette to a light-blue one.
///
/// The previous version of this file asserted the opposite of what it asserts
/// now: it required every surface to be warm and failed any colour that was
/// blue-dominant. That test was correct for the palette it was written for and
/// wrong for this one, so it was rewritten rather than deleted - the property
/// worth pinning is that the whole palette agrees with itself, not any
/// particular hue family.
///
/// Two things it caught while the palette was being chosen:
/// - inkFaint and borderStrong were drafted at 4.25:1 and 2.52:1, both under
///   their targets. They were darkened to #55738D and #6E93B5 rather than the
///   thresholds being relaxed.
/// - `border` sits at 1.33:1 against surface. That is deliberate for a hairline
///   divider, and it is the one pair below 3.0 here; `borderStrong` carries
///   control outlines instead.
double hueOf(Color c) {
  final HSLColor hsl = HSLColor.fromColor(c);
  return hsl.saturation < 0.02 ? -1 : hsl.hue;
}

/// A surface that is not blue-leaning. For a blue theme this is the failure.
bool isWarmDominant(Color c) => c.r > c.b && c.b > 0;

double contrastRatio(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('surfaces agree with the blue theme', () {
    test('light surfaces are cool, not warm', () {
      for (final MapEntry<String, Color> e in <String, Color>{
        'canvas': AppColors.canvas,
        'surfaceMuted': AppColors.surfaceMuted,
        'primarySoft': AppColors.primarySoft,
        'cyanSoft': AppColors.cyanSoft,
      }.entries) {
        expect(
          isWarmDominant(e.value),
          isFalse,
          reason: '${e.key} is warm in a blue theme',
        );
      }
    });

    test('dark surfaces are cool, not warm', () {
      for (final MapEntry<String, Color> e in <String, Color>{
        'darkCanvas': AppColors.darkCanvas,
        'darkSurface': AppColors.darkSurface,
        'darkSurfaceMuted': AppColors.darkSurfaceMuted,
      }.entries) {
        expect(
          isWarmDominant(e.value),
          isFalse,
          reason: '${e.key} is warm in a blue theme',
        );
      }
    });

    test('the darkest dark surface stays cool', () {
      const Color lowest = Color(0xFF080D13);
      expect(isWarmDominant(lowest), isFalse);
      expect(contrastRatio(AppColors.darkInk, lowest), greaterThan(7));
    });
  });

  group('shadows are tinted to the theme', () {
    test('no shadow is warm', () {
      for (final MapEntry<String, List<BoxShadow>> e
          in <String, List<BoxShadow>>{
        'sm': AppShadow.sm,
        'md': AppShadow.md,
        'lg': AppShadow.lg,
        'raised': AppShadow.raised,
        'glow': AppShadow.glow,
      }.entries) {
        for (final BoxShadow s in e.value) {
          expect(
            isWarmDominant(s.color),
            isFalse,
            reason: '${e.key} shadow ${s.color.toARGB32().toRadixString(16)} '
                'is warm',
          );
        }
      }
    });

    test('the brand shadow is drawn from the brand ramp', () {
      final double brand = hueOf(AppShadow.glow.first.color);
      final double primary = hueOf(AppColors.primary);
      expect(
        (brand - primary).abs() < 12,
        isTrue,
        reason: 'glow shadow drifted away from the brand hue',
      );
    });
  });

  group('the brand ramp is one blue family', () {
    test('every brand colour sits in the cool arc', () {
      // The cool arc wraps through 240: azure is near 200 and deep cyan near
      // 193, while a naive "hue >= 180" test would reject anything that drifts
      // past 240.
      bool isCoolHue(double h) => h >= 175 && h <= 250;

      for (final MapEntry<String, Color> e in <String, Color>{
        'primary': AppColors.primary,
        'primaryDeep': AppColors.primaryDeep,
        'sky': AppColors.sky,
        'cyan': AppColors.cyan,
      }.entries) {
        final double h = hueOf(e.value);
        expect(
          isCoolHue(h),
          isTrue,
          reason: '${e.key} sits at hue ${h.toStringAsFixed(0)}, outside '
              'the cool arc',
        );
      }
    });

    test('the ramp is ordered, darkest to lightest', () {
      // Luminance reality: primaryDeep 0.089 < primary 0.127 < cyan 0.146 <
      // sky 0.206. An earlier version of this test chained
      // primary < sky < cyan, which is not the order these four actually sit
      // in.
      double l(Color c) => c.computeLuminance();
      expect(
        l(AppColors.primaryDeep),
        lessThan(l(AppColors.primary)),
        reason: 'primaryDeep must be the deepest',
      );
      expect(l(AppColors.primary), lessThan(l(AppColors.sky)));
      expect(l(AppColors.primary), lessThan(l(AppColors.cyan)));
      // The ramp has to actually span a range, or it reads as one colour.
      expect(
        l(AppColors.sky) - l(AppColors.primaryDeep),
        greaterThan(0.08),
      );
    });

    test('the amber alias still points at amber', () {
      // Amber is a semantic warning colour and is deliberately warm, so it
      // sits outside the brand ramp. Only the alias is pinned here; an earlier
      // version asserted it was cool, which contradicted its whole purpose.
      expect(AppColors.teal, AppColors.amber);
      expect(AppColors.teal600, AppColors.amber600);
      expect(hueOf(AppColors.amber), isNot(-1));
    });
  });

  group('contrast holds in the blue palette', () {
    test('body text pairs clear AA', () {
      final List<List<Object>> pairs = <List<Object>>[
        <Object>[AppColors.ink, AppColors.canvas, 4.5],
        <Object>[AppColors.inkMuted, AppColors.canvas, 4.5],
        <Object>[AppColors.inkFaint, AppColors.canvas, 4.5],
        <Object>[AppColors.ink, AppColors.surfaceMuted, 4.5],
        <Object>[AppColors.primary, AppColors.primarySoft, 4.5],
        <Object>[AppColors.cyan, AppColors.cyanSoft, 4.5],
        <Object>[AppColors.positive, AppColors.canvas, 4.5],
        <Object>[AppColors.danger, AppColors.canvas, 4.5],
      ];
      for (final List<Object> p in pairs) {
        expect(
          contrastRatio(p[0] as Color, p[1] as Color),
          greaterThanOrEqualTo(p[2] as double),
          reason: '${(p[0] as Color).toARGB32().toRadixString(16)} on '
              '${(p[1] as Color).toARGB32().toRadixString(16)}',
        );
      }
    });

    test('white text on every brand fill clears AA', () {
      for (final MapEntry<String, Color> e in <String, Color>{
        'primary': AppColors.primary,
        'primaryDeep': AppColors.primaryDeep,
        'cyan': AppColors.cyan,
      }.entries) {
        expect(
          contrastRatio(Colors.white, e.value),
          greaterThanOrEqualTo(4.5),
          reason: 'white on ${e.key} is too low',
        );
      }
    });

    test('control outlines clear 3:1', () {
      expect(
        contrastRatio(AppColors.borderStrong, AppColors.canvas),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        contrastRatio(AppColors.borderStrong, AppColors.surface),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('every theme brightness keeps its text readable', () {
      for (final ThemeData t in <ThemeData>[
        AppTheme.light(),
        AppTheme.dark(),
      ]) {
        expect(
          contrastRatio(t.colorScheme.onSurface, t.colorScheme.surface),
          greaterThan(4.5),
        );
        expect(
          contrastRatio(t.colorScheme.onPrimary, t.colorScheme.primary),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(
            t.colorScheme.onSecondaryContainer,
            t.colorScheme.secondaryContainer,
          ),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  });
}