import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural guard for the Explore "Saved" tab.
///
/// `ExplorePage._buildBody` returns a Column that is handed straight to
/// `SliverToBoxAdapter`. A Column inside a sliver has unbounded height, so an
/// `Expanded` in that Column cannot resolve and Flutter throws at runtime:
///
///   RenderFlex children have non-zero flex but incoming height constraints
///   are unbounded
///
/// The saved list shrink-wraps its own content and the outer sliver already
/// scrolls, so no flex was ever required.
///
/// This asserts against the source rather than pumping the widget. That is
/// deliberate: `destinationResultsProvider` and `wishlistProvider` are private
/// to explore_page.dart with no injection seam, so the page cannot be rendered
/// in a widget test without loading live Supabase data. Exposing them purely
/// for testability is a larger change than the bug it guards.
void main() {
  group('explore_page saved body layout', () {
    late String source;

    setUpAll(() {
      source = File('lib/features/explore/explore_page.dart').readAsStringSync();
    });

    test('the saved branch does not use a flex child', () {
      // Isolate the _showSaved branch of _buildBody.
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

    test('the body is passed to a sliver, so height really is unbounded', () {
      // Guards the premise of the test above.
      expect(
        source,
        contains('SliverToBoxAdapter(child: _bodyColumn(async))'),
        reason: 'if the body stopped being a sliver child, the constraint '
            'argument no longer applies',
      );
    });
  });
}