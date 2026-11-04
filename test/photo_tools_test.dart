import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/features/media/photo_tools_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
