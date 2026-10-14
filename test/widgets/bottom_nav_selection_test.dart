import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/core/theme/app_theme.dart';
import 'package:tripsplit_world/router/app_router.dart';
import 'package:tripsplit_world/router/app_shell.dart';

/// Guards the phone bottom bar's selected state.
///
/// Driven against the real [appRouter] rather than a stand-in, so the selected
/// index is derived from the real route exactly as it is in production.
///
/// A report came in that selecting a tab on mobile made the selection vanish.
/// The selection logic turned out to be correct when checked, but nothing
/// pinned it — so this asserts the observable property directly: exactly one
/// destination is marked selected, and it is the one matching the route.
void main() {
  Future<void> pumpApp(
    WidgetTester tester,
    Size size, {
    bool clampText = true,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: appRouter,
          builder: (BuildContext context, Widget? child) => clampText
              ? MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(1.0),
                  ),
                  child: child ?? const SizedBox.shrink(),
                )
              : (child ?? const SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Scopes a finder to the bottom bar alone.
  ///
  /// Labels like "Expenses" and "Trips" also appear in page content, so an
  /// unscoped `find.text` matches more than once and the assertions pass for
  /// the wrong reason.
  Finder inBar(WidgetTester tester, String label) => find.descendant(
    of: find.byKey(const Key('app-bottom-nav')),
    matching: find.text(label),
  );

  /// The colour painted behind a destination's icon.
  ///
  /// The pill is a sibling of the label rather than an ancestor, so it has to be
  /// found by its own key.
  Color? indicatorFor(WidgetTester tester, AppTab tab) {
    final Finder pill = find.byKey(ValueKey<String>('nav-pill-${tab.route}'));
    if (pill.evaluate().isEmpty) return null;
    final AnimatedContainer container =
        tester.widget<AnimatedContainer>(pill.first);
    final BoxDecoration? decoration = container.decoration as BoxDecoration?;
    return decoration?.color;
  }

  /// The routes whose pill is currently tinted.
  Set<String> selectedRoutes(WidgetTester tester) => <String>{
    for (final AppTab tab in AppTab.values)
      if (indicatorFor(tester, tab) != Colors.transparent) tab.route,
  };

  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(inBar(tester, label));
    await tester.pump();
    // Past the pill's transition, so the AnimatedContainer has settled.
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('every destination stays reachable and selected', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const Size(390, 844));

    for (final AppTab tab in AppTab.values) {
      await tapTab(tester, tab.label);

      expect(
        selectedRoutes(tester),
        <String>{tab.route},
        reason: 'tapping "${tab.label}" should select exactly that destination, '
            'but got $selectedRoutes',
      );

      // The label must survive the switch. A vanished label is the failure
      // this was written for.
      expect(
        inBar(tester, tab.label),
        findsOneWidget,
        reason: 'the "${tab.label}" label disappeared after selecting it',
      );
    }
  });

  testWidgets('tapping the already-selected destination keeps it selected', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const Size(390, 844));

    await tapTab(tester, 'Assistant');
    expect(selectedRoutes(tester), <String>{'assistant'});

    await tapTab(tester, 'Assistant');
    expect(
      selectedRoutes(tester),
      <String>{'assistant'},
      reason: 'a repeat tap must not clear the selection',
    );
  });

  testWidgets('all five labels are visible at the narrowest supported width', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const Size(320, 640), clampText: false);

    for (final AppTab tab in AppTab.values) {
      expect(
        inBar(tester, tab.label),
        findsOneWidget,
        reason: '${tab.label} is not visible at 320px',
      );
    }
    expect(tester.takeException(), isNull);
  });
}
