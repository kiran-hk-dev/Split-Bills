import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/core/config/app_config.dart';
import 'package:tripsplit_world/core/theme/app_theme.dart';
import 'package:tripsplit_world/features/budget/budget_page.dart';
import 'package:tripsplit_world/features/converter/converter_page.dart';
import 'package:tripsplit_world/features/dashboard/dashboard_page.dart';
import 'package:tripsplit_world/features/documents/documents_page.dart';
import 'package:tripsplit_world/features/emergency/emergency_center_page.dart';
import 'package:tripsplit_world/features/explore/explore_page.dart';
import 'package:tripsplit_world/features/expenses/expenses_page.dart';
import 'package:tripsplit_world/features/itinerary/itinerary_page.dart';
import 'package:tripsplit_world/features/packing/packing_page.dart';
import 'package:tripsplit_world/features/profile/profile_page.dart';
import 'package:tripsplit_world/features/trips/trips_page.dart';

/// Renders every primary screen at phone, tablet and desktop widths.
///
/// This is a rendering guard, not a behaviour test. The Explore tab shipped a
/// `SliverToBoxAdapter` containing an `Expanded`, which threw "non-zero flex but
/// unbounded height" and meant the tab could not be displayed at all — and no
/// existing test caught it, because the page's data providers have no injection
/// seam and so were never pumped.
///
/// Pumping each page is enough: whatever the providers resolve to the widget
/// tree still has to lay out without throwing. That is the failure this pins.
///
/// Demo mode is how the app runs without Supabase: every provider branches on
/// `AppConfig.demoMode` to read bundled fixtures, and `SupabaseService`
/// deliberately refuses to initialise in that mode. So these tests run under:
///
///     flutter test --dart-define=DEMO_MODE=true
///
/// Without the define they skip rather than fail, because a plain `flutter test`
/// has no session and every provider would sit in an error state for reasons
/// that have nothing to do with layout.
///
/// `pumpAndSettle` is deliberately avoided: the shimmer and progress animations
/// repeat forever, so settling would never complete and the test would time out
/// instead of asserting anything.
void main() {
  /// Demo mode is compiled in, so it cannot be toggled at runtime. See this
  /// file's doc comment for why these skip without the define.
  final bool skip = !AppConfig.demoMode;

  /// Representative widths from the app's own breakpoints.
  const Map<String, Size> viewports = <String, Size>{
    'small phone 320x640': Size(320, 640),
    'phone 390x844': Size(390, 844),
    'tablet 1024x768': Size(1024, 768),
    'desktop 1440x900': Size(1440, 900),
  };

  final Size phone = viewports['phone 390x844']!;
  final Size desktop = viewports['desktop 1440x900']!;

  Future<void> pumpAt(WidgetTester tester, Size size, Widget page) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          // The real host is AppShell, which supplies the Scaffold and
          // therefore the Material ancestor that InkWell and the slivers
          // require. Some pages (the dashboard) provide no Scaffold of their
          // own, so wrapping here reproduces how they are actually mounted.
          home: Scaffold(body: page),
        ),
      ),
    );

    // First frame builds, later ones settle providers and finish entrance
    // animations.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// The five screens behind the primary tabs.
  final Map<String, Widget Function()> tabs = <String, Widget Function()>{
    'dashboard': () => const DashboardPage(),
    'trips': () => const TripsPage(),
    'expenses': () => const ExpensesPage(),
    'explore': () => const ExplorePage(),
    'assistant': () => const EmergencyCenterPage(),
  };

  group('every tab renders at every breakpoint', () {
    tabs.forEach((String name, Widget Function() build) {
      viewports.forEach((String label, Size size) {
        testWidgets(
          '$name at $label',
          (WidgetTester tester) async {
            await pumpAt(tester, size, build());
            expect(
              tester.takeException(),
              isNull,
              reason: '$name threw while laying out at $label',
            );
          },
          skip: skip,
        );
      });
    });
  });

  group('trip-scoped screens render on a phone and a desktop', () {
    final Map<String, Widget Function()> tripScreens =
        <String, Widget Function()>{
          'itinerary': () => const ItineraryPage(tripId: 'test-trip'),
          'budget': () => const BudgetPage(tripId: 'test-trip'),
          'packing': () => const PackingPage(tripId: 'test-trip'),
        };

    tripScreens.forEach((String name, Widget Function() build) {
      testWidgets(
        name,
        (WidgetTester tester) async {
          for (final Size size in <Size>[phone, desktop]) {
            await pumpAt(tester, size, build());
            expect(
              tester.takeException(),
              isNull,
              reason: '$name threw while laying out at $size',
            );
          }
        },
        skip: skip,
      );
    });
  });

  group('standalone screens render on a phone and a desktop', () {
    final Map<String, Widget Function()> standalone = <String, Widget Function()>{
      'converter': () => const ConverterPage(),
      'documents': () => const DocumentsPage(),
      'profile': () => const ProfilePage(),
    };

    standalone.forEach((String name, Widget Function() build) {
      testWidgets(
        name,
        (WidgetTester tester) async {
          for (final Size size in <Size>[phone, desktop]) {
            await pumpAt(tester, size, build());
            expect(
              tester.takeException(),
              isNull,
              reason: '$name threw while laying out at $size',
            );
          }
        },
        skip: skip,
      );
    });
  });

  group('wide windows stay readable', () {
    testWidgets(
      'the dashboard content is capped and centred, not stretched edge to edge',
      (WidgetTester tester) async {
        await pumpAt(tester, desktop, const DashboardPage());

        // The shell caps content at maxContentWidth and centres it. Without
        // that cap the same build that looks right on a phone puts a card and
        // its text 1440px apart.
        final Size surface = tester.getSize(
          find.byType(Scaffold).first,
        );

        for (final Element element in find.byType(Text).evaluate()) {
          final RenderObject? object = element.findRenderObject();
          if (object is! RenderBox) continue;
          if (!object.attached || !object.hasSize || object.size.isEmpty) continue;

          final Rect rect = object.localToGlobal(Offset.zero) & object.size;
          expect(
            rect.width,
            lessThanOrEqualTo(AppBreakpoints.maxContentWidth + 1),
            reason: 'a text run is ${rect.width.toStringAsFixed(0)}px wide on a '
                '${surface.width.toStringAsFixed(0)}px window; content should '
                'be capped and centred',
          );
        }
      },
      skip: skip,
    );

    testWidgets(
      'the dashboard renders identically wide on a 2560px monitor',
      (WidgetTester tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(2560, 1400);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            child: const MaterialApp(
              theme: null,
              home: Scaffold(body: DashboardPage()),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(tester.takeException(), isNull);
      },
      skip: skip,
    );
  });
}
