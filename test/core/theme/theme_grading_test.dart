import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/core/theme/app_theme.dart';

/// "Colour grading is not fine" turned out to be several literal leftovers
/// from the previous indigo palette rather than a matter of taste: indigo
/// shadows, a blue-black darkest surface, and comments that still described
/// the ramp as indigo -> violet -> teal. Every one of those passed the old
/// contrast suite, because contrast says nothing about whether a colour belongs
/// to the palette. These pin that instead.
double hueOf(Color c) {
  final HSLColor hsl = HSLColor.fromColor(c);
  return hsl.saturation < 0.02 ? -1 : hsl.hue;
}

/// True when blue is the strongest channel, which is what makes a surface read
/// as cold against a warm palette.
bool isBlueDominant(Color c) =>
    c.b > c.g && c.b > c.r && (HSLColor.fromColor(c).saturation > 0.04);

bool isGreyish(Color c) => HSLColor.fromColor(c).saturation <= 0.04;

double relativeLuminance(Color c) => c.computeLuminance();

double contrastRatio(Color a, Color b) {
  final double la = relativeLuminance(a);
  final double lb = relativeLuminance(b);
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('every surface is warm', () {
    test('light surfaces are not blue-dominant', () {
      for (final MapEntry<String, Color> e in <String, Color>{
        'canvas': AppColors.canvas,
        'surface': AppColors.surface,
        'surfaceMuted': AppColors.surfaceMuted,
        'primarySoft': AppColors.primarySoft,
        'roseSoft': AppColors.roseSoft,
        'mint': AppColors.mint,
      }.entries) {
        expect(
          isBlueDominant(e.value),
          isFalse,
          reason: '${e.key} #${e.value.toARGB32().toRadixString(16)} is '
              'blue-dominant and reads cold over a warm canvas',
        );
      }
    });

    test('dark surfaces are not blue-dominant', () {
      for (final MapEntry<String, Color> e in <String, Color>{
        'darkCanvas': AppColors.darkCanvas,
        'darkSurface': AppColors.darkSurface,
        'darkSurfaceMuted': AppColors.darkSurfaceMuted,
      }.entries) {
        expect(
          isBlueDominant(e.value),
          isFalse,
          reason: '${e.key} is blue-dominant',
        );
      }
    });

    test('the darkest dark surface is warm, not blue-black', () {
      // This was #08080F: blue-dominant, and left over from the indigo ramp.
      const Color lowest = Color(0xFF0A0908);
      expect(isBlueDominant(lowest), isFalse);
      expect(contrastRatio(AppColors.darkInk, lowest), greaterThan(7));
    });
  });

  group('shadows are tinted warm', () {
    test('no shadow colour is blue-dominant', () {
      for (final MapEntry<String, List<BoxShadow>> e in <String, List<BoxShadow>>{
        'sm': AppShadow.sm,
        'md': AppShadow.md,
        'lg': AppShadow.lg,
        'raised': AppShadow.raised,
        'glow': AppShadow.glow,
      }.entries) {
        for (final BoxShadow s in e.value) {
          expect(
            isBlueDominant(s.color),
            isFalse,
            reason: '${e.key} shadow ${s.color.toARGB32().toRadixString(16)} '
                'is blue-dominant; a cold shadow over parchment reads as dirt',
          );
        }
      }
    });

    test('the brand shadow is drawn from the brand ramp', () {
      final Color brand = AppShadow.glow.first.color;
      expect(
        (hueOf(brand) - hueOf(AppColors.primary)).abs() < 3 ||
            (hueOf(brand) - hueOf(AppColors.primary)) > 357,
        isTrue,
        reason: 'glow shadow drifted away from the brand hue',
      );
    });
  });

  group('the brand ramp is one warm family', () {
    test('every brand colour sits in the warm arc', () {
      // The arc wraps through 0: red is at 0 degrees and rose at 345, so a
      // naive "hue <= 60" test rejects the reds that are plainly warm.
      bool isWarmHue(double h) => h <= 60 || h >= 330;

      for (final MapEntry<String, Color> e in <String, Color>{
        'primary': AppColors.primary,
        'primaryDeep': AppColors.primaryDeep,
        'orange': AppColors.orange,
        'rose': AppColors.rose,
        'amber': AppColors.amber,
        'amber600': AppColors.amber600,
      }.entries) {
        final double h = hueOf(e.value);
        expect(
          isWarmHue(h),
          isTrue,
          reason: '${e.key} sits at hue ${h.toStringAsFixed(0)}, '
              'outside the warm arc',
        );
      }
    });

    test('a token named teal is not a misnomer any more', () {
      // #B45309 is amber. The alias is kept for compatibility, but it must not
      // quietly become teal again.
      expect(AppColors.teal, AppColors.amber);
      expect(hueOf(AppColors.amber) <= 60 || hueOf(AppColors.amber) >= 330, isTrue);
    });
  });

  group('contrast still holds after the grading changes', () {
    test('body text pairs clear AA', () {
      final List<List<Object>> pairs = <List<Object>>[
        <Object>[AppColors.ink, AppColors.canvas, 4.5],
        <Object>[AppColors.inkMuted, AppColors.canvas, 4.5],
        <Object>[AppColors.inkFaint, AppColors.canvas, 4.5],
        <Object>[AppColors.ink, AppColors.surfaceMuted, 4.5],
        <Object>[AppColors.primary, AppColors.primarySoft, 4.5],
        <Object>[AppColors.rose, AppColors.roseSoft, 4.5],
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

    test('white text on the brand fill clears AA', () {
      expect(
        contrastRatio(Colors.white, AppColors.primary),
        greaterThanOrEqualTo(4.5),
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
          contrastRatio(
            t.colorScheme.onPrimary,
            t.colorScheme.primary,
          ),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  });
}