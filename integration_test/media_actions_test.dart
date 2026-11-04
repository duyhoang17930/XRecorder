import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/media/media_actions.dart';
import 'package:xrecorder/features/media/media_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Rename conflicts and trash restore preserve original bytes', (
    tester,
  ) async {
    const channel = MethodChannel('com.xrecorder/media');
    final media = AndroidMediaRepository();
    final actions = AndroidMediaActions();
    final recorder = ui.PictureRecorder();
    Canvas(
      recorder,
    ).drawRect(const Rect.fromLTWH(0, 0, 80, 40), Paint()..color = Colors.teal);
    final picture = recorder.endRecording();
    final image = await picture.toImage(80, 40);
    picture.dispose();
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    image.dispose();
    Future<String> save() async =>
        (await channel.invokeMethod<String>('saveImage', {'bytes': bytes}))!;
    final first = await save();
    final second = await save();
    final name = 'Actions_test_${DateTime.now().millisecondsSinceEpoch}.png';
    expect((await media.find(first))!.owned, isTrue);
    await actions.rename(Uri.parse(first), name);
    expect((await media.find(first))!.displayName, name);
    await expectLater(
      actions.rename(Uri.parse(second), name),
      throwsA(isA<DomainFailure>()),
    );
    await expectLater(
      actions.rename(Uri.parse(first), '../bad'),
      throwsA(isA<DomainFailure>()),
    );
    expect(await media.find(second), isNotNull);
    final item = (await media.find(first))!;
    final entry = await actions.trash(item);
    expect(await media.find(first), isNull);
    expect((await actions.list()).any((e) => e.id == entry.id), isTrue);
    expect(
      (await media.storage())['trash'],
      greaterThanOrEqualTo(bytes.length),
    );
    final restored = await actions.restore(entry.id);
    expect(restored.uri.toString(), isNot(first));
    expect(restored.width, 80);
    expect(restored.height, 40);
    final restoredBytes = await channel.invokeMethod<Uint8List>('imageBytes', {
      'uri': restored.uri.toString(),
    });
    expect(restoredBytes, orderedEquals(bytes));
    expect((await actions.list()).any((e) => e.id == entry.id), isFalse);
    for (final current in [restored, (await media.find(second))!]) {
      final trash = await actions.trash(current);
      await actions.permanentlyDelete(trash.id);
      expect(await media.find(current.id), isNull);
    }
    media.dispose();
  });
}
