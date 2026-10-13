import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/shared/widgets/trip_cover.dart';

Future<void> _pump(
  WidgetTester tester, {
  String? imageUrl,
  String? seed,
  String? title,
  String? subtitle,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            height: 180,
            child: TripCover(
              imageUrl: imageUrl,
              seed: seed,
              title: title,
              subtitle: subtitle,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('TripCover palette', () {
    test('is deterministic for the same trip', () {
      // The same trip must look the same on every device and after a restart,
      // so this cannot depend on anything random.
      final int a = TripCover.paletteIndex('JP:Tokyo');
      final int b = TripCover.paletteIndex('JP:Tokyo');
      expect(a, b);
    });

    test('different trips usually differ', () {
      final Set<int> used = <int>{
        for (final String seed in <String>[
          'JP:Tokyo',
          'IN:Goa',
          'TH:Bangkok',
          'FR:Paris',
          'IS:Reykjavik',
          'PE:Cusco',
        ])
          TripCover.paletteIndex(seed),
      };
      // Not a strict guarantee for any hash, but with 8 palettes and 6 trips
      // this should spread out rather than collapsing to one or two.
      expect(used.length, greaterThanOrEqualTo(4));
    });

    test('an empty seed is safe', () {
      expect(TripCover.paletteIndex(''), 0);
      expect(TripCover.paletteFor(''), isNotEmpty);
    });

    test('handles non-ASCII seeds', () {
      expect(() => TripCover.paletteIndex('JP:東京'), returnsNormally);
      expect(TripCover.paletteFor('JP:東京'), isNotEmpty);
    });

    test('every palette has two colours for the gradient', () {
      for (int i = 0; i < 8; i++) {
        expect(TripCover.paletteFor(i.toString()), hasLength(2));
      }
    });
  });

  group('TripCover rendering', () {
    testWidgets('renders artwork even with no image url', (
      WidgetTester tester,
    ) async {
      await _pump(tester, seed: 'JP:Tokyo');

      expect(tester.takeException(), isNull);
      expect(find.byType(TripCover), findsOneWidget);
    });

    testWidgets('shows an empty url as no image rather than an error', (
      WidgetTester tester,
    ) async {
      await _pump(tester, imageUrl: '', seed: 'IN:Goa');
      expect(tester.takeException(), isNull);
    });

    testWidgets('overlays the title and subtitle', (
      WidgetTester tester,
    ) async {
      await _pump(tester, seed: 'TH:Bangkok', title: 'Bangkok', subtitle: '12 days');

      expect(find.text('Bangkok'), findsOneWidget);
      expect(find.text('12 days'), findsOneWidget);
    });

    testWidgets('long titles ellipsize instead of overflowing', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        seed: 'IS:Reykjavik',
        title: 'An extremely long destination name that will not fit on a phone',
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow on a small phone (320px)', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        size: const Size(320, 640),
        seed: 'PE:Cusco',
        title: 'Cusco',
        subtitle: 'Peru',
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('handles a thumbnail with no title', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: DestinationThumb(seed: 'JP:Tokyo', emoji: '🗼')),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(DestinationThumb), findsOneWidget);
    });
  });
}