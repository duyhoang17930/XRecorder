import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/widgets/studio_shell.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

import 'fixtures/catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const media = MethodChannel('com.xrecorder/media');
  final reads = <String>[];
  late Uint8List image;
  setUp(() {
    reads.clear();
    // Tiny synthetic PNG keeps route tests independent of GPU picture rendering.
    image = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAHgAAABQCAIAAABd+SbeAAACMElEQVR4nO3bQU4bMRTG8fdMNnQROEEQm6oXQJyjd+AEnKYH4QhVegWEVHUdCbFhEdrCc2V74nEiVeqGr+9F338xGQ8sRj9ZzsRK9PunC/Ge1WNqg/Xq993N6tvql4Rqunv23hEaFKFBERoUoUERGhShQREaFKFBERoUoUERGhShQREaFKFBERoUoUERGhShQREaFKFBERoUoUERGhShQREaFKFBERoUoUERGhShQS3EXUnETIdxLkdTSblMi5SHv8XJIfQh8Xiuw5VYLXx+vz91VrVuW5WtvphIGWh5iTHBHUL/tbZmtN9ZhMsttO1W4+ntuq7aJmWZ1nqxjAMtJMn9jaWDm4z5Xuj1qUPmpvO6apdzzdMa3cDDrNEPp9emlnJycZSJuc7heWTaudPjyeb8ZXv5/NQf+0o5iZrn4+LL9rMLYu3H9sjcBAf2CVreHte3H9Pr8uv8qPe/Ef8J+v7DlTj++eZc+7Qislxszn7+WO5mdJTHEJ9rdG9ArNO8rtFWr8fw9Qwd4qHo2KClrRglnTZAsrYdD7HpJMbUDjNlciHeM015bzPEeQ6hbW+0w9V5R6n/Q6SV2iF0ms+arFrnHtMcaTPPIfTcuCvdPq2Mw6yRPo77g879lmxenff3piPmD/pIIzQoQoMiNChCgyI0KEKDIjQoQoMiNChCgyI0KEKDIjQoQoMiNChCgyI0KEKDIjQoQoMiNChCgyI0KEKDIjQoQoMiNChCgyK0YPoDZax1qgMQD4UAAAAASUVORK5CYII=',
    );
    messenger.setMockMethodCallHandler(
      AndroidRecordingService.commands,
      (_) async => {'id': '', 'state': 'idle'},
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.xrecorder/capture/events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(media, (call) async {
      if (call.method == 'selectDestination') {
        return 'content://qa/tree/destination';
      }
      if (call.method == 'transfer') return {'moved': true, 'verified': true};
      if (call.method == 'imageBytes' || call.method == 'decodePhoto') {
        reads.add('${call.method}:${(call.arguments as Map)['uri']}');
        return image;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(AndroidEditProjectRepository.channel, (
      call,
    ) async {
      if (call.method == 'list') return <String>[];
      if (call.method == 'find') {
        reads.add('draft:${call.arguments}');
        return jsonEncode(
          EditProject(
            id: call.arguments as String,
            title: 'Draft ${call.arguments}',
            updatedAt: DateTime(2026),
            clips: [],
          ).toJson(),
        );
      }
      return null;
    });
  });
  tearDown(() {
    for (final channel in [
      media,
      AndroidRecordingService.commands,
      const MethodChannel('com.xrecorder/capture/events'),
      AndroidEditProjectRepository.channel,
    ]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  Future<GoRouter> start(WidgetTester tester) async {
    final catalog = TestCatalog();
    // XRecorderApp owns and disposes the injected repository.
    await tester.pumpWidget(XRecorderApp(mediaRepository: catalog));
    await tester.pumpAndSettle();
    return GoRouter.of(tester.element(find.byType(StudioShell)));
  }

  testWidgets('warm media links replace the displayed item identity', (
    tester,
  ) async {
    final router = await start(tester);
    try {
      router.go('/media/${Uri.encodeComponent('content://test/0')}');
      await tester.pumpAndSettle();
      expect(find.text('Clip 0.mp4'), findsOneWidget);
      router.go('/media/${Uri.encodeComponent('content://test/1')}');
      await tester.pumpAndSettle();
      expect(find.text('Clip 1.mp4'), findsOneWidget);
      expect(find.text('Clip 0.mp4'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });

  for (final screen in ['photo-preview', 'photo-tools']) {
    testWidgets('warm $screen links read the newly requested image', (
      tester,
    ) async {
      final router = await start(tester);
      final method = screen == 'photo-preview' ? 'imageBytes' : 'decodePhoto';
      try {
        router.go('/$screen/${Uri.encodeComponent('content://test/image_a')}');
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(reads, contains('$method:content://test/image_a'));
        router.go('/$screen/${Uri.encodeComponent('content://test/image_b')}');
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(reads, contains('$method:content://test/image_b'));
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
      }
    });
  }

  testWidgets('warm editor links replace the draft controller', (tester) async {
    final router = await start(tester);
    try {
      router.go('/editor/project/first');
      await tester.pumpAndSettle();
      expect(find.text('Draft first'), findsOneWidget);
      router.go('/editor/project/second');
      await tester.pumpAndSettle();
      expect(reads, contains('draft:second'));
      expect(find.text('Draft second'), findsOneWidget);
      expect(find.text('Draft first'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });

  for (final path in ['editor/project/first', 'photo-tools/fixture']) {
    testWidgets('root $path Back returns to its library without a pop error', (
      tester,
    ) async {
      final router = await start(tester);
      try {
        router.go('/$path');
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(router.canPop(), isFalse);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text(
            path.startsWith('editor') ? 'Editing Studio' : 'Photo Library',
          ),
          findsOneWidget,
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    });
  }

  testWidgets('root media details returns to library after a verified move', (
    tester,
  ) async {
    final router = await start(tester);
    try {
      router.go('/media/${Uri.encodeComponent('content://test/0')}');
      await tester.pumpAndSettle();
      expect(router.canPop(), isFalse);
      await tester.ensureVisible(find.text('Move to folder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to folder'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Choose destination'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Video Library'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('warm help links replace their selected topic', (tester) async {
    final router = await start(tester);
    try {
      router.go('/help?topic=protected-capture');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Why is a video black or silent?',
      );
      router.go('/help?topic=recording-stopped');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'What if recording fails or the phone locks?',
      );
    } finally {
      await tester.pumpWidget(const SizedBox());
    }
  });
}
