import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xrecorder/core/domain/models.dart';

import 'catalog.dart';

/// Test-only media: no user files, recording sessions or drafts are created.
class VisualCatalog extends TestCatalog {
  VisualCatalog(this.image) {
    items.clear();
    for (var i = 0; i < 30; i++) {
      items.add(
        MediaItem(
          id: 'content://ui-fixture/$i',
          uri: Uri.parse('content://ui-fixture/$i'),
          kind: MediaKind.video,
          displayName:
              'Studio fixture ${(i + 1).toString().padLeft(2, '0')}.mp4',
          mimeType: 'video/mp4',
          sizeBytes: 12000000 + i * 1024000,
          duration: Duration(seconds: 42 + i * 13),
          createdAt: DateTime(2026, 11, 5),
          modifiedAt: DateTime(2026, 11, 5),
          source: MediaSource.recording,
        ),
      );
    }
  }
  final Uint8List image;
  @override
  Future<Uint8List> thumbnail(Uri uri) async => image;
}

Future<Uint8List> fixtureImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 320, 180),
    Paint()..color = const Color(0xFF25344A),
  );
  canvas.drawCircle(
    const Offset(240, 50),
    70,
    Paint()..color = const Color(0xFF476C89),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(30, 36, 116, 110),
      const Radius.circular(12),
    ),
    Paint()..color = const Color(0xFFFF7948),
  );
  for (var i = 0; i < 4; i++) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(170, 95 + i * 14, 90 - i * 10, 5),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFBDEDE4),
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(320, 180);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}
