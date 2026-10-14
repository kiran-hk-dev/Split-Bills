import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/core/config/app_config.dart';
import 'package:tripsplit_world/core/theme/app_theme.dart';
import 'package:tripsplit_world/features/profile/profile_page.dart';
import 'package:tripsplit_world/router/providers.dart';

/// Guards the discoverability of sign-out.
///
/// It existed only inside Settings, which is three taps from the avatar and
/// below the fold — reachable in the strict sense, invisible in practice. It is
/// now also on the Profile page, and the menu is built independently of the
/// profile data so a failed or empty profile cannot hide the only way to end a
/// session.
Future<void> _pumpProfile(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(900, 2400);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: ProfilePage()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('Profile page sign-out', () {
    testWidgets('offers a sign-out entry directly', (
      WidgetTester tester,
    ) async {
      await _pumpProfile(tester);

      expect(find.text('Sign out'), findsOneWidget);
      expect(find.byKey(const Key('profile-sign-out')), findsOneWidget);
    });

    testWidgets('sign-out sits last, after the other destinations', (
      WidgetTester tester,
    ) async {
      await _pumpProfile(tester);

      // The old placement was inside Settings, three taps from the avatar and
      // below the fold. What matters now is that it is reachable from the
      // profile page itself, and that as a destructive action it stays at the
      // bottom of the list rather than beside harmless navigation rows.
      final double settingsY = tester.getTopLeft(find.text('Settings')).dy;
      final double signOutY = tester
          .getTopLeft(find.byKey(const Key('profile-sign-out')))
          .dy;

      expect(
        signOutY,
        greaterThan(settingsY),
        reason: 'sign-out is destructive and should be the last row',
      );
    });

    testWidgets('the account menu survives a profile that failed to load', (
      WidgetTester tester,
    ) async {
      // With no Supabase client the profile provider resolves to null, which
      // is the state that previously replaced the whole page with an empty
      // state and no way to sign out.
      await _pumpProfile(tester);

      expect(find.byKey(const Key('profile-sign-out')), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('tapping sign-out explains itself instead of silently failing', (
      WidgetTester tester,
    ) async {
      await _pumpProfile(tester);

      await tester.tap(find.byKey(const Key('profile-sign-out')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Without a session there is nothing to end, so the app must say so
      // rather than opening a confirmation it could not honour.
      if (AppConfig.demoMode) {
        expect(find.textContaining('Demo mode'), findsOneWidget);
      } else {
        expect(find.textContaining('no session'), findsOneWidget);
      }
    });
  });
}
