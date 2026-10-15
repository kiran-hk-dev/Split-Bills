import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/data/repositories.dart';

/// A trip cover photo was impossible to add: `cover_image_url` existed, the
/// renderer honoured it, `image_picker` was already a dependency, and none of
/// it was ever wired together. These cover the parts that are pure logic.
void main() {
  group('coverExtensionFor', () {
    test('keeps the extension the file actually has', () {
      expect(coverExtensionFor('trip.jpg', 'image/jpeg'), '.jpg');
      expect(coverExtensionFor('TRIP.JPEG', 'image/jpeg'), '.jpeg');
      expect(coverExtensionFor('holiday.png', 'image/png'), '.png');
      expect(coverExtensionFor('beach.webp', 'image/webp'), '.webp');
    });

    test('ignores a query string some pickers append', () {
      expect(coverExtensionFor('photo.jpg?crop=1', 'image/jpeg'), '.jpg');
    });

    test('falls back to the mime type when the name has no extension', () {
      expect(coverExtensionFor('clipboard', 'image/png'), '.png');
      expect(coverExtensionFor('clipboard', 'image/webp'), '.webp');
    });

    test('never returns an extension the bucket would reject', () {
      for (final String name in <String>['a.heic', 'a.gif', 'a', 'a.svg']) {
        expect(
          <String>['.jpg', '.jpeg', '.png', '.webp'],
          contains(coverExtensionFor(name, 'image/jpeg')),
          reason: '$name produced an unexpected extension',
        );
      }
    });
  });

  group('tripCoverMimeTypes', () {
    test('accepts what browsers actually hand over', () {
      expect(tripCoverMimeTypes, contains('image/jpeg'));
      expect(tripCoverMimeTypes, contains('image/png'));
      expect(tripCoverMimeTypes, contains('image/webp'));
    });

    test('excludes HEIC, the iPhone default', () {
      // An iPhone photo is HEIC. The bucket rejects it, so it has to be
      // caught before upload with an explanation rather than surfacing as an
      // opaque storage error.
      expect(tripCoverMimeTypes, isNot(contains('image/heic')));
      expect(tripCoverMimeTypes, isNot(contains('image/heif')));
    });
  });
}