import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/core/theme/app_theme.dart';
import 'package:tripsplit_world/shared/widgets/common.dart';

/// WCAG 2.1 contrast checks for the app palette.
///
/// These failed silently before. `inkFaint` was used for real text at 2.78:1,
/// and the theme drew text-field and outlined-button outlines from
/// `AppColors.border` at 1.34:1, which is invisible to low-vision users.
/// Measuring beats eyeballing: several StatusPill tones that *looked* alarming
/// measured a comfortable 4.5-5.5:1, while the genuinely failing pair was easy
/// to miss because it looked like ordinary grey text.
extension on Color {
  double get _linR => _channel(r);
  double get _linG => _channel(g);
  double get _linB => _channel(b);

  double _channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  /// Relative luminance per WCAG.
  double get luminance =>
      0.2126 * _linR + 0.7152 * _linG + 0.0722 * _linB;
}

double contrastRatio(Color a, Color b) {
  final double la = a.luminance, lb = b.luminance;
  final double hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  /// AA for normal text.
  const double textAA = 4.5;

  /// AA for large text and for the boundary that identifies a control.
  const double uiAA = 3.0;

  group('text contrast (WCAG AA, 4.5:1)', () {
    test('body text on canvas and surface', () {
      expect(
        contrastRatio(AppColors.ink, AppColors.canvas),
        greaterThanOrEqualTo(textAA),
      );
      expect(
        contrastRatio(AppColors.ink, AppColors.surface),
        greaterThanOrEqualTo(textAA),
      );
    });

    test('muted text on canvas and surface', () {
      expect(
        contrastRatio(AppColors.inkMuted, AppColors.canvas),
        greaterThanOrEqualTo(textAA),
      );
      expect(
        contrastRatio(AppColors.inkMuted, AppColors.surface),
        greaterThanOrEqualTo(textAA),
      );
    });

    test('faint placeholder text is readable, not just decorative', () {
      // Used for real text in documents, itinerary and notifications.
      expect(
        contrastRatio(AppColors.inkFaint, AppColors.canvas),
        greaterThanOrEqualTo(textAA),
      );
      expect(
        contrastRatio(AppColors.inkFaint, AppColors.surface),
        greaterThanOrEqualTo(textAA),
      );
    });

    test('status pill tones', () {
      final Map<String, (Color, Color)> tones =
          <String, (Color, Color)>{
            'positive': (AppColors.positive, AppColors.positiveSoft),
            'warning': (AppColors.warning, AppColors.warningSoft),
            'danger': (AppColors.danger, AppColors.dangerSoft),
            'info': (AppColors.info, AppColors.infoSoft),
            'neutral': (AppColors.inkMuted, AppColors.surfaceMuted),
          };
      tones.forEach((String name, (Color, Color) pair) {
        expect(
          contrastRatio(pair.$1, pair.$2),
          greaterThanOrEqualTo(textAA),
          reason: 'StatusPill $name',
        );
      });
    });

    test('primary button label on the primary fill', () {
      expect(
        contrastRatio(Colors.white, AppColors.teal),
        greaterThanOrEqualTo(textAA),
      );
    });

    test('dark theme body and muted text', () {
      expect(
        contrastRatio(AppColors.darkInk, AppColors.darkCanvas),
        greaterThanOrEqualTo(textAA),
      );
      expect(
        contrastRatio(AppColors.darkInkMuted, AppColors.darkSurface),
        greaterThanOrEqualTo(textAA),
      );
    });
  });

  group('control outlines (WCAG 1.4.11, 3:1)', () {
    test('light theme control border is perceivable', () {
      // scheme.outline is what draws text fields and outlined buttons.
      final ColorScheme light = AppTheme.light().colorScheme;
      expect(
        contrastRatio(light.outline, AppColors.surface),
        greaterThanOrEqualTo(uiAA),
        reason: 'outline must identify an interactive control',
      );
      expect(
        contrastRatio(light.outline, AppColors.canvas),
        greaterThanOrEqualTo(uiAA),
      );
    });

    test('dark theme control border is perceivable', () {
      final ColorScheme dark = AppTheme.dark().colorScheme;
      expect(
        contrastRatio(dark.outline, AppColors.darkSurface),
        greaterThanOrEqualTo(uiAA),
      );
      expect(
        contrastRatio(dark.outline, AppColors.darkCanvas),
        greaterThanOrEqualTo(uiAA),
      );
    });

    test('the control border still reads as stronger than a card edge', () {
      expect(
        contrastRatio(AppColors.borderStrong, AppColors.border),
        greaterThanOrEqualTo(1.8),
        reason: 'borderStrong must remain visibly heavier than border',
      );
    });
  });

group('BudgetProgressBar semantics', () {
    // A progress node's semanticsValue is parsed as a NUMBER. Passing prose
    // threw "Progress bar value, minValue, and maxValue must be valid numbers"
    // for anyone with a screen reader attached, and an overspend announced 140,
    // outside the 0-100 range, which threw too.
    Future<void> pumpBar(WidgetTester tester, double value) async {
      tester.view.physicalSize = const Size(400, 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: BudgetProgressBar(value: value)),
        ),
      );
      await tester.pump();
    }

    testWidgets('a normal value does not throw when semantics are on', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpBar(tester, 0.62);

      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('an overspend does not announce a value above 100', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpBar(tester, 1.4);

      expect(tester.takeException(), isNull);

      // getSemantics returns a TestSemanticsNode; only the string `value`
      // matters here.
      final dynamic node = tester.getSemantics(
        find.byType(LinearProgressIndicator),
      );
      final String? value = node.value as String?;
      if (value != null) {
        final int? parsed = int.tryParse(value);
        expect(parsed, isNotNull, reason: 'semanticsValue must stay numeric');
        expect(parsed, lessThanOrEqualTo(100));
      }
      handle.dispose();
    });

    testWidgets('a zero value is safe', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpBar(tester, 0);

      expect(tester.takeException(), isNull);
      handle.dispose();
    });
  });
}