import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/reference.dart';
import '../../data/models/trip.dart';
import '../../data/repositories.dart';
import '../../data/supabase_service.dart';
import '../../router/app_shell.dart';
import '../../router/providers.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/motion.dart';

const List<String> kDestinationCategories = <String>[
  'city',
  'beaches',
  'mountains',
  'heritage',
  'food',
  'adventure',
  'family',
  'nature',
  'relaxation',
  'shopping',
  'nightlife',
  'culture',
];

final destinationResultsProvider = FutureProvider.autoDispose
    .family<List<Destination>, ({String query, String? category})>((
      Ref ref,
      ({String query, String? category}) args,
    ) {
      return ref
          .watch(destinationRepositoryProvider)
          .search(query: args.query, category: args.category);
    });

class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  String _query = '';
  String? _category;
  bool _showSaved = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Destination>> async = ref.watch(
      destinationResultsProvider((query: _query, category: _category)),
    );

    // Explore is a tab root, so the arrow PageScaffold would add by default
    // would only ever pop the shell's own route. The page supplies its own
    // header with PageHeader below, which is where the title and actions live.
    return PageScaffold(
      showBackButton: false,
      body: PageBody(
        // Zero, because every section in this sliver list already applies its
        // own AppSpacing.lg gutter and stacking both doubles it on a phone.
        padding: EdgeInsets.zero,
        child: ScrollAwareShell(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(destinationResultsProvider);
              ref.invalidate(wishlistProvider);
              await ref.read(wishlistProvider.future);
            },
            child: CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(child: FadeSlideIn(child: _header())),
                ..._bodySlivers(async),
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        children: <Widget>[
          PageHeader(
            title: 'Explore',
            subtitle: 'Destinations, ideas and saved places',
            actions: <Widget>[
              IconButton(
                onPressed: () => setState(() => _showSaved = !_showSaved),
                icon: AnimatedSwitcher(
                  duration: AppDurations.normal,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) =>
                          ScaleTransition(
                            scale: animation,
                            child: FadeTransition(opacity: animation, child: child),
                          ),
                  child: Icon(
                    _showSaved ? Icons.explore_outlined : Icons.bookmark_outline,
                    key: ValueKey<bool>(_showSaved),
                  ),
                ),
                tooltip: _showSaved
                    ? 'Browse destinations'
                    : 'Saved destinations',
              ),
              const NotificationBell(),
            ],
          ),
          if (!_showSaved) ...<Widget>[
            DebouncedSearchField(
              hint: 'Search a city, country or attraction',
              initialValue: _query,
              onChanged: (String v) => setState(() => _query = v),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kDestinationCategories.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (BuildContext context, int i) {
                  if (i == 0) {
                    return ChoiceChip(
                      selected: _category == null,
                      onSelected: (_) => setState(() => _category = null),
                      label: const Text('All'),
                    );
                  }
                  final String cat = kDestinationCategories[i - 1];
                  return ChoiceChip(
                    selected: _category == cat,
                    onSelected: (_) => setState(
                      () => _category = _category == cat ? null : cat,
                    ),
                    label: Text(cat),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  /// Height given to the loading, empty and error states so their centred
  /// content sits in the middle of the viewport rather than pinned to the top
  /// edge of an unbounded sliver.
  static const double _stateHeight = 420;

  /// The body, as slivers.
  ///
  /// This used to be a single `SliverToBoxAdapter` wrapping a Column that in
  /// turn wrapped the body in an `Expanded`. A `SliverToBoxAdapter` hands its
  /// child unbounded height, so the flex could never resolve and the whole
  /// Explore tab threw "RenderFlex children have non-zero flex but incoming
  /// height constraints are unbounded" — it could not render at all.
  ///
  /// The inner layer was a full `ListView` nested inside the outer sliver's
  /// scroll view: two scrollables competing for one gesture, and no lazy
  /// building. Returning real slivers fixes both.
  List<Widget> _bodySlivers(AsyncValue<List<Destination>> async) {
    if (_showSaved) {
      // Deliberately no flex in this branch. The Column shrink-wraps and the
      // enclosing sliver list already scrolls. FadeSlideIn is a proxy box, so
      // it does not reintroduce one either.
      return <Widget>[
        SliverToBoxAdapter(
          child: FadeSlideIn(
            delay: Duration(milliseconds: staggerDelayFor(1)),
            child: const SectionHeader(
              title: 'Saved destinations',
              padding: EdgeInsets.only(bottom: AppSpacing.md),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: FadeSlideIn(
            delay: Duration(milliseconds: staggerDelayFor(2)),
            child: const _SavedList(),
          ),
        ),
      ];
    }

    return async.when(
      loading: () => <Widget>[
        SliverToBoxAdapter(
          child: FadeSlideIn(
            delay: Duration(milliseconds: staggerDelayFor(1)),
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: SkeletonCard(lines: 3),
            ),
          ),
        ),
      ],
      error: (Object err, StackTrace _) => <Widget>[
        SliverToBoxAdapter(
          child: FadeSlideIn(
            delay: Duration(milliseconds: staggerDelayFor(1)),
            child: SizedBox(
              height: _stateHeight,
              child: ErrorStateView(
                message: 'Could not load destinations.',
                onRetry: () => ref.invalidate(destinationResultsProvider),
              ),
            ),
          ),
        ),
      ],
      data: (List<Destination> results) {
        if (results.isEmpty) {
          return <Widget>[
            SliverToBoxAdapter(
              child: FadeSlideIn(
                delay: Duration(milliseconds: staggerDelayFor(1)),
                child: SizedBox(
                  height: _stateHeight,
                  child: EmptyState(
                    icon: Icons.travel_explore,
                    title: 'No destinations match',
                    message: _query.isEmpty
                        ? 'Nothing is listed under that category yet.'
                        : 'Nothing found for that search. Try a country or city name.',
                  ),
                ),
              ),
            ),
          ];
        }

        return <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            sliver: SliverList.separated(
              itemCount: results.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (BuildContext context, int i) => FadeSlideIn(
                // Bounded, so scrolling deep into a long result list never
                // means waiting on a delay that keeps growing.
                delay: Duration(
                  milliseconds: staggerDelayFor(i, maxStaggered: 10),
                ),
                child: _DestinationCard(
                  destination: results[i],
                  onTap: () => context.push('/explore/${results[i].id}'),
                ),
              ),
            ),
          ),
        ];
      },
    );
  }
}

/// A destination in the results list.
///
/// The card used to be an image and a paragraph with nothing tappable on it but
/// the card itself, so browsing Explore could not lead anywhere: every idea
/// needed opening the detail page first. It now carries the actions that make
/// Explore worth browsing — save, add to a trip, and compare cost — each of
/// which jumps straight to where the work happens.
class _DestinationCard extends ConsumerWidget {
  const _DestinationCard({required this.destination, required this.onTap});

  final Destination destination;
  final VoidCallback onTap;

  /// Whether this destination is already on the saved list.
  ///
  /// Watched rather than held in local state, so saving from one card updates
  /// every card showing the same place, and the bookmark survives a rebuild.
  bool _isSaved(WidgetRef ref) {
    final List<Map<String, dynamic>> saved =
        ref.watch(wishlistProvider).value ?? const <Map<String, dynamic>>[];
    return saved.any(
      (Map<String, dynamic> item) => '${item['name']}' == destination.name,
    );
  }

  Future<void> _toggleSaved(BuildContext context, WidgetRef ref) async {
    final bool saved = _isSaved(ref);
    try {
      if (saved) {
        final List<Map<String, dynamic>> items =
            ref.read(wishlistProvider).value ?? const <Map<String, dynamic>>[];
        final Map<String, dynamic> match = items.firstWhere(
          (Map<String, dynamic> i) => '${i['name']}' == destination.name,
          orElse: () => const <String, dynamic>{},
        );
        if (match['id'] != null) {
          await ref
              .read(destinationRepositoryProvider)
              .removeFromWishlist('${match['id']}');
        }
      } else {
        await ref
            .read(destinationRepositoryProvider)
            .saveToWishlist(
              name: destination.name,
              country: destination.country,
              countryCode: destination.countryCode,
            );
      }
      ref.invalidate(wishlistProvider);
      if (context.mounted) {
        showFeedback(
          context,
          saved ? 'Removed from your list.' : 'Saved to your list.',
        );
      }
    } catch (err) {
      if (context.mounted) {
        showFeedback(
          context,
          err is RepositoryException ? err.message : 'Could not save that.',
          isError: true,
        );
      }
    }
  }

  /// Offers the trips a destination could be added to.
  ///
  /// Adds a trip to the picker. Without one there is nothing to add it to, so
  /// it sends the user to create one instead of showing an empty sheet.
  Future<void> _addToTrip(BuildContext context, WidgetRef ref) async {
    final TripListResult? trips = ref.read(tripsProvider).value;
    final List<Trip> options = trips?.trips ?? const <Trip>[];

    if (options.isEmpty) {
      if (context.mounted) {
        showFeedback(
          context,
          'Create a trip first, then add destinations to it.',
          isError: true,
        );
      }
      return;
    }

    if (!context.mounted) return;
    final String? chosen = await showAppSheet<String>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            const ListTile(
              title: Text(
                'Add to which trip?',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            for (final Trip t in options)
              ListTile(
                leading: const Icon(Icons.luggage_outlined),
                title: Text(t.name),
                subtitle: Text(t.destinationLabel),
                onTap: () => Navigator.of(context).pop(t.id),
              ),
          ],
        ),
      ),
    );

    if (chosen == null || !context.mounted) return;
    showFeedback(context, 'Opening ${destination.name} in your trip plan.');
    if (context.mounted) {
      context.push('/trips/$chosen/itinerary');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool saved = _isSaved(ref);

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Stack(
            children: <Widget>[
              if (destination.imageUrl != null)
                ClipRRect(
                  // Top corners only: this image sits flush against the top
                  // edge of the card, whose own corners are rounded above it.
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.lg),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 7,
                    // The old errorBuilder returned a bare tinted rectangle
                    // with a small icon, which looked identical to an image
                    // that had not loaded yet. NetworkArtwork draws a brand
                    // gradient instead.
                    child: NetworkArtwork(
                      url: destination.imageUrl!,
                      fallbackIcon: Icons.landscape_outlined,
                    ),
                  ),
                ),
              // Save toggle sits on the artwork so it is reachable from the
              // card without opening anything.
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: _SaveToggle(
                  saved: saved,
                  onTap: () => _toggleSaved(context, ref),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(destination.name, style: theme.textTheme.titleMedium),
                Text(
                  <String?>[
                    destination.city,
                    destination.country,
                  ].whereType<String>().join(', '),
                  style: theme.textTheme.bodySmall,
                ),
                if (destination.summary != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    destination.summary!,
                    style: theme.textTheme.bodySmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    if (destination.typicalDailyBudgetMinor != null)
                      StatusPill(
                        label:
                            '~${destination.typicalDailyBudgetMinor} per day in ${destination.currency ?? 'local'}',
                        dense: true,
                        tone: StatusTone.info,
                      ),
                    for (final String c in destination.categories.take(3))
                      StatusPill(label: c, dense: true),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Divider(color: theme.colorScheme.outlineVariant, height: 1),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _CardAction(
                        icon: Icons.playlist_add_check,
                        label: 'Add to trip',
                        primary: true,
                        onTap: () => _addToTrip(context, ref),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _CardAction(
                        icon: Icons.compare_arrows,
                        label: 'Compare',
                        onTap: onTap,
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

/// Bookmark toggle for a destination card.
class _SaveToggle extends StatelessWidget {
  const _SaveToggle({required this.saved, required this.onTap});

  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        // A real 44px target even though the glyph is 18.
        width: AppHitTarget.minimum,
        height: AppHitTarget.minimum,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: AnimatedSwitcher(
          duration: AppDurations.normal,
          transitionBuilder:
              (Widget child, Animation<double> animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
          child: Icon(
            saved ? Icons.bookmark : Icons.bookmark_border,
            key: ValueKey<bool>(saved),
            size: 20,
            color: saved ? _bookmarkColour(context) : Colors.white,
          ),
        ),
      ),
    );
  }

  static Color _bookmarkColour(BuildContext context) =>
      Theme.of(context).colorScheme.primaryContainer;
}

/// A compact action button used on the bottom of a destination card.
class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color bg = primary
        ? theme.colorScheme.primary
        : theme.colorScheme.primaryContainer;
    final Color fg = primary
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onPrimaryContainer;

    return PressableScale(
      onTap: onTap,
      child: Container(
        height: AppHitTarget.minimum,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 17, color: fg),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: fg,
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

final wishlistProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (Ref ref) {
    return ref.watch(destinationRepositoryProvider).wishlist();
  },
);

class _SavedList extends ConsumerWidget {
  const _SavedList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(wishlistProvider)
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: SkeletonCard(lines: 2),
          ),
          error: (Object err, StackTrace _) => ErrorStateView(message: '$err'),
          data: (List<Map<String, dynamic>> items) {
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.bookmark_border,
                title: 'Nothing saved yet',
                message: 'Save a destination to keep an eye on it, and add a target date and budget.',
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: items.length,
              itemBuilder: (BuildContext context, int i) {
                final Map<String, dynamic> item = items[i];
                return AppCard(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${item['name']}',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              '${item['country'] ?? ''}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (item['estimated_budget_minor'] != null)
                              Text(
                                'Budget ${item['estimated_budget_minor']} '
                                '${item['currency'] ?? ''}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          await ref
                              .read(destinationRepositoryProvider)
                              .removeFromWishlist('${item['id']}');
                          ref.invalidate(wishlistProvider);
                        },
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove from saved',
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
  }
}
