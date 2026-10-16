import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/core/config/app_config.dart';
import 'package:tripsplit_world/core/theme/app_theme.dart';
import 'package:tripsplit_world/features/converter/converter_page.dart';
import 'package:tripsplit_world/features/dashboard/dashboard_page.dart';
import 'package:tripsplit_world/features/explore/explore_page.dart';
import 'package:tripsplit_world/features/expenses/expenses_page.dart';
import 'package:tripsplit_world/features/trips/trips_page.dart';

/// Accessibility guards for the primary tabs.
///
/// Both checks came out of measuring the screens rather than reading them.
///
/// The tap-target failure was a hardcoded `SizedBox(height: 40)` around the
/// Explore filter row, which capped every chip below the 48dp minimum no
/// matter what the chips asked for. Padding the chips and constraining the
/// text field changed nothing on their own, because the row was capping them.
///
/// The icon-button check exists because an icon with no tooltip and no label
/// is announced as "button" and nothing else.
bool _hasVisibleLabel(Widget child) {
  if (child is Text) {
    return (child.data ?? child.textSpan?.toPlainText() ?? '').isNotEmpty;
  }
  if (child is Semantics) {
    final String label = child.properties.label ?? child.properties.hint ?? '';
    return label.trim().isNotEmpty;
  }
  if (child is Tooltip) {
    return (child.message ?? '').trim().isNotEmpty;
  }
  return false;
}

void main() {
  // Every provider here branches on demo fixtures, so these only mean
  // something with the define set. See responsive_smoke_test for why.
  final bool skip = !AppConfig.demoMode;

  final Map<String, Widget Function()> tabs = <String, Widget Function()>{
    'dashboard': () => const DashboardPage(),
    'trips': () => const TripsPage(),
    'expenses': () => const ExpensesPage(),
    'explore': () => const ExplorePage(),
    'convert': () => const ConverterPage(),
  };

Future<SemanticsHandle> pumpAt(WidgetTester tester, Widget page) async {
    // The handle has to be disposed inside the test body, not from a tearDown:
    // the framework verifies handles are gone before tearDowns run.
    final SemanticsHandle handle = tester.ensureSemantics();
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: page),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 700));
    return handle;
  }

  tabs.forEach((String name, Widget Function() build) {
    group('$name', () {
testWidgets('every icon button is announced', (WidgetTester tester) async {
        final SemanticsHandle h = await pumpAt(tester, build());

        final List<IconButton> buttons =
            tester.widgetList<IconButton>(find.byType(IconButton)).toList();
        final List<String> anonymous = <String>[];
        for (final IconButton b in buttons) {
          final bool labelled = (b.tooltip ?? '').trim().isNotEmpty ||
              _hasVisibleLabel(b.icon);
          if (!labelled) anonymous.add('${b.icon.runtimeType}');
        }

        h.dispose();
        expect(
          anonymous,
          isEmpty,
          reason: 'on $name these IconButtons have no tooltip and no labelled '
              'child, so a screen reader announces only "button": '
              '${anonymous.join(', ')}',
        );
      });

      testWidgets('no tappable target is under 48dp', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle h = await pumpAt(tester, build());

        final List<String> small = <String>[];
        void visit(SemanticsNode node) {
          if (node.isMergedIntoParent) {
            node.visitChildren((SemanticsNode c) {
              visit(c);
              return true;
            });
            return;
          }
          final SemanticsData d = node.getSemanticsData();
          if (d.hasAction(ui.SemanticsAction.tap) &&
              node.rect.width > 0 &&
              node.rect.height > 0) {
            // A full-screen node is the scroll container, not a control.
            final bool isScrollContainer =
                node.rect.width >= 380 && node.rect.height >= 600;
            if (!isScrollContainer) {
              final double shortSide = node.rect.width < node.rect.height
                  ? node.rect.width
                  : node.rect.height;
              if (shortSide < AppHitTarget.minimum - 0.5) {
                small.add(
                  '${node.rect.width.toStringAsFixed(0)}x'
                  '${node.rect.height.toStringAsFixed(0)} '
                  '"${(d.label.isEmpty ? d.hint : d.label)}"',
                );
              }
            }
          }
          node.visitChildren((SemanticsNode c) {
            visit(c);
            return true;
          });
        }

// The semantics owner lives on the binding's pipelineOwner here.
// rootPipelineOwner does not carry it in this SDK version, so the deprecated
// accessor is the one that resolves.
// ignore: deprecated_member_use
final SemanticsOwner? owner = tester.binding.pipelineOwner.semanticsOwner;
        expect(owner, isNotNull, reason: 'semantics were not enabled');
        visit(owner!.rootSemanticsNode!);

        h.dispose();
        expect(
          small,
          isEmpty,
          reason: 'on $name these tappable targets are under '
              '${AppHitTarget.minimum}dp: ${small.join(', ')}',
        );
      });
    }, skip: skip);
  });
}