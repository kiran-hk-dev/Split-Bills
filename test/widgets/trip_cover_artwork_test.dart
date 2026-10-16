import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripsplit_world/shared/widgets/trip_cover.dart';

/// Rasterises a [TripCover] and inspects the pixels.
///
/// The complaint was that trip covers are "just empty". A widget test that only
/// checks for the absence of exceptions cannot tell an empty box from a painted
/// one — both render cleanly. This captures the real pixels and asserts the
/// artwork has genuine tonal range, which a flat placeholder never would.
void main() {
  /// Paints a cover and returns its RGBA pixels.
  ///
  /// `toImage` has to run inside `runAsync`: the fake async zone the test body
  /// runs in never pumps the real rasterizer, so awaiting it directly hangs.
  Future<Uint8List> renderCover(WidgetTester tester, String seed) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: const Key('cover-boundary'),
            child: SizedBox(
              width: 320,
              height: 140,
              child: TripCover(seed: seed, showScrim: false),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // Park the drift on a representative frame rather than frame zero.
    await tester.pump(const Duration(milliseconds: 3500));

    final RenderRepaintBoundary boundary =
        tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('cover-boundary')),
        );

    late Uint8List bytes;
    await tester.runAsync(() async {
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final ByteData? data = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      bytes = data!.buffer.asUint8List();
      image.dispose();
    });
    return bytes;
  }

  /// Mean luminance per row, used to measure tonal spread down the image.
  double verticalSpread(Uint8List bytes, int width, int height) {
    double minRow = double.infinity;
    double maxRow = -double.infinity;
    for (int y = 0; y < height; y++) {
      double total = 0;
      for (int x = 0; x < width; x++) {
        final int i = (y * width + x) * 4;
        total +=
            0.2126 * bytes[i] + 0.7152 * bytes[i + 1] + 0.0722 * bytes[i + 2];
      }
      final double mean = total / width;
      if (mean < minRow) minRow = mean;
      if (mean > maxRow) maxRow = mean;
    }
    return maxRow - minRow;
  }

  /// Mean RGB across the cover, bucketed so trivial differences do not count.
  String meanColour(Uint8List bytes) {
    double r = 0, g = 0, b = 0;
    final int pixels = bytes.length ~/ 4;
    for (int i = 0; i < bytes.length; i += 4) {
      r += bytes[i];
      g += bytes[i + 1];
      b += bytes[i + 2];
    }
    // Quantised to steps of 12 per channel.
    return '${(r / pixels / 12).round()}-${(g / pixels / 12).round()}-'
        '${(b / pixels / 12).round()}';
  }

  testWidgets('cover artwork is painted, not a flat fill', (    WidgetTester tester,
  ) async {
    final Uint8List bytes = await renderCover(tester, 'JP:Tokyo');

    final Set<int> colours = <int>{};
    for (int i = 0; i < bytes.length; i += 4) {
      colours.add((bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2]);
    }

    // A flat duotone with no blobs, sweep or vignette lands in the low
    // hundreds of distinct colours. Painted artwork lands in the thousands.
    expect(
      colours.length,
      greaterThan(1500),
      reason: 'only ${colours.length} distinct colours — the cover looks flat '
          'or empty',
    );

    // And it must run from darker to lighter, rather than being uniform.
    final double spread = verticalSpread(bytes, 320, 140);
    expect(
      spread,
      greaterThan(18),
      reason: 'vertical tonal spread was only ${spread.toStringAsFixed(1)}',
    );
  });

  testWidgets('palettes are distinguishable across the whole cover', (
    WidgetTester tester,
  ) async {
    // Mean colour rather than one pixel: a single pixel sits under whatever
    // blob, sweep and vignette happen to land on it, so it says more about
    // the composition than the palette.
    final Set<String> signatures = <String>{};

    for (final String seed in <String>[
      'JP:Tokyo',
      'IN:Goa',
      'TH:Bangkok',
      'FR:Paris',
      'IS:Reykjavik',
      'PE:Cusco',
      'NZ:Queenstown',
      'MA:Marrakech',
    ]) {
      final Uint8List bytes = await renderCover(tester, seed);
      signatures.add(meanColour(bytes));
    }

    expect(
      signatures.length,
      greaterThanOrEqualTo(6),
      reason: 'the 8 palettes produced only ${signatures.length} distinct mean '
          'colours, so trips look too alike',
    );
  });

testWidgets('every cover palette sits inside the brand arc', (
    WidgetTester tester,
  ) async {
    // This test used to assert the opposite: that no palette fell in the
    // 90-195 green-to-cyan band, because the brand was ember and that band
    // read as a clash. The brand is blue now, so cyan is in-family and the
    // band that clashes is the warm one. The property worth keeping is the
    // same either way: the covers belong to the brand.
    for (int i = 0; i < 8; i++) {
      final List<Color> palette = TripCover.paletteFor('$i:seed');
      expect(palette, hasLength(3));

      for (final Color c in palette) {
        final double hue = HSVColor.fromColor(c).hue;
        final bool inBrandArc = hue >= 175 && hue <= 250;
        expect(
          inBrandArc,
          isTrue,
          reason: 'palette $i contains $c at hue ${hue.toStringAsFixed(0)}, '
              'outside the blue brand arc',
        );
      }
    }
  });

  testWidgets('a cover is one hue end to end, not two meeting', (
    WidgetTester tester,
  ) async {
    // The ramp is built from lightness alone. A shade that crosses 0 degrees
    // on the hue wheel would wrap maroon into rose and reintroduce exactly the
    // two-colour look this replaced.
    for (int i = 0; i < 8; i++) {
      final List<double> hues = TripCover.paletteFor('$i:seed')
          .map((c) => HSLColor.fromColor(c).hue)
          .toList();
      for (final double h in hues) {
        expect(
          h,
          lessThan(359.5),
          reason: 'seed $i wrapped the hue wheel at $h, so the ramp splits '
              'into two colours',
        );
      }
    }
  });
}
