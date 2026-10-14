import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural guard for the Explore body layout.
///
/// The body used to be handed to a single `SliverToBoxAdapter` as a Column.
/// A Column inside a sliver has unbounded height, so an `Expanded` in that
/// Column cannot resolve and Flutter throws at runtime:
///
///   RenderFlex children have non-zero flex but incoming height constraints
///   are unbounded
///
/// That took down the whole Explore tab — it could not render at all.
///
/// The body now returns real slivers (`_bodySlivers`), so the results list is
/// a lazy `SliverList` sharing the page's one scroll position instead of a
/// `ListView` nested inside the outer scroll view. The saved branch still goes
/// through a `SliverToBoxAdapter`, so it must still shrink-wrap.
///
/// This asserts against the source rather than pumping the widget. That is
/// deliberate: `destinationResultsProvider` and `wishlistProvider` are private
/// to explore_page.dart with no injection seam, so the page cannot be rendered
/// in a widget test without loading live Supabase data. Exposing them purely
/// for testability is a larger change than the bug it guards.
void main() {
  group('explore_page body layout', () {
    late String source;

    setUpAll(() {
      source = File('lib/features/explore/explore_page.dart').readAsStringSync();
    });

    test('the saved branch does not use a flex child', () {
      // Isolate the _showSaved branch of _bodySlivers.
      final int start = source.indexOf('if (_showSaved) {');
      expect(start, greaterThan(-1), reason: 'saved branch not found');

      final int end = source.indexOf('return async.when(', start);
      expect(end, greaterThan(start), reason: 'saved branch end not found');

      final String branch = source.substring(start, end);

      expect(
        branch,
        isNot(contains('Expanded(')),
        reason: 'Expanded inside a SliverToBoxAdapter Column has no height to '
            'fill and throws "non-zero flex but unbounded height"',
      );
      expect(branch, isNot(contains('Flexible(')));
      expect(branch, isNot(contains('Spacer(')));
    });

    test('the saved list shrink-wraps so it needs no flex parent', () {
      // If this ever changes, the branch above would need revisiting.
      expect(source, contains('shrinkWrap: true'));
      expect(source, contains('NeverScrollableScrollPhysics'));
    });

    test('the body is spread in as slivers, not boxed into one adapter', () {
      // The original crash needed a box child with a flex inside it. Returning
      // slivers removes the possibility at the type level.
      expect(
        source,
        contains('..._bodySlivers(async)'),
        reason: 'the body must be spread into the sliver list',
      );
      expect(
        source,
        isNot(contains('SliverToBoxAdapter(child: _bodyColumn(')),
        reason: 'boxing the body into one SliverToBoxAdapter is what allowed '
            'the unbounded-height flex crash to reappear',
      );
    });

    test('the results list is a lazy sliver, not a nested scrollable', () {
      // A ListView inside the page's CustomScrollView competes for the same
      // gesture and builds every card up front.
      expect(source, contains('SliverList.separated'));

      final int listStart = source.indexOf('ListView.separated(');
      expect(
        listStart,
        greaterThan(-1),
        reason: 'only the horizontal category rail should use ListView.separated',
      );
      final int sliverList = source.indexOf('SliverList.separated(');
      expect(
        sliverList,
        greaterThan(listStart),
        reason: 'the results list must be the sliver one',
      );
    });
  });
}