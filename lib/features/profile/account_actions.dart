import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../data/supabase_service.dart';
import '../../router/providers.dart';
import '../../shared/widgets/common.dart';

/// Signs the current user out, after confirming.
///
/// Lives here rather than inside a page because sign-out has to behave
/// identically wherever it is offered. It was originally only reachable from
/// Settings — three taps from the avatar and below the fold — which made it
/// effectively invisible, so it is also surfaced directly on the Profile page.
///
/// The guards come first and deliberately do not show a confirmation the app
/// could not honour: in demo mode there is no session, and before Supabase has
/// initialised there is nothing to end. Offering a "Sign out?" dialog in either
/// case would let the user confirm something that cannot happen.
Future<void> signOutAction(BuildContext context, WidgetRef ref) async {
  if (AppConfig.demoMode) {
    showFeedback(
      context,
      'Demo mode has no real session to sign out of.',
      isError: true,
    );
    return;
  }

  if (!SupabaseService.isInitialised) {
    showFeedback(
      context,
      'Supabase is not configured, so there is no session to end.',
      isError: true,
    );
    return;
  }

  final bool confirmed = await confirmDestructive(
    context,
    title: 'Sign out?',
    message:
        'You will need your email and password to sign back in. Trips and '
        'expenses stay on your account.',
    confirmLabel: 'Sign out',
  );
  if (!confirmed || !context.mounted) return;

  await ref.read(authControllerProvider.notifier).signOut();
  if (!context.mounted) return;

  // The router listens for the signed-out state and returns to /welcome, but
  // redirect explicitly so a sign-out from a deep link cannot leave the user
  // on a screen that needs a session.
  context.go('/welcome');
}
