import 'package:flutter/foundation.dart';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xrecorder/features/media/photo_tools_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

import 'recording_configuration_test.dart' show state;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('OS-consented screenshot is a real catalog image', (
    tester,
  ) async {
    final capture = AndroidRecordingService();
    final media = AndroidMediaRepository();
    debugPrint('SCREENSHOT_TEST_CONSENT');
    await capture.screenshot();
    final saved = await state(capture, RecordingState.completed);
    expect(saved.screenshot, isTrue);
    final image = await media.find(saved.outputUri.toString());
    expect(image!.kind, MediaKind.image);
    expect(image.sizeBytes, greaterThan(0));
    debugPrint('SCREENSHOT_TEST_OUTPUT=${saved.outputUri}');
    const channel = MethodChannel('com.xrecorder/media');
    final bytes = await channel.invokeMethod<Uint8List>('imageBytes', {
      'uri': saved.outputUri.toString(),
    });
    final codec = await ui.instantiateImageCodec(bytes!);
    final source = (await codec.getNextFrame()).image;
    codec.dispose();
    final recorder = ui.PictureRecorder();
    PhotoPainter(source, [
      PhotoMark('Rectangle', Colors.red, [
        const Offset(.1, .1),
        const Offset(.8, .4),
      ]),
    ]).paint(
      Canvas(recorder),
      Size(source.width.toDouble(), source.height.toDouble()),
    );
    final picture = recorder.endRecording();
    final cropped = await picture.toImage(source.width, source.height ~/ 2);
    picture.dispose();
    final png = await cropped.toByteData(format: ui.ImageByteFormat.png);
    final uri = await channel.invokeMethod<String>('saveImage', {
      'bytes': png!.buffer.asUint8List(),
    });
    final copy = await media.find(uri!);
    expect(copy!.height, source.height ~/ 2);
    expect(
      (await media.find(saved.outputUri.toString()))!.height,
      source.height,
    );
    debugPrint('ANNOTATED_COPY_OUTPUT=$uri');
    cropped.dispose();
    source.dispose();
    media.dispose();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
