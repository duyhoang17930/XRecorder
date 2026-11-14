import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/features/media/photo_tools_screen.dart';

import 'fixtures/visual_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('photo annotations preserve relative text size and stroke width at thumbnail scale', () async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 320, 640),
      Paint()..color = Colors.black,
    );
    final picture = recorder.endRecording();
    final source = await picture.toImage(320, 640);
    picture.dispose();
    final marks = [
      PhotoMark('Text', Colors.cyan, [const Offset(.2, .2)], text: 'QA'),
      PhotoMark('Pen', Colors.red, [
        const Offset(.1, .7),
        const Offset(.9, .7),
      ], width: .006),
    ];
    Future<({int textWidth, int textHeight, double redEnergy})> measure(
      int width,
    ) async {
      final recorder = ui.PictureRecorder();
      PhotoPainter(
        source,
        marks,
      ).paint(Canvas(recorder), Size(width.toDouble(), width * 2.0));
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, width * 2);
      picture.dispose();
      final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
      image.dispose();
      var left = width, top = width * 2, right = -1, bottom = -1;
      var red = 0.0;
      for (var y = 0; y < width * 2; y++) {
        for (var x = 0; x < width; x++) {
          final i = (y * width + x) * 4;
          if (y < width &&
              rgba[i] < 20 &&
              rgba[i + 1] > 100 &&
              rgba[i + 2] > 100) {
            if (x < left) left = x;
            if (x > right) right = x;
            if (y < top) top = y;
            if (y > bottom) bottom = y;
          }
          if (y > width) red += rgba[i];
        }
      }
      return (
        textWidth: right - left + 1,
        textHeight: bottom - top + 1,
        redEnergy: red,
      );
    }

    final full = await measure(320), half = await measure(160);
    expect(full.textWidth, greaterThan(0));
    expect(full.textHeight, greaterThan(0));
    expect((half.textWidth * 2 - full.textWidth).abs(), lessThanOrEqualTo(3));
    expect((half.textHeight * 2 - full.textHeight).abs(), lessThanOrEqualTo(3));
    expect(half.redEnergy * 4 / full.redEnergy, inInclusiveRange(.8, 1.2));
    source.dispose();
  });

  for (final tool in ['Star', 'Heart']) {
    test(
      '$tool sticker stays within its dragged box and preserves source',
      () async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 32, 32),
          Paint()..color = Colors.black,
        );
        final picture = recorder.endRecording();
        final source = await picture.toImage(32, 32);
        picture.dispose();
        final points = [const Offset(.25, .25), const Offset(.75, .75)];
        Future<List<int>> rendered(List<Offset> points) async {
          final result = await renderPhotoCopy(source, [
            PhotoMark(tool, Colors.cyan, points),
          ], const Rect.fromLTWH(0, 0, 32, 32));
          final bytes = (await result.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List().toList();
          result.dispose();
          return bytes;
        }

        final actual = await rendered(points);
        expect(await rendered(points.reversed.toList()), actual);
        var colored = 0;
        for (var y = 0; y < 32; y++) {
          for (var x = 0; x < 32; x++) {
            final i = (y * 32 + x) * 4;
            if (actual[i + 1] > 10 || actual[i + 2] > 10) {
              colored++;
              expect(x, inInclusiveRange(7, 24));
              expect(y, inInclusiveRange(7, 24));
            }
            expect(actual[i + 3], 255);
          }
        }
        expect(colored, inInclusiveRange(50, 256));
        int green(int x, int y) => actual[(y * 32 + x) * 4 + 1];
        // A rectangle fallback must fail this shape oracle.
        expect(green(9, 9), 0);
        expect(green(16, 16), greaterThan(100));
        if (tool == 'Star') {
          expect(green(16, 11), greaterThan(50));
        } else {
          expect(
            green(16, 10),
            0,
          ); // The heart's central top notch stays empty.
        }
        final original = (await source.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        for (var i = 0; i < original.length; i += 4) {
          expect(original.sublist(i, i + 4), [0, 0, 0, 255]);
        }
        source.dispose();
      },
    );
  }

  testWidgets(
    'photo Sticker picker is reachable and Undo/Redo preserve placement',
    (tester) async {
      const channel = MethodChannel('com.xrecorder/media');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final bytes = (await tester.runAsync(fixtureImage))!;
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'decodePhoto' ? bytes : null,
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        const MaterialApp(home: PhotoToolsScreen(uri: 'content://qa/sticker')),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('All tools'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Star'));
      await tester.pumpAndSettle();
      expect(
        find.text('Drag across the photo to size and place the sticker.'),
        findsOneWidget,
      );
      final surface = find.byKey(const ValueKey('photo-drawing-surface'));
      final rect = tester.getRect(surface);
      final gesture = await tester.startGesture(
        rect.topLeft + Offset(rect.width * .25, rect.height * .25),
      );
      await gesture.moveBy(Offset(rect.width * .5, rect.height * .5));
      await gesture.up();
      await tester.pumpAndSettle();
      PhotoPainter painter() =>
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: surface,
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as PhotoPainter;
      expect(painter().marks.single.tool, 'Star');
      await tester.tap(find.byTooltip('Undo photo edit'));
      await tester.pumpAndSettle();
      expect(painter().marks, isEmpty);
      await tester.tap(find.byTooltip('Redo photo edit'));
      await tester.pumpAndSettle();
      expect(painter().marks.single.tool, 'Star');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'stroke width stays in range at gesture endpoints and tool changes',
    (tester) async {
      const channel = MethodChannel('com.xrecorder/media');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final bytes = (await tester.runAsync(fixtureImage))!;
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'decodePhoto' ? bytes : null,
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await tester.pumpWidget(
        const MaterialApp(home: PhotoToolsScreen(uri: 'content://qa/slider')),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
      final finder = find.byType(Slider);
      for (var i = 0; i < 8; i++) {
        final slider = tester.widget<Slider>(finder);
        // Flutter Slider._lerp(1): floating-point rounding can exceed max.
        slider.onChanged!((slider.max - slider.min) + slider.min);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
          tester.widget<Slider>(finder).value,
          lessThanOrEqualTo(slider.max),
        );
        tester.widget<Slider>(finder).onChanged!(slider.min);
        await tester.pump();
        expect(tester.widget<Slider>(finder).value, slider.min);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'photo crop, clockwise rotation and flip preserve source pixels',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 4, 2),
        Paint()..color = const Color(0xFF0000FF),
      );
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 2, 2),
        Paint()..color = const Color(0xFFFF0000),
      );
      final picture = recorder.endRecording();
      final source = await picture.toImage(4, 2);
      picture.dispose();
      final output = await renderPhotoCopy(
        source,
        [],
        const Rect.fromLTWH(0, 0, 4, 2),
        turns: 1,
      );
      expect((output.width, output.height), (2, 4));
      final pixels = (await output.toByteData())!.buffer.asUint8List();
      expect(pixels[0], 255);
      expect(pixels[(3 * 2) * 4 + 2], 255);
      final flipped = await renderPhotoCopy(
        source,
        [],
        const Rect.fromLTWH(0, 0, 4, 2),
        flipH: true,
      );
      final flippedPixels = (await flipped.toByteData())!.buffer.asUint8List();
      expect(flippedPixels[2], 255);
      expect(flippedPixels[3 * 4], 255);
      final cropped = await renderPhotoCopy(
        source,
        [],
        const Rect.fromLTWH(2, 0, 2, 2),
      );
      expect((cropped.width, cropped.height), (2, 2));
      expect((await cropped.toByteData())!.buffer.asUint8List()[2], 255);
      expect((await source.toByteData())!.buffer.asUint8List()[0], 255);
      source.dispose();
      output.dispose();
      flipped.dispose();
      cropped.dispose();
    },
  );
  test(
    'Annotations burn into derived pixels without modifying source',
    () async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 100, 100),
        Paint()..color = Colors.blue,
      );
      final picture = recorder.endRecording();
      final source = await picture.toImage(100, 100);
      picture.dispose();
      final derivedRecorder = ui.PictureRecorder();
      PhotoPainter(source, [
        PhotoMark('Pen', Colors.red, [
          const Offset(.2, .5),
          const Offset(.8, .5),
        ]),
      ]).paint(Canvas(derivedRecorder), const Size(100, 100));
      final derivedPicture = derivedRecorder.endRecording();
      final derived = await derivedPicture.toImage(100, 100);
      derivedPicture.dispose();
      final pixels = (await derived.toByteData())!.buffer.asUint8List();
      final original = (await source.toByteData())!.buffer.asUint8List();
      final center = (50 * 100 + 50) * 4;
      expect(pixels[center], Colors.red.r * 255);
      expect(original[center + 2], Colors.blue.b * 255);
      expect(pixels[center], isNot(original[center]));
      derived.dispose();
      source.dispose();
    },
  );
}
