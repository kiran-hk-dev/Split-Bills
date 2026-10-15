import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/data/repositories.dart';

/// The converter became a primary tab while the exchange-rates edge function
/// had never been deployed, so tapping it dead-ended on "nothing is cached
/// yet". These cover the Frankfurter fallback that now sits between the
/// function and the cache.
Map<String, dynamic> payload({
  required String date,
  required Map<String, Object?> rates,
}) => <String, dynamic>{'base': 'USD', 'date': date, 'rates': rates};

void main() {
  group('parseFrankfurterResponse', () {
    test('maps each requested quote to a rate', () {
      final parsed = parseFrankfurterResponse(
        'USD',
        <String>['EUR', 'GBP'],
        payload(
          date: '2026-10-14',
          rates: <String, Object?>{'EUR': 0.89326, 'GBP': 0.75377},
        ),
      );

      expect(parsed.map((r) => r.quote), <String>['EUR', 'GBP']);
      expect(parsed.first.rate, closeTo(0.89326, 1e-9));
      expect(parsed.first.base, 'USD');
      expect(parsed.first.provider, 'frankfurter');
    });

    test('marks reference rates as indicative, never as a live quote', () {
      final parsed = parseFrankfurterResponse(
        'USD',
        <String>['EUR'],
        payload(date: '2026-10-14', rates: <String, Object?>{'EUR': 0.89}),
      );

      expect(parsed.single.isIndicative, isTrue);
    });

    test('carries the publication date as the fetch time, not now', () {
      final parsed = parseFrankfurterResponse(
        'USD',
        <String>['EUR'],
        payload(date: '2026-10-01', rates: <String, Object?>{'EUR': 0.89}),
      );

      expect(
        parsed.single.fetchedAt,
        DateTime(2026, 10, 1),
        reason: 'age is shown to the user, so it must reflect the rate date',
      );
    });

    test('a rate published inside the five day window is not stale', () {
      // Reference rates are only republished on working days, so a Friday
      // rate read on Monday must not be labelled stale. Dates are relative so
      // the test keeps meaning something as time passes.
      final published = DateTime.now().subtract(const Duration(days: 4));

      final parsed = parseFrankfurterResponse(
        'USD',
        <String>['EUR'],
        payload(
          date: published.toIso8601String().substring(0, 10),
          rates: <String, Object?>{'EUR': 0.89},
        ),
      );

      expect(parsed.single.isStale, isFalse);
    });

    test('a rate older than the window is flagged stale', () {
      final published = DateTime.now().subtract(const Duration(days: 30));

      final parsed = parseFrankfurterResponse(
        'USD',
        <String>['EUR'],
        payload(
          date: published.toIso8601String().substring(0, 10),
          rates: <String, Object?>{'EUR': 0.89},
        ),
      );

      expect(parsed.single.isStale, isTrue);
    });

    test('skips quotes the response omitted instead of inventing a rate', () {
      final parsed = parseFrankfurterResponse(
        'USD',
        <String>['EUR', 'ZZZ'],
        payload(date: '2026-10-14', rates: <String, Object?>{'EUR': 0.89}),
      );

      expect(parsed.map((r) => r.quote), <String>['EUR']);
    });

    test('never returns the base currency against itself', () {
      final parsed = parseFrankfurterResponse(
        'USD',
        <String>['USD', 'EUR'],
        payload(
          date: '2026-10-14',
          rates: <String, Object?>{'USD': 1.0, 'EUR': 0.89},
        ),
      );

      expect(parsed.map((r) => r.quote), <String>['EUR']);
    });

    test('throws when nothing usable came back, so the cache is tried', () {
      expect(
        () => parseFrankfurterResponse(
          'USD',
          <String>['EUR'],
          payload(date: '2026-10-14', rates: const <String, Object?>{}),
        ),
        throwsStateError,
      );
    });

    test('survives a response with no rates key at all', () {
      expect(
        () => parseFrankfurterResponse(
          'USD',
          <String>['EUR'],
          <String, dynamic>{'date': '2026-10-14'},
        ),
        throwsStateError,
      );
    });

    test('ignores a non-numeric rate rather than crashing on the cast', () {
      expect(
        () => parseFrankfurterResponse(
          'USD',
          <String>['EUR'],
          payload(
            date: '2026-10-14',
            rates: <String, Object?>{'EUR': 'n/a'},
          ),
        ),
        throwsStateError,
      );
    });
  });
}