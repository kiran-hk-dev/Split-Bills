import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/data/models/misc.dart';

ActivityLog log(String summary, {String? actorName}) => ActivityLog(
  id: 'a',
  entityType: 'expense',
  action: 'expense_added',
  summary: summary,
  createdAt: DateTime(2026, 10, 1),
  actorName: actorName,
);

void main() {
  group('ActivityLog display helpers', () {
    // The reported symptom: "8b90b4a6-2fa2-4ea3-9854-0e2c74527d3e added
    // breakfast (INR)" appearing in the dashboard activity feed.
    test('strips a leading raw uuid from the summary', () {
      expect(
        log(
          '8b90b4a6-2fa2-4ea3-9854-0e2c74527d3e added breakfast (INR)',
        ).displaySummary,
        'added breakfast (INR)',
      );
    });

    test('leaves an already-clean summary untouched', () {
      expect(
        log('Priya added breakfast (INR)').displaySummary,
        'Priya added breakfast (INR)',
      );
    });

    test('handles an uppercase uuid', () {
      expect(
        log('8B90B4A6-2FA2-4EA3-9854-0E2C74527D3E added dinner (INR)')
            .displaySummary,
        'added dinner (INR)',
      );
    });

    test('never leaves a bare id as the whole summary', () {
      final String shown = log('8b90b4a6-2fa2-4ea3-9854-0e2c74527d3e  ').displaySummary;
      expect(shown, isNotEmpty);
      expect(shown, isNot(contains('8b90b4a6')));
    });

    test('does not strip a string that merely resembles a uuid', () {
      // A short id, or a word containing hyphens, is left alone.
      expect(
        log('abc123 added lunch').displaySummary,
        'abc123 added lunch',
      );
      expect(
        log('check-in-desk added lunch').displaySummary,
        'check-in-desk added lunch',
      );
    });

    test('falls back to a neutral actor name rather than an id', () {
      expect(log('x').displayActorName, 'Someone');
      expect(log('x', actorName: '').displayActorName, 'Someone');
      expect(log('x', actorName: '   ').displayActorName, 'Someone');
      expect(log('x', actorName: 'Dana Rivera').displayActorName, 'Dana Rivera');
    });

    test('builds a two-letter monogram, tolerant of one word', () {
      expect(log('x', actorName: 'Dana Rivera').actorInitials, 'DR');
      expect(log('x', actorName: 'Priya').actorInitials, 'Pr');
      // No name at all falls back to the neutral actor name, never an id.
      expect(log('x', actorName: null).actorInitials, 'So');
    });

    test('monogram never derives from a uuid', () {
      final ActivityLog l = log(
        '8b90b4a6-2fa2-4ea3-9854-0e2c74527d3e added breakfast (INR)',
        actorName: null,
      );
      expect(l.actorInitials, 'So');
      expect(l.displaySummary, isNot(contains('8b90b4a6')));
    });
  });
}
