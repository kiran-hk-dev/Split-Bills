import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/app_config.dart';
import '../../core/money/currency.dart';
import '../../core/theme/app_theme.dart';
import '../../data/demo/demo_fixtures.dart';
import '../../data/models/expense.dart';
import '../../data/models/planning.dart';
import '../../data/models/trip.dart';
import '../../data/repositories.dart';
import '../../data/supabase_service.dart';
import '../../router/providers.dart';
import '../../shared/widgets/avatars.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/trip_cover.dart';

/// Hub for one trip. Every module is scoped to this trip id.
class TripDetailPage extends ConsumerStatefulWidget {
  const TripDetailPage({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripDetailPage> createState() => _TripDetailPageState();
}

class _TripDetailPageState extends ConsumerState<TripDetailPage> {
  @override
  void initState() {
    super.initState();
    // Publish the trip id so the screens this one links to (itinerary,
    // expenses, visa) can read it from shared state.
    //
    // This used to *clear* it, which made the page blank itself out: clearing
    // tripped currentTripProvider to null, the page rendered "Trip not found",
    // and opening any trip from My Trips appeared broken.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final String id = widget.tripId;
      if (id.isEmpty) return;
      if (ref.read(selectedTripIdProvider) != id) {
        ref.read(selectedTripIdProvider.notifier).select(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Keyed on the route parameter, so a refresh or a deep link still resolves.
    final AsyncValue<Trip?> async = ref.watch(
      tripByIdProvider(widget.tripId),
    );

    return async.when(
      loading: () => PageScaffold(body: const _TripDetailSkeleton()),
      error: (Object err, StackTrace _) => PageScaffold(
        body: ErrorStateView(
          message: 'Could not load this trip.\n$err',
          onRetry: () => ref.invalidate(tripByIdProvider(widget.tripId)),
        ),
      ),
      data: (Trip? trip) {
        if (trip == null) {
          return PageScaffold(
            body: ErrorStateView(
              title: 'Trip not found',
              message:
                  'It may have been deleted, or you may no longer be a member of it.',
              onRetry: () => context.go('/trips'),
            ),
          );
        }
        return _TripDetailBody(trip: trip);
      },
    );
  }
}

/// Placeholder shown while a trip loads.
///
/// A skeleton rather than a spinner: the layout is already known, so the page
/// does not jump when the data lands.
class _TripDetailSkeleton extends StatelessWidget {
  const _TripDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    // PageBody carries the 1080px width cap. padding is zero because the
    // sections below already apply their own AppSpacing.lg gutter.
    return PageBody(
      padding: EdgeInsets.zero,
      child: ScrollAwareShell(
        child: const SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SkeletonBox(height: 28),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(height: 18),
                SizedBox(height: AppSpacing.xl),
                SkeletonBox(height: 160),
                SizedBox(height: AppSpacing.lg),
                SkeletonBox(height: 96),
                SizedBox(height: AppSpacing.lg),
                SkeletonBox(height: 96),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TripDetailBody extends ConsumerWidget {
  const _TripDetailBody({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<TripMember>> members = ref.watch(
      membersProvider(trip.id),
    );
    final List<Widget> modules = _moduleTiles(trip, context);

    // The SliverAppBar below is this page's header: it carries the cover, the
    // trip name, the automatic back arrow and the overflow menu. PageScaffold
    // therefore adds none of its own, or the page would carry two app bars and
    // two back buttons. padding is zero because every section below already
    // applies its own AppSpacing.lg gutter.
    return PageScaffold(
      showBackButton: false,
      body: PageBody(
        padding: EdgeInsets.zero,
        child: ScrollAwareShell(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                pinned: true,
                expandedHeight: 240,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    trip.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      shadows: <Shadow>[
                        Shadow(blurRadius: 8, color: Colors.black54),
                      ],
                    ),
                  ),
                  background: TripCover(
                    imageUrl: trip.coverImageUrl,
                    seed: '${trip.countryCode ?? ''}:${trip.name}',
                    // No title here: the trip name and dates are already laid
                    // out underneath, so overlaying them would duplicate them.
                    showScrim: true,
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                actions: <Widget>[
                  PopupMenuButton<String>(
                    onSelected: (String value) =>
                        _handleAction(context, ref, value),
                    itemBuilder:
                        (BuildContext context) => <PopupMenuEntry<String>>[
                          const PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Edit trip'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'duplicate',
                            child: ListTile(
                              leading: Icon(Icons.copy_all_outlined),
                              title: Text('Duplicate'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'archive',
                            child: ListTile(
                              leading: Icon(Icons.inventory_2_outlined),
                              title: Text('Archive'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          if (trip.myRole.isOwner)
                            const PopupMenuItem(
                              value: 'cover-styles',
                              child: ListTile(
                                leading: Icon(Icons.wallpaper_outlined),
                                title: Text('Cover styles'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          if (trip.myRole.isOwner)
                            const PopupMenuItem(
                              value: 'cover',
                              child: ListTile(
                                leading: Icon(Icons.photo_library_outlined),
                                title: Text('Upload cover photo'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          if (trip.myRole.isOwner &&
                              trip.coverImageUrl != null &&
                              trip.coverImageUrl!.isNotEmpty)
                            const PopupMenuItem(
                              value: 'cover-remove',
                              child: ListTile(
                                leading: Icon(Icons.hide_image_outlined),
                                title: Text('Remove cover'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          if (trip.myRole.isOwner)
                            const PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                title: Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          if (trip.myRole.isOwner)
                            const PopupMenuItem(
                              value: 'leave',
                              child: ListTile(
                                leading: Icon(Icons.logout),
                                title: Text('Leave trip'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                        ],
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  delay: Duration(milliseconds: staggerDelayFor(0)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            StatusPill(
                              label: trip.effectiveStatus.label,
                              tone: trip.isOngoing
                                  ? StatusTone.positive
                                  : StatusTone.info,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            StatusPill(
                              label: trip.travelStyle.label,
                              icon: Icons.tune,
                            ),
                            const Spacer(),
                            Text(
                              trip.dateRangeLabel,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        if (trip.description != null &&
                            trip.description!.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.md),
                          Text(trip.description!, style: theme.textTheme.bodyMedium),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        _MetaRow(
                          trip: trip,
                          members: members.value ?? const <TripMember>[],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  delay: Duration(milliseconds: staggerDelayFor(1)),
                  child: _BudgetStrip(trip: trip),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  delay: Duration(milliseconds: staggerDelayFor(2)),
                  child: const SectionHeader(
                    title: 'Trip modules',
                    subtitle: 'Everything below is scoped to this trip',
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.huge,
                ),
                // Each tile cascades in on its own index; the delay stops
                // growing past the eighth tile.
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisExtent: 104,
                  ),
                  delegate: SliverChildListDelegate(<Widget>[
                    for (int i = 0; i < modules.length; i++)
                      FadeSlideIn(
                        delay: Duration(milliseconds: staggerDelayFor(i)),
                        child: modules[i],
                      ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: trip.myRole.canEdit
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/trips/${trip.id}/expenses/new'),
              icon: const Icon(Icons.add),
              label: const Text('Add expense'),
            )
          : null,
    );
  }

  /// The module grid's tiles, in order.
  ///
  /// Kept as a list rather than inline sliver children so the grid can wrap
  /// each tile in its own entrance without the definitions moving.
  static List<Widget> _moduleTiles(Trip trip, BuildContext context) =>
      <Widget>[
        _ModuleTile(
          icon: Icons.map_outlined,
          label: 'Itinerary',
          caption: '${trip.dayCount} days',
          onTap: () => context.push('/trips/${trip.id}/itinerary'),
        ),
        _ModuleTile(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Budget',
          caption: trip.baseCurrency,
          onTap: () => context.push('/trips/${trip.id}/budget'),
        ),
        _ModuleTile(
          icon: Icons.receipt_long_outlined,
          label: 'Expenses',
          caption: 'Split & settle',
          onTap: () => context.push('/trips/${trip.id}/expenses'),
          primary: true,
        ),
        _ModuleTile(
          icon: Icons.balance_outlined,
          label: 'Balances',
          caption: 'Who owes whom',
          onTap: () => context.push('/trips/${trip.id}/balances'),
        ),
        _ModuleTile(
          icon: Icons.bar_chart_outlined,
          label: 'Reports',
          caption: 'CSV & PDF',
          onTap: () => context.push('/trips/${trip.id}/reports'),
        ),
        _ModuleTile(
          icon: Icons.confirmation_number_outlined,
          label: 'Bookings',
          caption: 'Flights & stays',
          onTap: () => context.push('/trips/${trip.id}/bookings'),
        ),
        _ModuleTile(
          icon: Icons.folder_outlined,
          label: 'Documents',
          caption: 'Tickets & insurance',
          onTap: () => context.push('/documents?trip=${trip.id}'),
        ),
        _ModuleTile(
          icon: Icons.work_outline,
          label: 'Visa & entry',
          caption: 'Check requirements',
          onTap: () => context.push('/trips/${trip.id}/visa'),
        ),
        _ModuleTile(
          icon: Icons.checklist_outlined,
          label: 'Packing',
          caption: 'Checklist',
          onTap: () => context.push('/trips/${trip.id}/packing'),
        ),
        _ModuleTile(
          icon: Icons.group_outlined,
          label: 'Members',
          caption: '${trip.memberCount} people',
          onTap: () => context.push('/trips/${trip.id}/members'),
        ),
      ];

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final TripRepository repo = ref.read(tripRepositoryProvider);
    switch (action) {
      case 'edit':
        await context.push('/trips/new', extra: trip);
      case 'duplicate':
        if (AppConfig.demoMode) {
          if (context.mounted) {
            showFeedback(
              context,
              'Duplicating is disabled in demo mode.',
              isError: true,
            );
          }
          return;
        }
        try {
          final String id = await repo.duplicateTrip(trip.id);
          if (context.mounted) context.push('/trips/$id');
        } catch (err) {
          if (context.mounted) {
            showFeedback(
              context,
              err is RepositoryException ? err.message : 'Could not duplicate.',
              isError: true,
            );
          }
        }
      case 'archive':
        await repo.archiveTrip(trip.id, !trip.archived);
        ref.invalidate(tripsProvider);
        ref.invalidate(currentTripProvider);
        if (context.mounted) {
          showFeedback(
            context,
            trip.archived ? 'Trip restored.' : 'Trip archived.',
          );
        }
      case 'cover':
        await _changeCover(context, ref);
      case 'cover-styles':
        await _pickCoverStyle(context, ref);
      case 'cover-remove':
        try {
          await repo.removeTripCover(trip.id);
          ref.invalidate(tripsProvider);
          ref.invalidate(currentTripProvider);
          if (context.mounted) showFeedback(context, 'Cover photo removed.');
        } catch (err) {
          if (context.mounted) {
            showFeedback(
              context,
              err is RepositoryException
                  ? err.message
                  : 'Could not remove the cover photo.',
              isError: true,
            );
          }
        }
      case 'leave':
        final bool confirmed = await confirmDestructive(
          context,
          title: 'Leave this trip?',
          message: 'You will lose access to its expenses, itinerary and documents. The other members keep their copy.',
          confirmLabel: 'Leave',
        );
        if (!confirmed) return;
        await repo.leaveTrip(trip.id);
        ref.invalidate(tripsProvider);
        if (context.mounted) context.go('/trips');
      case 'delete':
        final bool confirmed = await confirmDestructive(
          context,
          title: 'Delete "${trip.name}"?',
          message: 'This permanently removes the trip and everything in it: expenses, balances, itineraries, bookings and documents. This cannot be undone.',
          confirmLabel: 'Delete permanently',
        );
        if (!confirmed) return;
        try {
          await repo.deleteTrip(trip.id);
          ref.invalidate(tripsProvider);
          if (context.mounted) context.go('/trips');
        } catch (err) {
          if (context.mounted) {
            showFeedback(
              context,
              err is RepositoryException ? err.message : 'Could not delete.',
              isError: true,
            );
          }
        }
    }
  }

  /// Picks one of the bundled cover illustrations.
///
/// This is the route that actually works today. Uploading needs a storage
/// bucket and migration 20260101000011, which has not been applied, so before
/// this a trip's cover could only ever be painted artwork.
Future<void> _pickCoverStyle(BuildContext context, WidgetRef ref) async {
  final String? current = TripCovers.bundledPathOf(trip.coverImageUrl);

  final String? chosen = await showAppSheet<String>(
    context: context,
    builder: (BuildContext sheetContext) => _CoverStyleSheet(current: current),
  );
  if (chosen == null || !context.mounted) return;

  try {
    await ref
        .read(tripRepositoryProvider)
        .updateTrip(trip.id, <String, dynamic>{
      'cover_image_url': TripCovers.urlFor(chosen),
    });
    ref.invalidate(tripsProvider);
    ref.invalidate(currentTripProvider);
    if (context.mounted) showFeedback(context, 'Cover updated.');
  } catch (err) {
    if (context.mounted) {
      showFeedback(
        context,
        err is RepositoryException ? err.message : 'Could not set the cover.',
        isError: true,
      );
    }
  }
}

  ///
  /// Until this existed `cover_image_url` could never be populated, so every
  /// trip fell back to painted artwork and there was no way to put a real
  /// photo on a trip at all.
  Future<void> _changeCover(BuildContext context, WidgetRef ref) async {
    if (AppConfig.demoMode) {
      showFeedback(
        context,
        'Uploads are disabled in demo mode.',
        isError: true,
      );
      return;
    }

    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // Downscaled before upload. A modern phone photo is 4-8 MB and the
      // bucket caps at 5 MB, so the original would fail on size alone.
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );
    if (picked == null || !context.mounted) return;

    final Uint8List bytes = await picked.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (context.mounted) {
        showFeedback(
          context,
          'That image is larger than 5 MB. Pick a smaller one.',
          isError: true,
        );
      }
      return;
    }

    try {
      await ref.read(tripRepositoryProvider).uploadTripCover(
            tripId: trip.id,
            bytes: bytes,
            filename: picked.name,
            mimeType: picked.mimeType ?? _mimeForCover(picked.name),
          );
      ref.invalidate(tripsProvider);
      ref.invalidate(currentTripProvider);
      if (context.mounted) showFeedback(context, 'Cover photo updated.');
    } catch (err) {
      if (context.mounted) {
        showFeedback(
          context,
          err is RepositoryException
              ? err.message
              : 'Could not update the cover photo.',
          isError: true,
        );
      }
    }
  }

  static String _mimeForCover(String filename) {
    final String lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}


class _CoverStyleSheet extends StatelessWidget {
  const _CoverStyleSheet({this.current});

  /// The bundled cover already in use, if any, so it can be marked.
  final String? current;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Cover style', style: text.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Bundled artwork, so it loads instantly and works offline. '
              'You can still upload a photo of your own.',
              style: text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // Two columns at every width: a cover is a 16:9-ish shape, so
                // a single column on a tablet would waste the sheet.
                const double gap = AppSpacing.md;
                final double tile =
                    (constraints.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: <Widget>[
                    for (final ({String path, String label}) o
                        in TripCovers.options)
                      SizedBox(
                        width: tile,
                        child: _CoverTile(
                          path: o.path,
                          label: o.label,
                          selected: o.path == current,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverTile extends StatelessWidget {
  const _CoverTile({
    required this.path,
    required this.label,
    required this.selected,
  });

  final String path;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: '$label cover',
      child: InkWell(
        onTap: () => Navigator.of(context).pop(path),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Image.asset(path, fit: BoxFit.cover),
                    if (selected)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: scheme.primary,
                            width: 3,
                          ),
                        ),
                      ),
                    if (selected)
                      Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? scheme.primary : scheme.onSurface,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.trip, required this.members});

  final Trip trip;
  final List<TripMember> members;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        _Meta(icon: Icons.place_outlined, text: trip.destinationLabel),
        _Meta(
          icon: Icons.people_outline,
          text: '${trip.travelerCount} travellers',
        ),
        _Meta(
          icon: Icons.event_outlined,
          text: '${trip.dayCount} day${trip.dayCount == 1 ? '' : 's'}',
        ),
        if (trip.perTravelerBudgetMinor > 0)
          _Meta(
            icon: Icons.pie_chart_outline,
            text:
                '${Money(trip.perTravelerBudgetMinor, trip.baseCurrency).format()} per person',
          ),
        if (members.isNotEmpty)
          _Meta(
            icon: Icons.group_outlined,
            text: members
                .map((TripMember m) => m.displayName)
                .take(3)
                .join(', '),
          ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 15, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.xs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(
            text,
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Live budget strip computed from the trip's real expenses.
class _BudgetStrip extends ConsumerWidget {
  const _BudgetStrip({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (AppConfig.demoMode) {
      final Budget budget = DemoFixtures.budgetFor(trip.id);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: AppCard(
          onTap: () => context.push('/trips/${trip.id}/budget'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text('Budget', style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  Text(
                    '${Money(budget.spentMinor, budget.currency).format()} of '
                    '${Money(budget.totalMinor, budget.currency).format()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              BudgetProgressBar(
                value: budget.totalMinor == 0
                    ? 0
                    : budget.spentMinor / budget.totalMinor,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: FutureBuilder<Budget>(
        future: ref
            .watch(tripRepositoryProvider)
            .budget
            .load(
              trip.id,
              dayCount: trip.dayCount,
              daysRemaining: trip.isPast ? 0 : trip.daysUntilStart,
            ),
        builder: (BuildContext context, AsyncSnapshot<Budget> snapshot) {
          if (!snapshot.hasData) {
            return const AppCard(child: SkeletonBox(height: 48));
          }
          final Budget budget = snapshot.data!;
          return AppCard(
            onTap: () => context.push('/trips/${trip.id}/budget'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'Budget',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    Text(
                      '${Money(budget.spentMinor, budget.currency).format()} of '
                      '${Money(budget.totalMinor, budget.currency).format()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                BudgetProgressBar(value: budget.utilisation),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  budget.isOverBudget
                      ? 'Over budget by ${Money(-budget.remainingMinor, budget.currency).format()}'
                      : '${Money(budget.remainingMinor, budget.currency).format()} left',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: budget.isOverBudget
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.icon,
    required this.label,
    required this.caption,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final String caption;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: primary
          ? theme.colorScheme.primary.withValues(alpha: 0.10)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: primary
                  ? theme.colorScheme.primary.withValues(alpha: 0.4)
                  : theme.colorScheme.outline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    icon,
                    size: 20,
                    color: primary
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: theme.textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                caption,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Members & invitations
// ---------------------------------------------------------------------
class MembersPage extends ConsumerStatefulWidget {
  const MembersPage({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends ConsumerState<MembersPage> {
  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<TripMember>> async = ref.watch(
      membersProvider(widget.tripId),
    );
    final AsyncValue<Trip?> tripAsync = ref.watch(currentTripProvider);
    final Trip? trip = tripAsync.value;

    return PageScaffold(
      title: 'Members',
      floatingActionButton: trip != null && trip.myRole.canAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _invite(context),
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Invite'),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, StackTrace _) => ErrorStateView(message: '$err'),
        data: (List<TripMember> members) => PageScrollView(
          // The extended Invite button floats over the list, so the clearance
          // clears it as well as the navigation bar.
          bottomClearance: 120,
          children: <Widget>[
            FadeSlideIn(
              delay: Duration(milliseconds: staggerDelayFor(0)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const InlineBanner(
                    message: 'Roles are enforced on the server. Hiding a button here does not grant or remove access â€” the database decides.',
                    tone: StatusTone.info,
                    icon: Icons.lock_outline,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  for (final TripMember m in members)
                    AppCard(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(
                        children: <Widget>[
                          MemberAvatar(initials: m.initials, size: 44),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  m.displayName,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  m.role.label,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (trip != null &&
                              trip.myRole.canAdmin &&
                              !m.role.isOwner)
                            PopupMenuButton<String>(
                              onSelected: (String value) =>
                                  _changeRole(context, m, value),
                              itemBuilder: (BuildContext context) =>
                                  <PopupMenuEntry<String>>[
                                    for (final TripRole role in <TripRole>[
                                      TripRole.admin,
                                      TripRole.editor,
                                      TripRole.viewer,
                                    ])
                                      PopupMenuItem<String>(
                                        value: role.name,
                                        child: Text('Make ${role.label}'),
                                      ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem<String>(
                                      value: 'remove',
                                      child: Text('Remove from trip'),
                                    ),
                                  ],
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            FadeSlideIn(
              delay: Duration(milliseconds: staggerDelayFor(1)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'What each role can do',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final TripRole role in TripRole.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          StatusPill(label: role.label, dense: true),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              role.description,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeRole(
    BuildContext context,
    TripMember member,
    String action,
  ) async {
    final TripRepository repo = ref.read(tripRepositoryProvider);
    try {
      if (action == 'remove') {
        final bool ok = await confirmDestructive(
          context,
          title: 'Remove ${member.displayName}?',
          message: 'They lose access to this trip immediately. Their expenses stay, because deleting them would break the balance history for everyone else.',
          confirmLabel: 'Remove',
        );
        if (!ok) return;
        await repo.removeMember(widget.tripId, member.userId);
      } else {
        await repo.updateMemberRole(
          widget.tripId,
          member.userId,
          TripRole.fromId(action),
        );
      }
      ref.invalidate(membersProvider(widget.tripId));
      if (context.mounted) showFeedback(context, 'Membership updated.');
    } catch (err) {
      if (context.mounted) {
        showFeedback(
          context,
          err is RepositoryException ? err.message : '$err',
          isError: true,
        );
      }
    }
  }

  Future<void> _invite(BuildContext context) async {
    if (AppConfig.demoMode) {
      showFeedback(
        context,
        'Invitations are disabled in demo mode.',
        isError: true,
      );
      return;
    }
    final ({String email, TripRole role})? result =
        await showAppSheet<({String email, TripRole role})>(
          context: context,
          builder: (BuildContext context) => const _InviteSheet(),
        );
    if (result == null) return;

    try {
      final InvitationResult invite = await ref
          .read(tripRepositoryProvider)
          .inviteMember(
            tripId: widget.tripId,
            email: result.email,
            role: result.role,
          );
      if (!context.mounted) return;
      await showAppSheet<void>(
        context: context,
        builder: (BuildContext context) => _InviteLinkSheet(result: invite),
      );
    } catch (err) {
      if (context.mounted) {
        showFeedback(
          context,
          err is RepositoryException ? err.message : '$err',
          isError: true,
        );
      }
    }
  }
}

class _InviteSheet extends StatefulWidget {
  const _InviteSheet();

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final TextEditingController _email = TextEditingController();
  TripRole _role = TripRole.editor;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Invite someone', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<TripRole>(
            isExpanded: true,
            initialValue: _role,
            decoration: const InputDecoration(
              labelText: 'Role',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            items: <DropdownMenuItem<TripRole>>[
              for (final TripRole role in <TripRole>[
                TripRole.admin,
                TripRole.editor,
                TripRole.viewer,
              ])
                DropdownMenuItem<TripRole>(
                  value: role,
                  child: Text(role.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (TripRole? r) => setState(() => _role = r ?? _role),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(_role.description, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () {
              final String email = _email.text.trim();
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                return;
              }
              Navigator.of(context).pop((email: email, role: _role));
            },
            child: const Text('Send invitation'),
          ),
        ],
      ),
    );
  }
}

class _InviteLinkSheet extends StatelessWidget {
  const _InviteLinkSheet({required this.result});

  final InvitationResult result;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(
            Icons.mark_email_read_outlined,
            size: 40,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Invitation created', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            result.emailSent
                ? 'An invitation was emailed to the address you entered.'
                : 'No email could be sent from this deployment. Share the link below directly.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (result.link.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: SelectableText(
                result.link,
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'The link can only be used by the invited address and expires automatically.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
