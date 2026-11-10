import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/editor/editor_preview.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/editor/transcription_service.dart';

import 'p2_p3_audio_layers_test.dart' as audio;
import 'p2_p3_native_test.dart' as media;
import 'p2_p3_photo_subtitle_test.dart' as photo;
import 'p2_p3_whisper_test.dart' as speech;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final reports = <String, Object?>{};
  const names = [
    'speech',
    'audio',
    'photo',
    'media',
    'rapidPreview',
    'longSpeech',
  ];
  var index = 0;
  setUp(() => binding.reportData = null);
  tearDown(() {
    reports[names[index++]] = binding.reportData;
    binding.reportData = {'suites': Map<String, Object?>.of(reports)};
  });
  // Reuse actual native output/assertion suites without Flutter's installer.
  speech.main();
  audio.main();
  photo.main();
  media.main();

  testWidgets('TASK09 rapid edits reach the real latest preview and export', (
    tester,
  ) async {
    const engine = AndroidEditProjectRepository.channel;
    final source = File(
      '/data/user/0/com.xrecorder.xrecorder/files/trash/p2_p3_audio_video.mp4',
    );
    final original = await source.readAsBytes();
    var project = EditProject(
      id: 'task09_rapid_${DateTime.now().microsecondsSinceEpoch}',
      updatedAt: DateTime.now(),
      clips: [
        TimelineClip(
          mediaId: 'content://com.xrecorder.xrecorder.files/trash/p2_p3_audio_video.mp4',
          inPoint: Duration.zero,
          outPoint: const Duration(seconds: 4),
          sourceDuration: const Duration(seconds: 4),
        ),
      ],
      effects: {'speed': 1.0},
    );
    final key = GlobalKey<EditorPreviewState>();
    Future<void> mount() => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPreview(key: key, project: project, onPosition: (_) {}),
        ),
      ),
    );
    await mount();
    for (var i = 0; i < 100 && key.currentState?.channel == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    }
    expect(key.currentState?.channel, isNotNull);
    await key.currentState!.load();
    await key.currentState!.command('play');
    project = project.copyWith(effects: {'speed': .5, 'volume': .4});
    await mount();
    project = project.copyWith(effects: {'speed': 2.0, 'volume': .2});
    await mount();
    // This duplicate load waits for all accepted pending updates to drain.
    await key.currentState!.load();
    await key.currentState!.command('play');
    Map<String, dynamic>? latest;
    for (var i = 0; i < 150; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      latest = await key.currentState!.channel!
          .invokeMapMethod<String, dynamic>('state');
      expect(latest!['error'], isNull);
      if (latest['renderedFirstFrame'] == true &&
          latest['playbackState'] == 3) {
        break;
      }
    }
    expect(latest!['renderedFirstFrame'], isTrue);
    expect(latest['durationMs'], inInclusiveRange(1950, 2050));
    expect(key.currentState!.error, isNull);
    await tester.pumpWidget(const SizedBox());
    Map<String, dynamic>? diagnostics;
    for (var i = 0; i < 150; i++) {
      diagnostics = await engine.invokeMapMethod<String, dynamic>(
        'editorDiagnostics',
      );
      if (diagnostics!['activePreviews'] == 0) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(diagnostics!['activePreviews'], 0);
    expect(diagnostics['previewReleaseFailures'], 0);
    final output = await engine.invokeMethod<String>(
      'engineProbe',
      project.toJson(),
    );
    expect(output, startsWith('content://'));
    expect(await source.readAsBytes(), orderedEquals(original));
    binding.reportData = {
      'latestSpeed': 2,
      'nativePreview': latest,
      'diagnostics': diagnostics,
      'output': output,
      'expectedDurationMs': 2000,
      'sourcePreserved': true,
    };
  }, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('TASK09 actual ten-minute boundary and over-limit rejection', (
    tester,
  ) async {
    const service = AndroidTranscriptionService();
    const channel = AndroidTranscriptionService.channel;
    const uri =
        'content://com.xrecorder.xrecorder.files/trash/task08_fleurs_en_repeat_600s_v1.wav';
    final id = await service.start(
      TranscriptionRequest(
        audioUri: Uri.parse(uri),
        durationMs: 600000,
        language: 'en',
        model: 'tiny',
        operationId: 'task09_long_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    TranscriptionJob? terminal;
    for (var i = 0; i < 1200; i++) {
      final job = await service.poll(id, 600000);
      if (![
        TranscriptionState.queued,
        TranscriptionState.running,
      ].contains(job.state)) {
        terminal = job;
        break;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    final native = await channel.invokeMapMethod<String, dynamic>(
      'transcriptionPoll',
      id,
    );
    binding.reportData = {
      'job': native,
      'inputDurationMs': 600000,
      'inputKind': 'Repeated licensed FLEURS speech for stress, not natural long-form accuracy.',
    };
    expect(
      terminal?.state,
      TranscriptionState.completed,
      reason: terminal?.error,
    );
    expect(native!['inferenceMs'] as num, greaterThan(0));
    expect(terminal!.cues, isNotEmpty);
    expect(terminal.cues.last.endMs, greaterThan(570000));
    await expectLater(
      channel.invokeMethod<String>('transcriptionStart', {
        'model': 'tiny',
        'language': 'en',
        'audioUri': uri,
        'durationMs': 600001,
        'operationId':
            'task09_over_limit_${DateTime.now().microsecondsSinceEpoch}',
      }),
      throwsA(isA<PlatformException>()),
    );
  }, timeout: const Timeout(Duration(minutes: 22)));
}
