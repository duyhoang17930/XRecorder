import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/features/media/photo_tools_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
