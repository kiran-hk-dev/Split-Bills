import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural guards for the shared page system.
///
/// The design-system work was invisible in the app for a long time: the theme,
/// navigation and motion primitives were all rebuilt, while 25 of 25 feature
/// pages still opened their own opaque `Scaffold` and not one of them used the
/// responsive width cap. The app looked like the old one wearing new chrome.
///
/// These assert against the source because the invariant is about what the
/// files say, not about what one screen happens to render.
void main() {
  /// Mounted outside the app shell, so they legitimately keep a real opaque
  /// Scaffold — they are the only thing providing a canvas.
  const Set<String> outsideShell = <String>{
    'auth_shell.dart',
    'sign_in_page.dart',
    'sign_up_page.dart',
    'forgot_password_page.dart',
  };

  /// The five tab destinations are roots, not pushes: a back arrow on them
  /// either does nothing or drops the user into an unrelated tab.
  const List<String> tabRoots = <String>[
    'dashboard_page.dart',
    'trips_page.dart',
    'expenses_page.dart',
    'explore_page.dart',
    'emergency_center_page.dart',
  ];

  late Map<String, String> pages;

  setUpAll(() {
    // Only real pages. The feature tree also holds data files
    // (emergency_data, packing_template) and a helper (account_actions), none
    // of which render.
    pages = <String, String>{
      for (final File f
          in Directory('lib/features').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('_page.dart') || f.path.endsWith('auth_shell.dart'))
          f.path.split(RegExp(r'[/\\]')).last: f.readAsStringSync(),
    };
  });


  group('pages use the shared page chrome', () {
    test('no feature page opens its own opaque Scaffold', () {
      final List<String> offenders = pages.entries
          .where(
            (MapEntry<String, String> e) => !outsideShell.contains(e.key),
          )
          .where(
            (MapEntry<String, String> e) =>
                RegExp(r'(?<!Page)\bScaffold\(').hasMatch(e.value),
          )
          .map((MapEntry<String, String> e) => e.key)
          .toList();

      expect(
        offenders,
        isEmpty,
        reason: 'these pages still create their own Scaffold. Inside the app '
            'shell that paints a second opaque canvas over the first, which '
            'shows as a seam, and it blocks the shell width cap. Use '
            'PageScaffold instead. Offenders: $offenders',
      );
    });

    test('every page caps its content width', () {
      const List<String> ways = <String>[
        'PageBody(',
        'PageScrollView(',
        'PageSliverScrollView(',
        'AppBreakpoints.maxFormWidth',
        'ConstrainedBox(',
      ];

      final List<String> offenders = pages.entries
          .where(
            (MapEntry<String, String> e) => !outsideShell.contains(e.key),
          )
          .where((MapEntry<String, String> e) => !ways.any(e.value.contains))
          .map((MapEntry<String, String> e) => e.key)
          .toList();

      expect(
        offenders,
        isEmpty,
        reason: 'these pages have no width cap, so a list card or form '
            'stretches the full width of a desktop monitor. Wrap the scroll '
            'view in PageBody or PageScrollView. Offenders: $offenders',
      );
    });

    test('pages that host a scroll view leave bottom clearance', () {
      // A page whose last item can hide behind the navigation bar or a
      // floating action button is the most common layout bug on a phone.
      //
      // Detection is deliberately loose: PageScrollView defaults to 96, pages
      // sometimes use a named constant, and sometimes a bare literal. Rather
      // than trying to match every spelling and reporting false positives, this
      // only flags a page that shows no sign of reserving space at all.
      const List<String> markers = <String>[
        'PageScrollView(',
        'PageSliverScrollView(',
        'bottomClearance',
        '_bottomClearance',
        'AppSpacing.huge',
      ];

      final List<String> offenders = <String>[];
      for (final MapEntry<String, String> e in pages.entries) {
        if (outsideShell.contains(e.key)) continue;
        final bool scrolls =
            e.value.contains('ListView') || e.value.contains('CustomScrollView');
        if (!scrolls) continue;
        if (markers.any(e.value.contains)) continue;

        // Comments are stripped first: a page explaining its clearance
        // ("// clears the navigation bar") or writing the numbers across
        // several commented lines would otherwise defeat the match.
        final String code = e.value
            .split('\n')
            .where((String l) => !l.trimLeft().startsWith('//'))
            .join('\n');

        final bool bottomBig = RegExp(
          r'(?:bottom|height)\s*:\s*(9[0-9]|[1-9][0-9]{2,})',
        ).hasMatch(code) ||
            RegExp(
              r'AppSpacing\.lg,\s*(?:AppSpacing\.lg,\s*)?(9[0-9]|[1-9][0-9]{2,})',
            ).hasMatch(code);

        if (!bottomBig) offenders.add(e.key);
      }

      expect(
        offenders,
        isEmpty,
        reason: 'these scroll but reserve no bottom clearance, so the last '
            'item sits under the navigation bar. Offenders: $offenders',
      );
    });

    test('pages opt into motion rather than appearing instantly', () {
      final List<String> offenders = pages.entries
          .where(
            (MapEntry<String, String> e) => !outsideShell.contains(e.key),
          )
          .where(
            (MapEntry<String, String> e) =>
                !e.value.contains('FadeSlideIn') &&
                !e.value.contains('StaggeredColumn') &&
                !e.value.contains('AnimatedSwitcher'),
          )
          .map((MapEntry<String, String> e) => e.key)
          .toList();

      expect(
        offenders,
        isEmpty,
        reason: 'these pages have no entrance animation, so they pop in while '
            'every other page cascades. Offenders: $offenders',
      );
    });
  });

  group('tab roots are navigable', () {
    test('each tab root has no back button', () {
      for (final String name in tabRoots) {
        expect(pages.containsKey(name), isTrue, reason: '$name not found');
        final String body = pages[name]!;

        // Two acceptable shapes: the page brings no Scaffold at all and relies
        // entirely on the shell's, or it brings a PageScaffold with the back
        // button suppressed.
        final bool bringsScaffold = body.contains('PageScaffold(');
        if (!bringsScaffold) {
          expect(
            RegExp(r'(?<!Page)\bScaffold\(').hasMatch(body),
            isFalse,
            reason: '$name should use PageScaffold or none at all, never a '
                'bare Scaffold',
          );
          continue;
        }

        expect(
          body,
          contains('showBackButton: false'),
          reason: '$name is a tab root, so its PageScaffold must pass '
              'showBackButton: false',
        );
      }
    });
  });

  group('earlier bug fixes are not regressed', () {
    test('the Explore tab still returns real slivers', () {
      final String explore = pages['explore_page.dart']!;
      expect(explore, contains('..._bodySlivers('));
      // A SliverToBoxAdapter containing an Expanded is what made the whole tab
      // unrenderable.
      expect(explore, isNot(contains('Expanded(child: _buildBody')));
    });

    test('Documents still degrades instead of crashing without Supabase', () {
      final String docs = pages['documents_page.dart']!;
      expect(docs, contains('Future<List<TravelDocument>> _load()'));
      expect(docs, contains('RepositoryException'));
    });

    test('Profile still exposes sign-out independently of profile data', () {
      final String profile = pages['profile_page.dart']!;
      expect(
        profile,
        contains("Key('profile-sign-out')"),
        reason: 'a test finds the sign-out row by this key',
      );
      // Rendered in both the data and the error branch. A failed profile
      // fetch must not lock the user out of signing out.
      expect(
        RegExp(r'_menu\(context, ref\)').allMatches(profile).length,
        greaterThanOrEqualTo(2),
      );
    });

    test('the itinerary day strip still tracks the text scale', () {
      // A fixed height overflowed the strip by 2px at the default scale and
      // far more at an enlarged accessibility scale.
      expect(pages['itinerary_page.dart']!, contains('textScalerOf(context)'));
    });

    test('the trip safety card still receives real values', () {
      // It was hardcoded to empty strings and silently stopped rendering.
      expect(
        pages['destination_detail_page.dart']!,
        contains('countryCode: d.countryCode'),
      );
    });

    test('no page takes a substring of a possibly-empty member name', () {
      // `''.substring(0, 1)` threw a RangeError for members with no display
      // name. MemberAvatar normalises initials itself.
      final List<String> offenders = <String>[];
      for (final MapEntry<String, String> e in pages.entries) {
        // Strip comments so the explanatory comments about this crash do not
        // read as code.
        final String code = e.value
            .split('\n')
            .where((String l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        if (RegExp(r'\?\.?\s*\)?\s*\.substring\(').hasMatch(code) ||
            code.contains("?? '?').substring")) {
          offenders.add(e.key);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'these pages substring a name that may be empty. Pass the raw '
            'name to MemberAvatar and let it normalise. Offenders: $offenders',
      );
    });
  });

  test('the guard actually found pages to check', () {
    // Without this a path typo would make every assertion pass vacuously.
    expect(pages.length, greaterThanOrEqualTo(20));
    expect(
      pages.values.any((String v) => v.contains('PageScaffold')),
      isTrue,
    );
  });
}
