import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_theme.dart';
import '../data/demo/demo_fixtures.dart';
import '../data/supabase_service.dart';
import '../data/models/trip.dart';
import '../shared/widgets/common.dart';
import '../shared/widgets/motion.dart';
import 'providers.dart';

/// The five primary destinations. Kept in one place so the bottom bar, the
/// navigation rail and the widget tests all agree.
enum AppTab {
  home(
    'home',
    'Home',
    'Home',
    Icons.home_outlined,
    Icons.home,
    Icons.home_rounded,
  ),
  trips(
    'trips',
    'Trips',
    'My trips',
    Icons.luggage_outlined,
    Icons.luggage,
    Icons.luggage_rounded,
  ),
  expenses(
    'expenses',
    'Expenses',
    'Expenses',
    Icons.receipt_long_outlined,
    Icons.receipt_long,
    Icons.receipt_long_rounded,
  ),
  explore(
    'explore',
    'Explore',
    'Explore',
    Icons.travel_explore_outlined,
    Icons.travel_explore,
    Icons.travel_explore_rounded,
  ),
  assistant(
    'assistant',
    'Assistant',
    'Assistant',
    Icons.health_and_safety_outlined,
    Icons.health_and_safety,
    Icons.health_and_safety_rounded,
  );

  const AppTab(
    this.route,
    this.label,
    this.railLabel,
    this.icon,
    this.selectedIcon,
    this.filledIcon,
  );

  final String route;

  /// Label for the phone bottom bar, where space is tight.
  final String label;

  /// Label for the side rail. "My trips" reads better than "Trips" beside
  /// the other four destinations, where "Trips" could be misread as a tab
  /// rather than a list of the user's own.
  final String railLabel;

  final IconData icon;

  /// The outlined-to-filled partner of [icon], used for the bar and rail.
  final IconData selectedIcon;

  /// The rounded variant used in the large active pill, where the heavier
  /// silhouette reads better at a glance than the standard weight.
  final IconData filledIcon;
}

/// Adaptive shell.
///
/// Three layouts from one component:
///
///  * below [AppBreakpoints.tablet] — an animated bottom bar
///  * [AppBreakpoints.tablet] to [AppBreakpoints.desktop] — a collapsed side
///    rail
///  * [AppBreakpoints.desktop] and up — an extended rail with labels
///
/// Every layout also caps the content width and centres it. Without that cap
/// the same build that looks right on a 390px phone renders a list card
/// 1900px wide on a desktop browser, with the navigation at one edge and the
/// text at the other.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.tab,
    required this.child,
    this.floatingActionButton,
    this.title,
    this.actions,
    this.showBackButton = false,
  });

  final AppTab tab;
  final Widget child;
  final Widget? floatingActionButton;
  final String? title;
  final List<Widget>? actions;
  final bool showBackButton;

  void _go(AppTab target, BuildContext context, WidgetRef ref) {
    if (target == tab) return;
    ref.read(selectedTripIdProvider.notifier).clear();
    GoRouter.of(context).go('/${target.route}');
  }

  /// True when there is nothing for an app bar to show.
  bool get _hasNoAppBar =>
      title == null && actions == null && !showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool useRail = width >= AppBreakpoints.tablet;
    final bool useExtendedRail = width >= AppBreakpoints.desktop;
    final int selectedIndex = AppTab.values.indexOf(tab);

    final Widget body = _WrapWithConnectionBanner(
      child: ScrollAwareShell(child: child),
    );

    final AppBar? appBar = _hasNoAppBar
        ? null
        : AppBar(
            title: title == null ? null : Text(title!),
            leading: showBackButton
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/home'),
                    tooltip: 'Back',
                  )
                : null,
            actions: actions,
          );

    if (!useRail) {
      return Scaffold(
        appBar: appBar,
        body: body,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        bottomNavigationBar: _BottomNavBar(
          tabs: AppTab.values,
          selectedIndex: selectedIndex,
          onSelected: (int i) => _go(AppTab.values[i], context, ref),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: <Widget>[
          _SideNav(
            tabs: AppTab.values,
            selectedIndex: selectedIndex,
            extended: useExtendedRail,
            onSelected: (int i) => _go(AppTab.values[i], context, ref),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Expanded(
            child: Scaffold(
              appBar: appBar == null
                  ? null
                  : AppBar(
                      title: title == null ? null : Text(title!),
                      automaticallyImplyLeading: false,
                      actions: actions,
                    ),
              body: _WrapWithConnectionBanner(
                // The width cap lives here so it applies to every page in the
                // shell, including the ones that have not adopted PageBody yet.
                child: _ContentWidth(child: ScrollAwareShell(child: child)),
              ),
              floatingActionButton: floatingActionButton,
            ),
          ),
        ],
      ),
    );
  }
}

/// The phone navigation bar.
///
/// Replaces Material's [NavigationBar] so the active state can be a gradient
/// pill with the icon morphing into its filled form, both animated. The
/// default bar swaps the indicator instantly and the label jumps from grey to
/// colour, which reads as a flicker rather than a response.
class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  /// Lets the responsive-navigation tests find the bar without depending on
  /// the Material widget type, which is free to change.
  static const Key navKey = Key('app-bottom-nav');

  final List<AppTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;

    return Container(
      key: navKey,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        // Lifts the bar off the scrolling content behind it.
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: dark ? const Color(0x66000000) : const Color(0x140F0E2A),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          // A minimum rather than a fixed height: at a 1.4x accessibility text
          // scale the label needs more room than 68dp, and a fixed height
          // overflowed the bar.
          constraints: const BoxConstraints(minHeight: 68),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              for (int i = 0; i < tabs.length; i++)
                Expanded(
                  child: _BottomNavItem(
                    tab: tabs[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    // The selected state is a filled brand pill, not a faint tint.
    //
    // It was `primaryContainer` (#EEF0FE) on a #FFFFFF surface — a difference
    // of about 3% that is invisible on a phone in daylight, so a selected tab
    // read as unselected. `primary` carries white icon and label at 6.3:1, and
    // it cannot be mistaken for the resting state.
    final Color pillColor = theme.colorScheme.primary;
    final Color activeColor = theme.colorScheme.onPrimary;
    final Color inactiveColor = theme.textTheme.bodySmall?.color ??
        AppColors.inkMuted;

    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // The pill behind the icon grows out of nothing when selected.
              AnimatedContainer(
                // Keyed per destination so the selected state can be asserted
                // directly — the label is a sibling of this pill, not a
                // descendant, so it cannot be used to find it.
                key: ValueKey<String>('nav-pill-${tab.route}'),
                duration: AppDurations.normal,
                curve: AppCurves.entrance,
                height: 34,
                width: selected ? 56 : 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? pillColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  boxShadow: selected
                      ? <BoxShadow>[
                          BoxShadow(
                            color: pillColor.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: AnimatedScale(
                  duration: AppDurations.normal,
                  curve: AppCurves.emphasis,
                  scale: selected ? 1.0 : 0.92,
                  child: AnimatedSwitcher(
                    duration: AppDurations.normal,
                    child: Icon(
                      selected ? tab.filledIcon : tab.icon,
                      key: ValueKey<bool>(selected),
                      size: 21,
                      color: selected ? activeColor : inactiveColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              // The label fades rather than switching colour instantly.
              AnimatedDefaultTextStyle(
                duration: AppDurations.fast,
                curve: AppCurves.standard,
                style:
                    (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
                      color: selected
                          ? theme.colorScheme.primary
                          : inactiveColor,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                child: Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tablet and desktop navigation rail.
///
/// Custom rather than [NavigationRail] so the selected item can carry the
/// brand gradient and animate between items, and so the extended variant can
/// show the wordmark. Material's rail does not animate its indicator at all.
class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.tabs,
    required this.selectedIndex,
    required this.extended,
    required this.onSelected,
  });

  final List<AppTab> tabs;
  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onSelected;

  static const double _collapsedWidth = 84;
  static const double _extendedWidth = 244;

  /// See [_BottomNavBar.navKey].
  static const Key navKey = Key('app-side-nav');

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      key: navKey,
      width: extended ? _extendedWidth : _collapsedWidth,
      color: theme.colorScheme.surface,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment:
              extended ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                extended ? AppSpacing.xl : 0,
                AppSpacing.xl,
                extended ? AppSpacing.xl : 0,
                AppSpacing.huge,
              ),
              child: _RailBrand(extended: extended),
            ),
            for (int i = 0; i < tabs.length; i++)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: extended ? AppSpacing.md : AppSpacing.md,
                  vertical: AppSpacing.xxs,
                ),
                child: _SideNavItem(
                  tab: tabs[i],
                  selected: i == selectedIndex,
                  extended: extended,
                  onTap: () => onSelected(i),
                ),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _SideNavUtility(extended: extended),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailBrand extends StatelessWidget {
  const _RailBrand({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget mark = const BrandMark(size: 38);

    if (!extended) {
      return Center(child: mark);
    }

    return Row(
      children: <Widget>[
        mark,
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'TripSplit',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              Text(
                'World',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SideNavItem extends StatelessWidget {
  const _SideNavItem({
    required this.tab,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final AppTab tab;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Color> brand = AppGradientsTheme.of(context).brand;
    // The selected rail item is filled with the brand gradient, so its
    // foreground has to be white. onPrimaryContainer would be dark indigo,
    // which is the right pairing for a pale primaryContainer pill but
    // unreadable on the gradient itself.
    const Color activeFg = Colors.white;
    final Color inactiveFg = theme.textTheme.bodySmall?.color ??
        AppColors.inkMuted;

    final Widget icon = AnimatedSwitcher(
      duration: AppDurations.normal,
      transitionBuilder:
          (Widget child, Animation<double> animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
      child: Icon(
        selected ? tab.filledIcon : tab.icon,
        key: ValueKey<bool>(selected),
        size: 22,
        color: selected ? activeFg : inactiveFg,
      ),
    );

    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      child: Tooltip(
        message: extended ? '' : tab.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AnimatedContainer(
            duration: AppDurations.normal,
            curve: AppCurves.entrance,
            height: 48,
            padding: EdgeInsets.symmetric(
              horizontal: extended ? AppSpacing.md : 0,
            ),
            decoration: BoxDecoration(
              gradient: selected
                  ? AppGradients.linear(colors: brand, end: Alignment.centerLeft)
                  : null,
              color: selected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              mainAxisAlignment:
                  extended ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: <Widget>[
                if (extended)
                  SizedBox(
                    width: 40,
                    child: Center(child: icon),
                  )
                else
                  icon,
                if (extended) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: AppDurations.fast,
                      style:
                          (theme.textTheme.labelLarge ?? const TextStyle())
                              .copyWith(
                                color: selected ? activeFg : inactiveFg,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                      child: Text(
                        tab.railLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Profile and settings, pinned to the foot of the rail.
class _SideNavUtility extends StatelessWidget {
  const _SideNavUtility({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color inactiveFg = theme.textTheme.bodySmall?.color ??
        AppColors.inkMuted;

    Widget row(IconData icon, String label, String route) {
      final Widget content = Row(
        mainAxisAlignment:
            extended ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: <Widget>[
          if (extended) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            Icon(icon, size: 20, color: inactiveFg),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: inactiveFg,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ] else
            Icon(icon, size: 20, color: inactiveFg),
        ],
      );

      return Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: () => context.push(route),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: SizedBox(height: 44, child: content),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        row(Icons.notifications_none_rounded, 'Notifications', '/notifications'),
        const SizedBox(height: AppSpacing.xs),
        row(Icons.settings_outlined, 'Settings', '/settings'),
        const SizedBox(height: AppSpacing.xs),
        row(Icons.person_outline_rounded, 'Profile', '/profile'),
      ],
    );
  }
}

/// Caps and centres the page content on wide windows.
///
/// Phones are unaffected — the gutter is just [AppSpacing.lg] there.
class _ContentWidth extends StatelessWidget {
  const _ContentWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppBreakpoints.maxContentWidth,
        ),
        child: child,
      ),
    );
  }
}

/// Shows an offline banner when the device has no connection. It never blocks
/// content — cached data stays readable.
class _WrapWithConnectionBanner extends ConsumerWidget {
  const _WrapWithConnectionBanner({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (AppConfig.demoMode) {
      return Column(
        children: <Widget>[
          const _DemoBanner(),
          Expanded(child: child),
        ],
      );
    }

    final ConnectionStatus status = ref.watch(connectionStatusProvider);
    if (status != ConnectionStatus.offline) return child;

    return Column(
      children: <Widget>[
        const _OfflineBanner(),
        Expanded(child: child),
      ],
    );
  }
}

/// Slides a strip down from the top when connectivity drops.
///
/// The previous version popped in with no motion, so the one banner that
/// appears without the user doing anything was also the least noticeable.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color fg = theme.brightness == Brightness.dark
        ? const Color(0xFFFCD34D)
        : AppColors.warning;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppDurations.slow,
      curve: AppCurves.entrance,
      builder: (BuildContext context, double t, Widget? _) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: t,
          child: Container(
            width: double.infinity,
            color: fg.withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.cloud_off, size: 16, color: fg),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'You are offline. Cached data is shown where available.',
                    style: theme.textTheme.bodySmall?.copyWith(color: fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color fg = theme.brightness == Brightness.dark
        ? const Color(0xFFFCD34D)
        : AppColors.warning;

    return Container(
      width: double.infinity,
      color: fg.withValues(alpha: theme.brightness == Brightness.dark ? 0.16 : 0.14),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.science_outlined, size: 16, color: fg),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Demo mode — fictional data, nothing is saved and no network calls are made.',
              style: theme.textTheme.bodySmall?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard header used at the top of each tab's scroll view.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.avatar,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double width = MediaQuery.sizeOf(context).width;
    final double gutter = PageBody.gutterFor(width);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        gutter,
        AppSpacing.lg,
        gutter,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (avatar != null) ...<Widget>[
            avatar!,
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Headline size grows with the window: on a phone this is the
                // page's clear focal point, on a desktop it should still be.
                Text(
                  title,
                  style:
                      (width >= AppBreakpoints.tablet
                              ? theme.textTheme.headlineSmall
                              : theme.textTheme.titleLarge)
                          ?.copyWith(letterSpacing: -0.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            ...actions,
          ],
        ],
      ),
    );
  }
}

/// Notification bell with an unread badge, used in headers.
///
/// The badge pops in rather than appearing at full size, and the bell nudges
/// so an arriving notification is noticed in peripheral vision.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final int count = ref.watch(unreadNotificationCountProvider).value ?? 0;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: <Widget>[
        IconButton(
          onPressed: () => context.push('/notifications'),
          icon: const Icon(Icons.notifications_none_rounded),
          tooltip: count > 0 ? '$count unread notifications' : 'Notifications',
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
        ),
        if (count > 0)
          Positioned(
            top: 4,
            right: 4,
            child: TweenAnimationBuilder<double>(
              key: ValueKey<int>(count),
              tween: Tween<double>(begin: 0, end: 1),
              duration: AppDurations.normal,
              curve: AppCurves.emphasis,
              builder:
                  (BuildContext context, double t, Widget? child) =>
                      Transform.scale(scale: t, child: child),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: theme.colorScheme.surface, width: 1.5),
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Small helper for demo-mode-only actions: runs the callback in demo mode and
/// otherwise shows a clear "not available in demo mode" message.
Future<void> guardDemoAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  if (AppConfig.demoMode) {
    showFeedback(
      context,
      'This action is disabled in demo mode — nothing is saved.',
      isError: true,
    );
    return;
  }
  await action();
}

/// Reads the demo profile when in demo mode, otherwise the live profile.
Profile? demoOrNull(Profile? profile) =>
    AppConfig.demoMode ? DemoFixtures.profile : profile;
