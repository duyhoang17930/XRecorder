import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/features/editor/subtitles.dart';

/// Renders every subtitle style option through the native overlay that the
/// editor preview and MP4 burn-in share, and checks the pixels it draws.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const engine = MethodChannel('com.xrecorder/editor');

  Future<Uint8List> render(Map<String, Object> options) async {
    final data = (await engine.invokeMapMethod<String, dynamic>(
      'subtitleDiagnostics',
      {
        'text': 'Xin chào thế giới',
        'chunkText': 'Xin chào thế giới',
        'options': {...subtitleStyleDefaults, ...options},
      },
    ))!;
    return data['fresh'] as Uint8List;
  }

  Future<ByteData> pixels(Uint8List png) async {
    final codec = await ui.instantiateImageCodec(png);
    final image = (await codec.getNextFrame()).image;
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    image.dispose();
    return bytes;
  }

  /// Opaque pixels within [tolerance] of [rgb] (text is anti-aliased).
  int count(ByteData rgba, int rgb, {int tolerance = 40, int minAlpha = 250}) {
    final r = rgb >> 16 & 0xff, g = rgb >> 8 & 0xff, b = rgb & 0xff;
    var n = 0;
    for (var i = 0; i < rgba.lengthInBytes; i += 4) {
      if (rgba.getUint8(i + 3) < minAlpha) continue;
      if ((rgba.getUint8(i) - r).abs() <= tolerance &&
          (rgba.getUint8(i + 1) - g).abs() <= tolerance &&
          (rgba.getUint8(i + 2) - b).abs() <= tolerance) {
        n++;
      }
    }
    return n;
  }

  testWidgets('every subtitle color draws text in that color', (tester) async {
    const expected = {
      'white': 0xFFFFFF,
      'yellow': 0xFFFF00,
      'red': 0xFF5252,
      'green': 0x69F0AE,
      'cyan': 0x18FFFF,
      'blue': 0x448AFF,
      'black': 0x000000,
    };
    expect(
      expected.keys.toSet(),
      subtitleStyleOptions['subtitleColor']!.toSet(),
    );
    for (final entry in expected.entries) {
      final rgba = await pixels(
        await render({
          'subtitleColor': entry.key,
          'subtitleBackground': 'none',
        }),
      );
      final hits = count(rgba, entry.value);
      debugPrint('SUBTITLE_COLOR ${entry.key}: $hits pixels');
      expect(hits, greaterThan(150), reason: entry.key);
    }
  });

  testWidgets('each font renders differently', (tester) async {
    final images = <String, Uint8List>{};
    for (final font in subtitleStyleOptions['subtitleFont']!) {
      images[font] = await render({'subtitleFont': font});
    }
    final fonts = images.keys.toList();
    for (var i = 0; i < fonts.length; i++) {
      for (var j = i + 1; j < fonts.length; j++) {
        expect(
          listEquals(images[fonts[i]], images[fonts[j]]),
          isFalse,
          reason: '${fonts[i]} vs ${fonts[j]}',
        );
      }
    }
  });

  testWidgets('backgrounds and sizes change the drawing', (tester) async {
    Future<int> boxPixels(String background, int rgb) async => count(
      await pixels(await render({'subtitleBackground': background})),
      rgb,
      tolerance: 6,
      minAlpha: 0xC0,
    );
    // Dark box is 0xCC000000; light box is 0xCCFFFFFF (text stays white).
    expect(await boxPixels('dark', 0x000000), greaterThan(1000));
    expect(await boxPixels('none', 0x000000), lessThan(200));
    final light = await pixels(
      await render({'subtitleBackground': 'light', 'subtitleColor': 'black'}),
    );
    // rawRgba is premultiplied: 80% white reads back as 0xCCCCCC.
    expect(
      count(light, 0xCCCCCC, tolerance: 6, minAlpha: 0xC0),
      greaterThan(1000),
    );

    int inked(ByteData rgba) {
      var n = 0;
      for (var i = 3; i < rgba.lengthInBytes; i += 4) {
        if (rgba.getUint8(i) > 0) n++;
      }
      return n;
    }

    final small = inked(await pixels(await render({'subtitleSize': 'small'})));
    final large = inked(await pixels(await render({'subtitleSize': 'large'})));
    debugPrint('SUBTITLE_SIZE small=$small large=$large');
    expect(large, greaterThan(small));
  });

  testWidgets('unknown style values are rejected, not drawn', (tester) async {
    for (final bad in [
      {'subtitleColor': 'purple'},
      {'subtitleFont': 'comic'},
      {'subtitleBackground': 'blur'},
    ]) {
      await expectLater(
        render(bad),
        throwsA(isA<PlatformException>()),
        reason: '$bad',
      );
    }
  });
}
