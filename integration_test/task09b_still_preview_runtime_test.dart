import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/editor/editor_preview.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/media/media_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('paused still preview actually displays the original image', (
    tester,
  ) async {
    binding.reportData = {'status': 'IN_PROGRESS'};
    const uri = 'content://media/external/images/media/28';
    final source = (await AndroidMediaRepository.channel
        .invokeMethod<List<int>>('imageBytes', {'uri': uri}))!;
    final run = DateTime.now().microsecondsSinceEpoch;
    final backup = File(
      '/data/user/0/com.xrecorder.xrecorder/files/task09b_still_${run}_source.png',
    );
    await backup.create(exclusive: true);
    await backup.writeAsBytes(source, flush: true);
    final key = GlobalKey<EditorPreviewState>();
    final project = EditProject(
      id: 'task09b_still_$run',
      updatedAt: DateTime.now(),
      clips: [
        TimelineClip(
          mediaId: uri,
          isImage: true,
          inPoint: Duration.zero,
          outPoint: const Duration(seconds: 4),
          sourceDuration: const Duration(seconds: 4),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPreview(key: key, project: project, onPosition: (_) {}),
        ),
      ),
    );
    Map<String, dynamic>? state;
    try {
      for (var i = 0; i < 200; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        if (key.currentState?.channel == null) continue;
        state = await key.currentState!.channel!
            .invokeMapMethod<String, dynamic>('state');
        expect(state!['error'], isNull);
        if (state['playbackState'] == 3) break;
      }
      expect(state?['playbackState'], 3);
      expect(state!['playing'], isFalse);
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump();
      final rectangle = tester.getRect(find.byType(PlatformViewLink));
      final request = File(
        '/data/user/0/com.xrecorder.xrecorder/files/task09b_still_$run.request.json',
      );
      await request.create(exclusive: true);
      await request.writeAsString(
        jsonEncode({
          'run': run,
          'source': backup.path,
          'uri': uri,
          'nativeState': state,
          'dpr': tester.view.devicePixelRatio,
          'rect': [
            rectangle.left,
            rectangle.top,
            rectangle.right,
            rectangle.bottom,
          ],
        }),
        flush: true,
      );
      final ack = File('${request.path}.ack');
      for (var i = 0; i < 600 && !await ack.exists(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
      expect(await ack.exists(), isTrue);
      final pixels =
          jsonDecode(await ack.readAsString()) as Map<String, dynamic>;
      binding.reportData = {
        'status': 'IN_PROGRESS',
        'request': request.path,
        'nativeState': state,
        'pixels': pixels,
      };
      expect(
        pixels['status'],
        'PASS',
        reason: 'Actual Android screenshot must show the source while paused.',
      );
      expect(
        await AndroidMediaRepository.channel.invokeMethod<List<int>>(
          'imageBytes',
          {'uri': uri},
        ),
        orderedEquals(source),
      );
      binding.reportData = {
        ...binding.reportData!,
        'status': 'PASS',
        'sourceBytesExact': true,
      };
    } finally {
      await tester.pumpWidget(const SizedBox());
      for (var i = 0; i < 150; i++) {
        await tester.pump();
        final diagnostics = await AndroidEditProjectRepository.channel
            .invokeMapMethod<String, dynamic>('editorDiagnostics');
        if (diagnostics!['activePreviews'] == 0) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
