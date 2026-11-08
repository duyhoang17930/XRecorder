import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/features/editor/transcription_service.dart';
import 'package:xrecorder/core/persistence/settings_store.dart';

// Real native persistence regression. Run once to create21 silent jobs, then
// restart the QA app and pass HISTORY_REOPEN=true plus EXPECTED_HISTORY_FILE.
// All old jobs and every fixture are retained; no model/media/draft is deleted.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Speech history survives more than20 jobs and app restart', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Speech history persistence QA')),
      ),
    );
    const channel = AndroidTranscriptionService.channel;
    const private = '/data/user/0/com.xrecorder.xrecorder/files/';
    Future<List<Map<String, dynamic>>> jobs() async =>
        (await channel.invokeListMethod<dynamic>('transcriptionJobs'))!
            .map((v) => Map<String, dynamic>.from(v as Map))
            .toList();
    if (const bool.fromEnvironment('HISTORY_REOPEN')) {
      const name = String.fromEnvironment('EXPECTED_HISTORY_FILE');
      expect(RegExp(r'^task07_history_[0-9]+\.json$').hasMatch(name), isTrue);
      final expected = (jsonDecode(
        await File('$private$name').readAsString(),
      ) as List).map((v) => Map<String, dynamic>.from(v as Map)).toList();
      final restored = await jobs();
      const legacy = bool.fromEnvironment('HISTORY_LEGACY');
      for (final old in expected) {
        final current = restored.singleWhere((v) => v['id'] == old['id']);
        if (legacy && !old.containsKey('language')) {
          expect(current['language'], 'auto');
        }
        for (final field in [
          'type',
          'model',
          'language',
          'projectId',
          'sourceSignature',
          'state',
          'segments',
          'createdAt',
          'resultLanguage',
          'detectedLanguage',
          'errorCode',
          'allowUncertainSpeech',
          'noSpeechDetected',
          'speechActivity',
          'memoryPreflight',
          'elapsedMs',
          'modelLoadMs',
          'inferenceMs',
          'progress',
          'error',
        ]) {
          if (legacy && !old.containsKey(field)) continue;
          expect(current[field], old[field], reason: '${old['id']}/$field');
        }
      }
      if (legacy) {
        const before = int.fromEnvironment('HISTORY_BEFORE_MS');
        final completedSpeech = expected
            .where(
              (v) =>
                  v['type'] == 'speech' &&
                  v['state'] == 'completed' &&
                  (v['segments'] as List).isNotEmpty &&
                  (v['createdAt'] as num) < before,
            )
            .length;
        expect(
          completedSpeech,
          greaterThanOrEqualTo(2),
          reason: 'Use genuine previously recognized speech, never fabricated transcripts.',
        );
      }
      final settingsExpectation = File(
        '${private}task07_settings_expected.json',
      );
      final checkedSettings = await settingsExpectation.exists();
      if (checkedSettings) {
        expect(
          await const AndroidSettingsStore().read(),
          await settingsExpectation.readAsString(),
        );
      }
      binding.reportData = {
        'stage': 'reopen',
        'expected': expected.length,
        'restored': restored.length,
        'allPreviousIdsAndTranscriptContentPreserved': true,
        'expectedFile': name,
        'legacyActualPayloads': legacy,
        'legacyFixtureReplay': false,
        'originalLiveLegacyRetentionVerified': legacy,
        'nativeSettingsDocumentExact': checkedSettings,
      };
      return;
    }
    final original = await jobs();
    expect(
      original.any((v) => ['running', 'queued'].contains(v['state'])),
      isFalse,
      reason: 'Never cancel or interfere with a pre-existing active operation.',
    );
    const service = AndroidTranscriptionService();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final created = <String>[];
    for (var i = 0; i < 21; i++) {
      final id = await service.start(
        TranscriptionRequest(
          audioUri: Uri.parse(
            'content://com.xrecorder.xrecorder.files/media/task07_silence.wav',
          ),
          durationMs: 4000,
          language: i.isEven ? 'en' : 'vi',
          operationId: 'history_${stamp}_$i',
          model: 'tiny',
        ),
      );
      TranscriptionJob? result;
      for (var n = 0; n < 300; n++) {
        result = await service.poll(id, 4000);
        if (![
          TranscriptionState.running,
          TranscriptionState.queued,
        ].contains(result.state)) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(result?.state, TranscriptionState.completed);
      expect(
        result!.cues,
        isEmpty,
        reason: 'Digital silence must not create a transcript.',
      );
      expect(result.errorCode, isNot('history_write_failed'));
      final checkpoint = jsonDecode(
        await File('${private}transcription_jobs.json').readAsString(),
      ) as List;
      expect(
        checkpoint.any(
          (v) => (v as Map)['id'] == id && v['state'] == 'completed',
        ),
        isTrue,
        reason: 'Completed without a storage warning must already be durable.',
      );
      created.add(id);
    }
    final expected = await jobs();
    expect(
      expected
          .map((v) => v['id'])
          .toSet()
          .containsAll(original.map((v) => v['id'])),
      isTrue,
    );
    final expectedIds = expected.map((v) => v['id']).toSet();
    var durable = <Object>{};
    for (var i = 0; i < 60; i++) {
      try {
        final disk = jsonDecode(
          await File('${private}transcription_jobs.json').readAsString(),
        ) as List;
        durable = disk.map((v) => (v as Map)['id'] as Object).toSet();
      } on FileSystemException {
        /* A legacy AtomicFile can briefly expose only its backup. */
      }
      if (durable.containsAll(expectedIds)) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(
      durable.containsAll(expectedIds),
      isTrue,
      reason: 'The former takeLast(20) silently discarded old jobs on disk.',
    );
    final filename = 'task07_history_$stamp.json';
    final manifest = File('$private$filename');
    expect(await manifest.exists(), isFalse);
    await manifest.writeAsString(jsonEncode(expected), flush: true);
    binding.reportData = {
      'stage': 'created',
      'oldJobs': original.length,
      'newSilentJobs': created.length,
      'durableJobs': durable.length,
      'expectedFile': filename,
      'modelDeletion': false,
      'oldTranscriptContentPreservedOnDisk': true,
    };
  }, timeout: const Timeout(Duration(minutes: 4)));
}
