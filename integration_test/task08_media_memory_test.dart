import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/features/editor/transcription_service.dart';

import 'p2_p3_audio_layers_test.dart' as audio;
import 'p2_p3_photo_subtitle_test.dart' as photo;
import 'p2_p3_whisper_test.dart' as speech;

// One installation preserves the model/fixture state between actual native flows.
// Keep every suite's report: their standalone entrypoints also remain usable.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final reports = <String, Object?>{};
  var suite = 0;
  const names = ['speech', 'audio', 'photo', 'longSpeech'];
  tearDown(() {
    reports[names[suite++]] = binding.reportData;
    binding.reportData = {'suites': Map<String, Object?>.of(reports)};
  });
  speech.main();
  audio.main();
  photo.main();
  testWidgets('TASK08 actual ten minute speech boundary', (tester) async {
    const service = AndroidTranscriptionService();
    const duration = 600000;
    final id = await service.start(
      TranscriptionRequest(
        audioUri: Uri.parse(
          'content://com.xrecorder.xrecorder.files/trash/'
          'task08_fleurs_en_repeat_600s_v1.wav',
        ),
        durationMs: duration,
        language: 'en',
        model: 'tiny',
        operationId: 'task08_long_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    TranscriptionJob? terminal;
    for (var i = 0; i < 1200; i++) {
      final job = await service.poll(id, duration);
      if (![
        TranscriptionState.queued,
        TranscriptionState.running,
      ].contains(job.state)) {
        terminal = job;
        break;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    final native = await AndroidTranscriptionService.channel
        .invokeMapMethod<String, dynamic>('transcriptionPoll', id);
    binding.reportData = {
      'job': native,
      'inputDurationMs': duration,
      'inputKind': 'repeated licensed real FLEURS speech; memory stress only',
    };
    expect(terminal, isNotNull);
    expect(native!['inferenceMs'] as num, greaterThan(0));
    if (terminal!.state == TranscriptionState.completed) {
      expect(terminal.cues, isNotEmpty);
      expect(terminal.cues.last.endMs, greaterThan(570000));
    } else {
      // The existing editor contract permits at most 200 subtitle cues.
      // Report that limit explicitly rather than calling it transcription PASS.
      expect(terminal.state, TranscriptionState.failed);
      expect(terminal.error, contains('200 subtitle segments'));
    }
    await expectLater(
      AndroidTranscriptionService.channel.invokeMethod<String>(
        'transcriptionStart',
        {
          'model': 'tiny',
          'language': 'en',
          'durationMs': duration + 1,
          'audioUri':
              'content://com.xrecorder.xrecorder.files/trash/'
              'task08_fleurs_en_repeat_600s_v1.wav',
          'operationId':
              'task08_over_limit_${DateTime.now().microsecondsSinceEpoch}',
        },
      ),
      throwsA(isA<PlatformException>()),
    );
  }, timeout: const Timeout(Duration(minutes: 22)));
}
