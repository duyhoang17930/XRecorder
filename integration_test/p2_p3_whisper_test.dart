import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/features/editor/transcription_service.dart';

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
      const root = 'content://com.xrecorder.xrecorder.files/media/';
      final reports = <Map<String, Object?>>[];
      var silenceChecked = false;
      Future<TranscriptionJob> finish(String id, int duration) async {
        for (var n = 0; n < 1800; n++) {
          final job = await service.poll(id, duration);
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
          reports.add({
            'model': model,
            'language': language,
            'elapsedMs': result.elapsedMs,
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
      await service.cancel(id);
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
      };
    },
    timeout: const Timeout(Duration(minutes: 40)),
  );
}
