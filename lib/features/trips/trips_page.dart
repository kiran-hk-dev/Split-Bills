import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/trip.dart';
import '../../router/providers.dart';
import '../../router/app_shell.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/trip_cover.dart';

class TripsPage extends ConsumerStatefulWidget {
  const TripsPage({super.key});

  @override
  ConsumerState<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends ConsumerState<TripsPage> {
  _TripFilter _filter = _TripFilter.upcoming;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<dynamic> tripsAsync = ref.watch(tripsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/trips/new'),
        icon: const Icon(Icons.add),
        label: const Text('New trip'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(tripsProvider.future),
        child: CustomScrollView(
          slivers: <Widget>[
            const SliverToBoxAdapter(
              child: PageHeader(
                title: 'My trips',
                subtitle: 'Everything you are planning',
              ),
            ),
            SliverToBoxAdapter(
              child: _FilterBar(selected: _filter, onChanged: _setFilter),
            ),
            ..._buildBody(context, tripsAsync),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }

  void _setFilter(_TripFilter f) => setState(() => _filter = f);

  List<Widget> _buildBody(BuildContext context, AsyncValue<dynamic> async) {
    if (async.isLoading) {
      return const <Widget>[
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverToBoxAdapter(child: SkeletonCard(lines: 3)),
        ),
      ];
    }

    if (async.hasError) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorStateView(
            message: 'Could not load your trips.\n${async.error}',
            onRetry: () => ref.invalidate(tripsProvider),
          ),
        ),
      ];
    }

    final data = async.value;
    final List<Trip> all = (data?.trips as List<Trip>?) ?? const <Trip>[];
    final bool isStale = data?.isStale ?? false;
    final List<Trip> filtered = _filter.apply(all);

    if (all.isEmpty) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.luggage_outlined,
            title: 'No trips yet',
            message: 'Create a trip to plan days, set a budget and split costs with the people you are travelling with.',
            action: FilledButton.icon(
              onPressed: () => context.push('/trips/new'),
              icon: const Icon(Icons.add),
              label: const Text('Create your first trip'),
            ),
          ),
        ),
      ];
    }

    if (filtered.isEmpty) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.event_available_outlined,
            title: 'Nothing in ${_filter.label.toLowerCase()}',
            message: 'Trips you add with the matching status will appear here.',
          ),
        ),
      ];
    }

    return <Widget>[
      if (isStale)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: InlineBanner(
              message: 'Showing trips saved on this device. Pull down to refresh when you are back online.',
              tone: StatusTone.warning,
              icon: Icons.cloud_off,
            ),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        sliver: SliverList.separated(
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (BuildContext context, int i) =>
              TripCard(trip: filtered[i]),
        ),
      ),
    ];
  }
}

enum _TripFilter {
  upcoming('Upcoming', Icons.flight_takeoff),
  ongoing('In progress', Icons.play_circle_outline),
  past('Past trips', Icons.history),
  draft('Drafts', Icons.edit_note),
  archived('Archived', Icons.inventory_2_outlined);

  const _TripFilter(this.label, this.icon);

  final String label;
  final IconData icon;

  List<Trip> apply(List<Trip> trips) => trips.where((Trip t) {
    switch (this) {
      case _TripFilter.upcoming:
        return t.isUpcoming && !t.archived;
      case _TripFilter.ongoing:
        return t.isOngoing && !t.archived;
      case _TripFilter.past:
        return t.isPast && !t.archived;
      case _TripFilter.draft:
        return t.status == TripStatus.draft;
      case _TripFilter.archived:
        return t.archived;
    }
  }).toList();
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});

  final _TripFilter selected;
  final ValueChanged<_TripFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: _TripFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (BuildContext context, int i) {
          final _TripFilter f = _TripFilter.values[i];
          return ChoiceChip(
            selected: f == selected,
            onSelected: (_) => onChanged(f),
            avatar: Icon(f.icon, size: 16),
            label: Text(f.label),
          );
        },
      ),
    );
  }
}

class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip});

  final Trip trip;

  /// The actions offered on every card.
  ///
  /// The card used to do exactly one thing — open the trip — so logging an
  /// expense or checking the plan meant opening the trip and then finding the
  /// right tile inside it. On a phone that is four taps for the single most
  /// common action in the app. These jump straight there.
  List<({String label, IconData icon, String route})> get _quickActions =>
      <({String label, IconData icon, String route})>[
        (
          label: 'Expense',
          icon: Icons.add_card_outlined,
          route: '/trips/${trip.id}/expenses/new',
        ),
        (
          label: 'Plan',
          icon: Icons.map_outlined,
          route: '/trips/${trip.id}/itinerary',
        ),
        (
          label: 'Budget',
          icon: Icons.pie_chart_outline,
          route: '/trips/${trip.id}/budget',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canEdit = trip.myRole.canEdit;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/trips/${trip.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Always show artwork. A trip with no photo gets painted artwork
          // derived from its own identity, so the list is not a column of
          // identical placeholders.
          AspectRatio(
            aspectRatio: 16 / 7,
            child: TripCover(
              imageUrl: trip.coverImageUrl,
              seed: '${trip.countryCode ?? ''}:${trip.name}',
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    StatusPill(label: trip.effectiveStatus.label, dense: true),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        trip.dateRangeLabel,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  trip.name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  trip.destinationLabel,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: AppSpacing.lg),

                // Quick actions. Only for someone who can actually change the
                // trip — offering "add expense" to a viewer would lead to a
                // permission error one tap later.
                if (canEdit)
                  _QuickActionRow(actions: _quickActions)
                else
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.visibility_outlined,
                        size: 16,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'You have view access to this trip',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),

                const SizedBox(height: AppSpacing.lg),
                Divider(color: theme.colorScheme.outlineVariant, height: 1),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.people_outline,
                      size: 14,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${trip.travelerCount}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text('${trip.dayCount} days', style: theme.textTheme.bodySmall),
                    const Spacer(),
                    Text(
                      trip.baseCurrency,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of pill buttons that jump straight to a trip's sub-screens.
class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({required this.actions});

  final List<({String label, IconData icon, String route})> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < actions.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _QuickActionButton(
              label: actions[i].label,
              icon: actions[i].icon,
              // The first one is the common case, so it is the filled one.
              primary: i == 0,
              onTap: () => context.push(actions[i].route),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color fg = primary
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: AppCurves.standard,
        height: AppHitTarget.minimum,
        decoration: BoxDecoration(
          color: primary
              ? theme.colorScheme.primary
              : theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 17, color: primary ? fg : theme.colorScheme.onPrimaryContainer),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: primary ? fg : theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
