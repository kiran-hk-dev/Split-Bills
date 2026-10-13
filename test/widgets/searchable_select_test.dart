import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/shared/widgets/searchable_select.dart';

const List<String> _items = <String>[
  'Flights',
  'Trains & buses',
  'Accommodation',
  'SIM & connectivity',
  'Medical reserve',
];

Future<void> _pump(
  WidgetTester tester, {
  required ValueChanged<String?> onChanged,
  String? value = 'Flights',
  bool isRequired = false,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Form(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SearchableSelect<String>(
              label: 'Category',
              value: value,
              items: _items,
              isRequired: isRequired,
              labelBuilder: (String s) => s,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('SearchableSelect', () {
    testWidgets('shows the current value, not a placeholder', (
      WidgetTester tester,
    ) async {
      await _pump(tester, onChanged: (_) {});

      expect(find.text('Flights'), findsOneWidget);
      expect(find.text('Choose Category'), findsNothing);
    });

    testWidgets('shows a prompt when nothing is selected', (
      WidgetTester tester,
    ) async {
      await _pump(tester, value: null, onChanged: (_) {});

      expect(find.text('Choose Category'), findsOneWidget);
    });

    testWidgets('tapping opens the searchable sheet with every option', (
      WidgetTester tester,
    ) async {
      await _pump(tester, onChanged: (_) {});

      await tester.tap(find.text('Flights'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TextField), findsOneWidget);
      for (final String item in _items) {
        expect(find.text(item), findsWidgets, reason: 'missing $item');
      }
    });

    testWidgets('typing narrows the list', (WidgetTester tester) async {
      await _pump(tester, onChanged: (_) {});

      await tester.tap(find.text('Flights'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(find.byType(TextField), 'sim');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('SIM & connectivity'), findsWidgets);
      expect(find.text('Medical reserve'), findsNothing);
    });

    testWidgets('search is case insensitive', (WidgetTester tester) async {
      await _pump(tester, onChanged: (_) {});

      await tester.tap(find.text('Flights'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(find.byType(TextField), 'MEDICAL');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Medical reserve'), findsWidgets);
    });

    testWidgets('reports a friendly message instead of an empty sheet', (
      WidgetTester tester,
    ) async {
      await _pump(tester, onChanged: (_) {});

      await tester.tap(find.text('Flights'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Nothing matches that search.'), findsOneWidget);
    });

    testWidgets('choosing an option closes the sheet and reports the value', (
      WidgetTester tester,
    ) async {
      String? chosen;
      await _pump(tester, onChanged: (String? v) => chosen = v);

      await tester.tap(find.text('Flights'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Medical reserve').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(chosen, 'Medical reserve');
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('a required field with no value fails validation', (
      WidgetTester tester,
    ) async {
      final GlobalKey<FormState> formKey = GlobalKey<FormState>();

      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SearchableSelect<String>(
                  label: 'Category',
                  value: null,
                  items: _items,
                  isRequired: true,
                  labelBuilder: (String s) => s,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Choose Category.'), findsOneWidget);
    });

    // A DropdownButton sizes to its widest label, which overflows a narrow
    // phone. These are the regression guards for that.
    testWidgets('does not overflow on a small phone (320px)', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        onChanged: (_) {},
        value: 'SIM & connectivity',
        size: const Size(320, 640),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow with a long selected label', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        onChanged: (_) {},
        value: 'SIM & connectivity',
        size: const Size(320, 640),
      );

      await tester.tap(find.text('SIM & connectivity'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });

    testWidgets('adapts to a wide desktop viewport', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        onChanged: (_) {},
        size: const Size(1440, 900),
      );

      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Flights'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The sheet is capped, so it cannot swallow a tall desktop screen.
      final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(find.byType(TextField), findsOneWidget);
      expect(screen.width, greaterThan(1000));
    });
  });
}