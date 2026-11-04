import 'package:flutter/material.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/editor/editor_preview.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

import 'recording_configuration_test.dart' show state;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native editor preview, persisted draft and transformed export agree',
    (tester) async {
      final capture = AndroidRecordingService();
      final media = AndroidMediaRepository();
      final drafts = AndroidEditProjectRepository();
      debugPrint('EDITOR_TEST_CAPTURE_CONSENT');
      await capture.start(
        const RecordingSettings(
          width: 1280,
          height: 720,
          fps: 30,
          bitrate: 8000000,
          countdown: Duration.zero,
          durationLimit: Duration(seconds: 6),
        ),
      );
      final saved = await state(capture, RecordingState.completed);
      final source = (await media.find(saved.outputUri.toString()))!;
      final project = EditProject(
        id: 'engine_test',
        clips: [
          TimelineClip(
            mediaId: source.id,
            inPoint: const Duration(seconds: 1),
            outPoint: const Duration(milliseconds: 2500),
            sourceDuration: source.duration!,
            rotation: 90,
            cropLeft: .1,
            cropRight: .9,
          ),
          TimelineClip(
            mediaId: source.id,
            inPoint: const Duration(seconds: 3),
            outPoint: const Duration(milliseconds: 4500),
            sourceDuration: source.duration!,
            rotation: 90,
            cropLeft: .1,
            cropRight: .9,
          ),
        ],
        updatedAt: DateTime.now(),
      );
      await drafts.save(project);
      expect(
        (await AndroidEditProjectRepository().find(project.id))!.toJson(),
        project.toJson(),
      );
      final key = GlobalKey<EditorPreviewState>();
      var position = Duration.zero;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorPreview(
              key: key,
              project: project,
              onPosition: (v) => position = v,
            ),
          ),
        ),
      );
      for (var i = 0; i < 30 && key.currentState?.channel == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      }
      expect(key.currentState?.channel, isNotNull);
      await key.currentState!.load();
      await key.currentState!.command('play');
      for (var i = 0; i < 40 && position.inMilliseconds < 1800; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await tester.pump();
      }
      expect(key.currentState!.error, isNull);
      expect(position.inMilliseconds, greaterThan(1800));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      final uri = await AndroidEditProjectRepository.channel
          .invokeMethod<String>('engineProbe', project.toJson())
          .timeout(const Duration(minutes: 2));
      final output = (await media.find(uri!))!;
      expect(output.duration!.inMilliseconds, inInclusiveRange(2800, 3300));
      expect(output.width!, greaterThan(output.height!));
      expect((await media.find(source.id))!.sizeBytes, source.sizeBytes);
      debugPrint('EDITOR_TEST_OUTPUT=$uri');
      final transformed = project.copyWith(
        effects: {
          'speed': 2.0,
          'height': 480,
          'fps': 24,
          'volume': .5,
          'pitch': 1.25,
          'music': uri,
          'musicVolume': .5,
          'filter': 'grayscale',
          'text': 'Export verification',
        },
      );
      final channel = AndroidEditProjectRepository.channel;
      final id = await channel.invokeMethod<String>(
        'exportStart',
        transformed.toJson(),
      );
      final cancelled = await channel.invokeMethod<String>(
        'exportStart',
        project.toJson(),
      );
      await channel.invokeMethod<void>('exportCancel', cancelled);
      Future<Map<String, dynamic>> job(String id) async => (jsonDecode(
        (await channel.invokeMethod<String>('exportList'))!,
      ) as List).cast<Map<String, dynamic>>().firstWhere((j) => j['id'] == id);
      expect((await job(cancelled!))['state'], 'cancelled');
      Map<String, dynamic> finished = {};
      for (var i = 0; i < 120; i++) {
        finished = await job(id!);
        if (['completed', 'failed'].contains(finished['state'])) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      expect(finished['state'], 'completed', reason: finished.toString());
      final exported = (await media.find(finished['uri'] as String))!;
      expect(exported.duration!.inMilliseconds, inInclusiveRange(1400, 1600));
      debugPrint('QUEUE_TEST_OUTPUT=${finished['uri']}');
      await channel.invokeMethod<void>('exportRetry', cancelled);
      await channel.invokeMethod<void>('exportCancel', cancelled);
      expect((await job(cancelled))['state'], 'cancelled');
      final gifId = await channel.invokeMethod<String>(
        'exportStart',
        project.copyWith(effects: {'format': 'gif', 'speed': 2.0}).toJson(),
      );
      for (var i = 0; i < 120; i++) {
        finished = await job(gifId!);
        if (['completed', 'failed'].contains(finished['state'])) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      expect(finished['state'], 'completed', reason: finished.toString());
      debugPrint('GIF_TEST_OUTPUT=${finished['uri']}');
      final portrait = project.copyWith(
        clips: project.clips
            .map(
              (clip) => clip.copyWith(rotation: 0, cropLeft: 0, cropRight: 1),
            )
            .toList(),
      );
      final portraitId = await channel.invokeMethod<String>(
        'exportStart',
        portrait.toJson(),
      );
      for (var i = 0; i < 120; i++) {
        finished = await job(portraitId!);
        if (['completed', 'failed'].contains(finished['state'])) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      expect(finished['state'], 'completed', reason: finished.toString());
      debugPrint('PORTRAIT_TEST_OUTPUT=${finished['uri']}');
      final broken = EditProject(
        id: 'missing_source',
        updatedAt: DateTime.now(),
        clips: [
          TimelineClip(
            mediaId: 'content://media/external/video/media/999999999',
            inPoint: Duration.zero,
            outPoint: const Duration(seconds: 1),
            sourceDuration: const Duration(seconds: 1),
          ),
        ],
      );
      final brokenId = await channel.invokeMethod<String>(
        'exportStart',
        broken.toJson(),
      );
      for (var i = 0; i < 30; i++) {
        finished = await job(brokenId!);
        if (['completed', 'failed'].contains(finished['state'])) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      expect(finished['state'], 'failed');
      expect(finished['uri'], isNull);
      expect((await media.find(source.id))!.sizeBytes, source.sizeBytes);
      media.dispose();
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
