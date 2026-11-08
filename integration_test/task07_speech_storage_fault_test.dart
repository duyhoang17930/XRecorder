import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/features/editor/transcription_service.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/persistence/settings_store.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';
import 'package:xrecorder/l10n/app_languages.dart';

// Run only on an isolated TASK07 QA AVD with app-owned fixtures. The blocked
// AtomicFile path and all backups are retained; no media or model is deleted.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Real speech history handles unavailable storage safely', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Speech storage fault QA'))),
    );
    const channel = AndroidTranscriptionService.channel;
    const service = AndroidTranscriptionService();
    const private = '/data/user/0/com.xrecorder.xrecorder/files/';
    final journal = File('${private}transcription_jobs.json');
    final readOnlyFixture = File('${private}task07_readonly_expectation.json');
    if (const bool.fromEnvironment('HISTORY_READONLY') ||
        await readOnlyFixture.exists()) {
      final before = await journal.readAsBytes();
      final expected = base64Decode(
        await readOnlyFixture.exists()
            ? jsonDecode(await readOnlyFixture.readAsString())['bytes']
                  as String
            : const String.fromEnvironment('HISTORY_BYTES'),
      );
      expect(before, expected);
      final unavailable = throwsA(
        isA<PlatformException>().having(
          (v) => v.code,
          'code',
          'history_unavailable',
        ),
      );
      await expectLater(
        channel.invokeMethod<dynamic>('transcriptionJobs'),
        unavailable,
      );
      await expectLater(
        channel.invokeMethod<dynamic>('transcriptionStart', {
          'audioUri':
              'content://com.xrecorder.xrecorder.files/trash/fleurs_en.wav',
          'durationMs': 10000,
          'model': 'tiny',
          'language': 'en',
          'operationId':
              'task07_readonly_${DateTime.now().microsecondsSinceEpoch}',
        }),
        unavailable,
      );
      await expectLater(
        channel.invokeMethod<dynamic>(
          'transcriptionSaveHistory',
          'task07_readonly',
        ),
        unavailable,
      );
      expect(await journal.readAsBytes(), before);
      binding.reportData = {
        'readOnlyFailureVisible': true,
        'startRejected': true,
        'retryRejected': true,
        'exactBytesPreserved': true,
        'bytes': before.length,
      };
      return;
    }
    // This phase is deliberately restricted to a fresh QA app store. It never
    // edits existing device preferences or capture behavior.
    const store = AndroidSettingsStore();
    final expectedSettings = File('${private}task07_settings_expected.json');
    final savedSettings = await store.read();
    if (savedSettings != null) {
      expect(
        await expectedSettings.exists(),
        isTrue,
        reason:
            'Never replace unrelated settings. Only resume this QA fixture.',
      );
      expect(savedSettings, await expectedSettings.readAsString());
    } else {
      final settings = SettingsController(store: store);
      await settings.restore();
      settings.setAppLocale(const Locale('ar'));
      await settings.flushed;
      final values =
          Map<String, dynamic>.from(
              jsonDecode((await store.read())!)['values'] as Map,
            )
            ..remove('appLocale')
            ..remove('speechLanguage');
      for (final locale in AppLanguages.supported) {
        settings.setAppLocale(locale);
        settings.setSpeechLanguage('ja');
        await settings.flushed;
        final restored = SettingsController(store: store);
        await restored.restore();
        expect(restored.appLocale, locale);
        expect(restored.preferredSpeechLanguage, 'ja');
        expect(
          Map<String, dynamic>.from(
              jsonDecode((await store.read())!)['values'] as Map,
            )
            ..remove('appLocale')
            ..remove('speechLanguage'),
          values,
        );
        restored.dispose();
      }
      settings.setAppLocale(const Locale('ar'));
      await settings.flushed;
      expect(await expectedSettings.exists(), isFalse);
      await expectedSettings.writeAsString((await store.read())!, flush: true);
      settings.dispose();
    }
    Future<TranscriptionJob> finish(String id, int duration) async {
      for (var i = 0; i < 1200; i++) {
        final value = await service.poll(id, duration);
        if (![
          TranscriptionState.queued,
          TranscriptionState.running,
        ].contains(value.state)) {
          return value;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      throw StateError('Native operation did not finish');
    }

    final original = (await channel.invokeListMethod<dynamic>(
      'transcriptionJobs',
    ))!.cast<Map>();
    expect(
      original.any((v) => ['running', 'queued'].contains(v['state'])),
      isFalse,
    );
    const root = 'content://com.xrecorder.xrecorder.files/trash/';
    const selectedModel = String.fromEnvironment(
      'SPEECH_MODEL',
      defaultValue: 'tiny',
    );
    final models = (await channel.invokeListMethod<dynamic>(
      'transcriptionModels',
    ))!.cast<Map>();
    if (models.singleWhere((v) => v['id'] == selectedModel)['installed'] !=
        true) {
      final id = (await channel.invokeMethod<String>(
        'transcriptionImportModel',
        {'model': selectedModel, 'uri': '${root}ggml-$selectedModel.bin'},
      ))!;
      expect((await finish(id, 600000)).state, TranscriptionState.completed);
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    const duration = int.fromEnvironment('SPEECH_DURATION_MS');
    const speechFile = String.fromEnvironment(
      'SPEECH_FILE',
      defaultValue: 'fleurs_en.wav',
    );
    expect(duration, greaterThan(100));
    final id = await service.start(
      TranscriptionRequest(
        audioUri: Uri.parse('$root$speechFile'),
        durationMs: duration,
        language: 'en',
        model: selectedModel,
        operationId: 'task07_fault_$stamp',
      ),
    );
    if (const bool.fromEnvironment('SPEECH_EXPECT_LOW_MEMORY')) {
      final result = await finish(id, duration);
      expect(result.state, TranscriptionState.failed);
      expect(result.errorCode, 'low_memory');
      expect(result.cues, isEmpty);
      final native = (await channel.invokeMapMethod<String, dynamic>(
        'transcriptionPoll',
        id,
      ))!;
      expect(native['modelLoadMs'], 0);
      expect(native['inferenceMs'], 0);
      final memory = (native['memoryPreflight'] as Map).cast<String, dynamic>();
      expect(
        memory['availableBytes'] as num,
        lessThan(memory['requiredBytes'] as num),
      );
      binding.reportData = {
        'lowMemoryRejectedBeforeJni': true,
        'memoryPreflight': memory,
        'nativeSettingsDocumentPreserved':
            await store.read() == await expectedSettings.readAsString(),
      };
      return;
    }
    var recognizing = false;
    for (var i = 0; i < 600; i++) {
      final job = await service.poll(id, duration);
      if (job.phase == 'recognizing on device') {
        recognizing = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(
      recognizing,
      isTrue,
      reason: 'Fault must interrupt real inference completion, not a mock.',
    );
    final before = await journal.readAsBytes();
    final backup = File('${private}task07_storage_backup_$stamp.json');
    expect(await backup.exists(), isFalse);
    await backup.writeAsBytes(before, flush: true);
    final blocker = Directory('${journal.path}.new');
    expect(
      await FileSystemEntity.type(blocker.path),
      FileSystemEntityType.notFound,
    );
    await blocker.create();
    await File('${blocker.path}/task07_owned_marker')
        .writeAsString('TASK07 write fault $stamp', flush: true);
    TranscriptionJob? result;
    try {
      result = await finish(id, duration);
      expect(result.state, TranscriptionState.completed);
      expect(result.cues, isNotEmpty);
      expect(result.errorCode, 'history_write_failed');
      expect(
        await journal.readAsBytes(),
        before,
        reason: 'An unsuccessful AtomicFile write must retain the prior bytes.',
      );
    } finally {
      if (await blocker.exists()) {
        await blocker.rename('${private}task07_storage_blocker_$stamp');
      }
    }
    final recognized = result.cues.map((v) => v.toJson()).toList();
    final metadata = (await channel.invokeMapMethod<String, dynamic>(
      'transcriptionPoll',
      id,
    ))!;
    expect(metadata['inferenceMs'] as num, greaterThan(0));
    await channel.invokeMethod<void>('transcriptionSaveHistory', id);
    final retried = await service.poll(id, duration);
    expect(retried.errorCode, isNull);
    expect(retried.cues.map((v) => v.toJson()).toList(), recognized);
    final afterMetadata = (await channel.invokeMapMethod<String, dynamic>(
      'transcriptionPoll',
      id,
    ))!;
    expect(
      afterMetadata['inferenceMs'],
      metadata['inferenceMs'],
      reason: 'Retry saving must not repeat inference.',
    );
    final disk = (jsonDecode(await journal.readAsString()) as List).cast<Map>();
    expect(disk.singleWhere((v) => v['id'] == id)['segments'], recognized);
    expect(
      disk
          .map((v) => v['id'])
          .toSet()
          .containsAll(original.map((v) => v['id'])),
      isTrue,
    );
    final manifest = File('${private}task07_history_$stamp.json');
    expect(await manifest.exists(), isFalse);
    await manifest.writeAsString(jsonEncode(disk), flush: true);
    final project = EditProject(
      id: 'task07_16kb_$stamp',
      title: 'TASK07 native runtime QA',
      updatedAt: DateTime.now(),
      clips: [
        TimelineClip(
          mediaId: '${root}task07_flash_tone.mp4',
          inPoint: Duration.zero,
          outPoint: const Duration(seconds: 4),
          sourceDuration: const Duration(seconds: 4),
        ),
      ],
      effects: {
        'subtitles': [
          {
            'startMs': 500,
            'endMs': 2500,
            'text': 'Việt Nam · 日本語 · हिन्दी · العربية 👩🏽‍💻',
          },
        ],
      },
    );
    final output = await AndroidEditProjectRepository.channel
        .invokeMethod<String>('engineProbe', project.toJson());
    expect(output, startsWith('content://media/'));
    binding.reportData = {
      'realSpeechCues': recognized.length,
      'inferenceMs': metadata['inferenceMs'],
      'writeFailureVisible': true,
      'oldBytesPreserved': true,
      'retryExactCues': true,
      'retryDidNotRepeatInference': true,
      'expectedFile': 'task07_history_$stamp.json',
      'fixturesAndBackupsRetained': true,
      'nativeSettingsLocales': AppLanguages.supported.length,
      'capturePreferencesPreserved': true,
      'media3UnicodeOutput': output,
    };
  }, timeout: const Timeout(Duration(minutes: 4)));
}
