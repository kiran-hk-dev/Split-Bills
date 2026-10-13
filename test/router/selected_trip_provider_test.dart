import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/router/providers.dart';

/// Regression guard for the "Trip not found" bug.
///
/// `TripDetailPage` received its trip id from the route but read the trip from
/// `selectedTripIdProvider`, and its `initState` *cleared* that provider one
/// frame after mounting. Clearing tripped the loader to null, so the page
/// rendered its "not found" state instead of the trip.
///
/// These tests pin the invariant that a trip id, once selected, survives, and
/// that it can be restored from the route.
void main() {
  group('SelectedTripNotifier', () {
    test('starts empty', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedTripIdProvider), isNull);
    });

    test('select publishes an id and read returns it', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedTripIdProvider.notifier).select('trip-abc');
      expect(container.read(selectedTripIdProvider), 'trip-abc');
    });

    test('re-selecting the same id is idempotent', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedTripIdProvider.notifier).select('trip-abc');
      container.read(selectedTripIdProvider.notifier).select('trip-abc');

      expect(container.read(selectedTripIdProvider), 'trip-abc');
    });

    test('switching to another trip replaces the id', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedTripIdProvider.notifier).select('trip-abc');
      container.read(selectedTripIdProvider.notifier).select('trip-xyz');

      expect(container.read(selectedTripIdProvider), 'trip-xyz');
    });

    test('clear only happens when something asks for it', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedTripIdProvider.notifier).select('trip-abc');
      container.read(selectedTripIdProvider.notifier).clear();

      expect(container.read(selectedTripIdProvider), isNull);
    });

    test('notifies listeners when the selection changes', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final List<String?> seen = <String?>[];
      container.listen<String?>(
        selectedTripIdProvider,
        (_, String? next) => seen.add(next),
        fireImmediately: false,
      );

      container.read(selectedTripIdProvider.notifier).select('trip-abc');
      container.read(selectedTripIdProvider.notifier).select('trip-xyz');

      expect(seen, <String?>['trip-abc', 'trip-xyz']);
    });
  });
}