import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/features/editor/transcription_service.dart';
import 'package:xrecorder/features/editor/speech_languages.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'whisper.cpp real multilingual model import, inference, benchmark and cancel',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Offline whisper.cpp verification')),
        ),
      );
      const service = AndroidTranscriptionService();
      const channel = AndroidTranscriptionService.channel;
      const root = bool.fromEnvironment('QA_PRIVATE_FIXTURES')
          ? 'content://com.xrecorder.xrecorder.files/trash/'
          : 'content://com.xrecorder.xrecorder.files/media/';
      const fixtureDirectory = bool.fromEnvironment('QA_PRIVATE_FIXTURES')
          ? '/data/user/0/com.xrecorder.xrecorder/files/trash/'
          : '/sdcard/Android/data/com.xrecorder.xrecorder/files/media/';
      final reports = <Map<String, Object?>>[];
      const globalCatalog = bool.fromEnvironment('ASR_GLOBAL_CATALOG');
      var maximumJobListMs = 0;
      if (globalCatalog) {
        final languages = (await channel.invokeListMethod<dynamic>(
          'transcriptionLanguages',
        ))!;
        expect(languages.length, 100);
        for (final row in languages.cast<Map>()) {
          final known = SpeechLanguages.find(row['code'] as String)!;
          expect(row['nativeCode'], known.nativeCode);
          expect(row['available'], known.available);
        }
      }
      var silenceChecked = false;
      Future<TranscriptionJob> finish(String id, int duration) async {
        for (var n = 0; n < 1800; n++) {
          final job = await service.poll(id, duration);
          if (globalCatalog && n == 0) {
            final watch = Stopwatch()..start();
            await channel.invokeListMethod<dynamic>('transcriptionJobs');
            maximumJobListMs = maximumJobListMs > watch.elapsedMilliseconds
                ? maximumJobListMs
                : watch.elapsedMilliseconds;
            expect(
              watch.elapsedMilliseconds,
              lessThan(2000),
              reason: 'Job recovery UI must not wait for inference to finish',
            );
          }
          if (![
            TranscriptionState.queued,
            TranscriptionState.running,
          ].contains(job.state)) {
            return job;
          }
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        throw StateError('Native speech job timeout: $id');
      }

      if (const bool.fromEnvironment('ASR_ACTIVITY_PROBE')) {
        final entries = (jsonDecode(
          await File(
            '${fixtureDirectory}task07_asr_manifest.json',
          ).readAsString(),
        ) as List).cast<Map<String, dynamic>>();
        final legacy = File(
          '${fixtureDirectory}quality_manifest.json',
        );
        if (await legacy.exists()) {
          entries.addAll(
            (jsonDecode(await legacy.readAsString()) as List)
                .cast<Map<String, dynamic>>()
                .where((row) => (row['file'] as String).startsWith('quality_')),
          );
        }
        final seen = <String>{};
        final probes = <Map<String, Object?>>[];
        for (final entry in entries) {
          if (!seen.add(entry['file'] as String)) continue;
          final values = (await channel.invokeMapMethod<String, dynamic>(
            'transcriptionSpeechActivity',
            {'uri': '$root${entry['file']}', 'durationMs': entry['durationMs']},
          ))!;
          probes.add({
            'file': entry['file'],
            'condition': entry['condition'],
            ...values,
          });
          debugPrint('TASK07_ACTIVITY=${entry['file']}');
        }
        binding.reportData = {
          'activityProbes': probes,
          'partial': false,
          'scope': 'Measurement only; no automatic VAD filter applied in this probe build.',
        };
        if (!const bool.fromEnvironment('ASR_ACTIVITY_AND_HI')) return;
      }

      if (const bool.fromEnvironment('ASR_CORPUS')) {
        final entries = (jsonDecode(
          await File(
            '$fixtureDirectory${const String.fromEnvironment('ASR_MANIFEST', defaultValue: 'quality_manifest.json')}',
          ).readAsString(),
        ) as List).cast<Map<String, dynamic>>();
        final invalidId =
            'invalid_uri_${DateTime.now().microsecondsSinceEpoch}';
        await expectLater(
          channel.invokeMethod<String>('transcriptionStart', {
            'model': 'tiny',
            'language': 'vi',
            'durationMs': 4000,
            'operationId': invalidId,
            'audioUri': 'file:///not-granted.wav',
          }),
          throwsA(isA<PlatformException>()),
        );
        final jobs = (await channel.invokeListMethod<dynamic>(
          'transcriptionJobs',
        ))!;
        final poisoned = jobs.any((row) => (row as Map)['id'] == invalidId);
        if (poisoned) {
          await service.cancel(invalidId); // Only this test's invalid request.
        }
        expect(
          poisoned,
          false,
          reason: 'Rejected request must not reserve a queued speech job',
        );
        for (final model in const String.fromEnvironment(
          'ASR_MODELS',
          defaultValue: 'tiny,base,small-q5_1',
        ).split(',')) {
          final samples = entries
              .where(
                (entry) =>
                    entry['models'] == null ||
                    (entry['models'] as List).contains(model),
              )
              .toList();
          if (model == 'tiny' && !globalCatalog) {
            samples.addAll(entries.take(2)); // 10 genuine infer/unload cycles.
          }
          for (final entry in samples) {
            final duration = entry['durationMs'] as int;
            final startedAtMs = DateTime.now().millisecondsSinceEpoch;
            final id = await service.start(
              TranscriptionRequest(
                audioUri: Uri.parse('$root${entry['file']}'),
                durationMs: duration,
                language: entry['language'] as String,
                model: model,
                operationId: 'corpus_${DateTime.now().microsecondsSinceEpoch}',
              ),
            );
            debugPrint('FINALQA_ASR=$model:${entry['file']}');
            final result = await finish(id, duration);
            expect(
              result.state,
              TranscriptionState.completed,
              reason: result.error,
            );
            if (entry['condition'] == 'silence') expect(result.cues, isEmpty);
            if (const bool.fromEnvironment('ASR_EXPECT_NON_SPEECH') &&
                ['noise', 'synthetic_chord'].contains(entry['condition'])) {
              expect(
                result.cues,
                isEmpty,
                reason: 'A measured non-speech control must not acquire hallucinated text',
              );
              expect(result.noSpeechDetected, isTrue);
            }
            if (globalCatalog &&
                (entry['condition'] as String).startsWith('real_speech')) {
              expect(
                result.cues,
                isNotEmpty,
                reason: 'The conservative check must retain known real speech',
              );
            }
            var previous = 0;
            for (final cue in result.cues) {
              expect(cue.startMs, greaterThanOrEqualTo(previous));
              expect(cue.endMs, lessThanOrEqualTo(duration));
              previous = cue.endMs;
            }
            final native = (await channel.invokeMapMethod<String, dynamic>(
              'transcriptionPoll',
              id,
            ))!;
            reports.add({
              'model': model,
              'file': entry['file'],
              'language': entry['language'],
              'referenceLanguage':
                  entry['referenceLanguage'] ?? entry['language'],
              'condition': entry['condition'],
              'requestedLanguage': result.language,
              'resultLanguage': result.resultLanguage,
              'detectedLanguage': result.detectedLanguage,
              'noSpeechDetected': result.noSpeechDetected,
              'speechActivity': result.speechActivity,
              'allowUncertainSpeech': result.allowUncertainSpeech,
              'elapsedMs': result.elapsedMs,
              'modelLoadMs': native['modelLoadMs'],
              'inferenceMs': native['inferenceMs'],
              'startedAtMs': startedAtMs,
              'finishedAtMs': DateTime.now().millisecondsSinceEpoch,
              'transcript': result.cues.map((c) => c.text).join(' '),
              'segments': result.cues.map((c) => c.toJson()).toList(),
            });
            binding.reportData = {
              ...binding.reportData ?? {},
              'benchmarks': reports,
              'invalidRequestDoesNotQueue': true,
              'partial': true,
              'physicalDevice': false,
              'engineCatalogVerified': globalCatalog,
              'maximumJobListMs': maximumJobListMs,
            };
          }
        }
        if (globalCatalog) {
          if (const bool.fromEnvironment('ASR_EXPECT_NON_SPEECH')) {
            final forced = await service.start(TranscriptionRequest(
              audioUri:Uri.parse('${root}task07_noise.wav'),durationMs:6000,
              language:'auto',model:'tiny',allowUncertainSpeech:true,
              operationId:'task07_uncertain_${DateTime.now().microsecondsSinceEpoch}',
            ));
            final result = await finish(forced,6000);
            final metadata = (await channel.invokeMapMethod<String,dynamic>('transcriptionPoll',forced))!;
            expect(result.state,TranscriptionState.completed);
            expect(result.allowUncertainSpeech,isTrue);
            expect(result.noSpeechDetected,isTrue);
            expect(metadata['inferenceMs'] as num,greaterThan(0),reason:'Explicit retry must reach the real engine');
            binding.reportData={...binding.reportData!, 'uncertainSpeechBypassVerified':true,
              'uncertainSpeechOverrideInferenceMs':metadata['inferenceMs']};
          }
          final cancelId = await service.start(
            TranscriptionRequest(
              audioUri: Uri.parse('${root}task07_cancel_long.wav'),
              durationMs: 60000,
              language: 'auto',
              model: 'base',
              operationId:
                  'task07_cancel_${DateTime.now().microsecondsSinceEpoch}',
            ),
          );
          var recognizing = false;
          for (var n = 0; n < 300; n++) {
            final status = await service.poll(cancelId, 60000);
            if (status.phase == 'recognizing on device') {
              recognizing = true;
              break;
            }
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
          expect(
            recognizing,
            isTrue,
            reason: 'Cancel must interrupt actual inference',
          );
          final watch = Stopwatch()..start();
          await service.cancel(cancelId);
          final drainId = await service.start(
            TranscriptionRequest(
              audioUri: Uri.parse('${root}task07_silence.wav'),
              durationMs: 4000,
              language: 'auto',
              model: 'tiny',
              operationId:
                  'task07_drain_${DateTime.now().microsecondsSinceEpoch}',
            ),
          );
          expect(
            (await finish(drainId, 4000)).state,
            TranscriptionState.completed,
          );
          expect(watch.elapsedMilliseconds, lessThan(5000));
          expect(
            (await service.poll(cancelId, 60000)).state,
            TranscriptionState.cancelled,
          );
          binding.reportData = {
            ...binding.reportData!,
            'cancelDrainMs': watch.elapsedMilliseconds,
          };
        }
        binding.reportData = {
          ...binding.reportData!,
          'partial': false,
          'fixturesRetained': true,
          'nativeJobRuns': reports.length,
          'nativeInferenceRuns': reports
              .where((row) => ((row['inferenceMs'] as num?) ?? 0) > 0)
              .length,
        };
        return;
      }

      for (final model in const String.fromEnvironment(
        'ASR_MODELS',
        defaultValue: 'tiny,base',
      ).split(',')) {
        final importId = (await channel.invokeMethod<String>(
          'transcriptionImportModel',
          {'model': model, 'uri': '${root}ggml-$model.bin'},
        ))!;
        final imported = await finish(importId, 600000);
        expect(
          imported.state,
          TranscriptionState.completed,
          reason: imported.error,
        );
        expect(
          await service.availability(),
          TranscriptionAvailability.onDevice,
        );
        if (model == 'tiny' && const bool.fromEnvironment('MODEL_FAULTS')) {
          final badName = 'qa_invalid_model_${DateTime.now().microsecondsSinceEpoch}.bin';
          final badFile = File(
            '$fixtureDirectory$badName',
          );
          await badFile.create(exclusive: true);
          await badFile.writeAsBytes(List.filled(4096, 0));
          final bad = (await channel.invokeMethod<String>(
            'transcriptionImportModel',
            {'model': 'tiny', 'uri': '$root$badName'},
          ))!;
          expect((await finish(bad, 4000)).state, TranscriptionState.failed);
          final interrupted = (await channel.invokeMethod<String>(
            'transcriptionImportModel',
            {'model': 'tiny', 'uri': '${root}ggml-tiny.bin'},
          ))!;
          var sawBytes = false;
          for (var i = 0; i < 200; i++) {
            final status = await service.poll(interrupted, 4000);
            if (status.progress > 0 &&
                status.state == TranscriptionState.running) {
              sawBytes = true;
              break;
            }
            if (status.state == TranscriptionState.completed) break;
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          expect(sawBytes, true);
          await service.cancel(interrupted);
          expect(
            (await finish(interrupted, 4000)).state,
            TranscriptionState.cancelled,
          );
          final models = (await channel.invokeListMethod<dynamic>(
            'transcriptionModels',
          ))!;
          expect(
            models.any(
              (row) => (row as Map)['id'] == 'tiny' && row['installed'] == true,
            ),
            true,
          );
        }
        if (model == 'tiny') {
          final silent = await service.start(
            TranscriptionRequest(
              audioUri: Uri.parse('${root}p2_p3_silence.wav'),
              durationMs: 4000,
              language: 'auto',
              operationId:
                  'asr_silent_${DateTime.now().microsecondsSinceEpoch}',
              model: 'tiny',
            ),
          );
          final result = await finish(silent, 4000);
          expect(result.state, TranscriptionState.completed);
          expect(result.cues, isEmpty);
          silenceChecked = true;
        }
        for (final language in ['en', 'vi', 'auto']) {
          final duration = language == 'en' ? 11000 : 16000;
          final startedAtMs = DateTime.now().millisecondsSinceEpoch;
          final request = TranscriptionRequest(
            audioUri: Uri.parse(
              '$root${language == 'en' ? 'p2_p3_jfk.wav' : 'p2_p3_fleurs_vi.wav'}',
            ),
            durationMs: duration,
            language: language,
            operationId:
                'asr_${model}_${language}_${DateTime.now().microsecondsSinceEpoch}',

            model: model,
          );
          final id = await service.start(request);
          final result = await finish(id, duration);
          expect(
            result.state,
            TranscriptionState.completed,
            reason: result.error,
          );
          expect(result.cues, isNotEmpty);
          final text = result.cues.map((c) => c.text).join(' ');
          if (language == 'en') expect(text.toLowerCase(), contains('country'));
          final native = (await channel.invokeMapMethod<String, dynamic>(
            'transcriptionPoll', id,
          ))!;
          reports.add({
            'model': model,
            'language': language,
            'elapsedMs': result.elapsedMs,
            'modelLoadMs': native['modelLoadMs'],
            'inferenceMs': native['inferenceMs'],
            'startedAtMs': startedAtMs,
            'finishedAtMs': DateTime.now().millisecondsSinceEpoch,
            'durationMs': duration,
            'transcript': text,
            'segments': result.cues.map((v) => v.toJson()).toList(),
          });
          binding.reportData = {'benchmarks': reports, 'partial': true};
        }
      }
      final id = await service.start(
        TranscriptionRequest(
          audioUri: Uri.parse('${root}p2_p3_jfk.wav'),
          durationMs: 11000,
          language: 'en',
          operationId: 'asr_cancel_${DateTime.now().microsecondsSinceEpoch}',

          model: 'base',
        ),
      );
      var phase = '';
      for (var n = 0; n < 60; n++) {
        final job = await service.poll(id, 11000);
        phase = job.phase;
        if (phase == 'recognizing on device') break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(phase, 'recognizing on device');
      await expectLater(
        channel.invokeMethod<void>('transcriptionDeleteModel', 'base'),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.message,
            'message',
            contains('in use'),
          ),
        ),
      );
      final cancellation = Stopwatch()..start();
      await service.cancel(id);
      final cancelRequestMs = cancellation.elapsedMilliseconds;
      expect(
        (await service.poll(id, 11000)).state,
        TranscriptionState.cancelled,
      );
      final nextId = await service.start(
        TranscriptionRequest(
          audioUri: Uri.parse('${root}p2_p3_silence.wav'),
          durationMs: 4000,
          language: 'auto',
          model: 'tiny',
          operationId: 'cancel_drain_${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      expect((await finish(nextId, 4000)).state, TranscriptionState.completed);
      final cancelDrainMs = cancellation.elapsedMilliseconds;
      expect(
        cancelDrainMs,
        lessThan(5000),
        reason: 'Cancelled inference must release the worker before a new job decodes',
      );
      expect(
        (await service.poll(id, 11000)).state,
        TranscriptionState.cancelled,
      );
      binding.reportData = {
        'benchmarks': reports,
        'nativeCancellation': true,
        'activeModelRemovalRejected': true,
        'silenceNoTranscript': silenceChecked,
        'fixturesRetained': true,
        'engine': 'whisper.cpp v1.9.5 CPU',
        'physicalDevice': false,
        'cancelRequestMs': cancelRequestMs,
        'cancelDrainAndNextDecodeMs': cancelDrainMs,
        'modelFaultsChecked': const bool.fromEnvironment('MODEL_FAULTS'),
      };
    },
    timeout: Timeout(
      Duration(
        minutes: const bool.fromEnvironment('ASR_GLOBAL_CATALOG') ? 90 : 40,
      ),
    ),
  );
}
