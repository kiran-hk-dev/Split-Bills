import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/shared/widgets/trip_cover.dart';

/// A bundled cover has to live in the same `cover_image_url` column as an
/// uploaded photo, which means the column holds two kinds of value. These pin
/// how they are told apart and that every bundled path actually exists.
void main() {
  group('cover url contract', () {
    test('a bundled cover round-trips', () {
      for (final ({String path, String label}) o in TripCovers.options) {
        final String url = TripCovers.urlFor(o.path);
        expect(url, startsWith(assetCoverPrefix));
        expect(
          TripCovers.bundledPathOf(url),
          o.path,
          reason: '${o.label} did not round-trip',
        );
      }
    });

    test('an uploaded photo is not mistaken for a bundled cover', () {
      for (final String url in <String>[
        'https://images.unsplash.com/photo-1536599018102',
        'https://qippwejcvhbikshpnndj.supabase.co/storage/v1/object/public/'
            'trip-covers/uuid/trip/1.jpg',
      ]) {
        expect(TripCovers.bundledPathOf(url), isNull);
      }
    });

    test('no cover means no bundled path', () {
      expect(TripCovers.bundledPathOf(null), isNull);
      expect(TripCovers.bundledPathOf(''), isNull);
    });

    test('every bundled cover is declared exactly once', () {
      final Set<String> paths =
          TripCovers.options.map((({String path, String label}) o) => o.path).toSet();
      expect(paths.length, TripCovers.options.length);
    });

    test('every bundled cover is named and labelled', () {
      for (final ({String path, String label}) o in TripCovers.options) {
        expect(o.path, startsWith('assets/covers/'));
        expect(o.label, isNotEmpty);
        // The label is what the gallery shows and what a screen reader reads.
        expect(TripCovers.labelForPath(o.path), o.label);
      }
    });

    test('an unknown path still yields a label rather than throwing', () {
      expect(TripCovers.labelForPath('assets/covers/nope.jpg'), 'Cover');
    });
  });

  group('TripCover renders a bundled cover', () {
    testWidgets('shows the asset rather than attempting a network fetch', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TripCover(
              seed: 'JP:Tokyo',
              imageUrl: TripCovers.urlFor(TripCovers.options.first.path),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('falls back to painted artwork for no cover at all', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TripCover(seed: 'JP:Tokyo')),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      // No image, so the painted landscape is what remains.
      expect(find.byType(Image), findsNothing);
    });
  });

  group('the covers are really bundled', () {
    test('every declared cover exists on disk', () {
      // Checks the file system rather than rootBundle on purpose: `flutter
      // test` does not bundle pubspec assets into rootBundle, so a
      // rootBundle assertion would fail for assets that are perfectly fine -
      // brand_logo.png fails it too.
      //
      // What this actually guards is the failure that matters: a misspelled
      // path or a folder missing from pubspec.yaml would leave the cover
      // silently falling back to the painted landscape, which is the exact
      // problem these covers exist to solve.
      for (final ({String path, String label}) o in TripCovers.options) {
        final File file = File(o.path);
        expect(
          file.existsSync(),
          isTrue,
          reason: '${o.label}: ${o.path} is missing',
        );
        expect(
          file.lengthSync(),
          greaterThan(1024),
          reason: '${o.label}: ${o.path} is suspiciously small',
        );
        final List<int> head = file.readAsBytesSync().take(3).toList();
        expect(
          head[0],
          0xFF,
          reason: '${o.label}: ${o.path} is not a JPEG',
        );
        expect(head[1], 0xD8, reason: '${o.label}: ${o.path} is not a JPEG');
      }
    });

    test('every declared cover is under a folder declared in pubspec', () {
      // The bug this guards: `assets:` sat at column zero instead of nested
      // under `flutter:`, so it parsed as an unknown top-level key and Flutter
      // ignored the whole block. Every asset listed below it was silently
      // dropped from every web build - the brand logo and the onboarding
      // artwork included - while `flutter build` still reported success.
      final List<String> lines = File('pubspec.yaml').readAsLinesSync();
      int? assetsLine;
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].trim() == 'assets:') {
          assetsLine = i;
          break;
        }
      }
      expect(assetsLine, isNotNull, reason: 'no assets: key in pubspec');
      expect(
        lines[assetsLine!].startsWith(' '),
        isTrue,
        reason: 'assets: is not indented, so it is a top-level key and Flutter '
            'ignores it along with every folder listed under it',
      );

      final String pubspec = File('pubspec.yaml').readAsStringSync();
      for (final ({String path, String label}) o in TripCovers.options) {
        final String folder = o.path.substring(0, o.path.lastIndexOf('/') + 1);
        expect(
          pubspec.contains('- $folder'),
          isTrue,
          reason: '$folder is not declared in pubspec.yaml, so ${o.label} '
              'would never be bundled',
        );
      }
    });
  });
}