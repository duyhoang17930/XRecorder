import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

Future<RecordingSession> state(
  AndroidRecordingService service,
  RecordingState target,
) async {
  for (var i = 0; i < 120; i++) {
    final value = await service.currentSession();
    if (value?.state == target) return value!;
    if (value?.state == RecordingState.failed) {
      throw StateError(value!.error?.message ?? 'Capture failed');
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  throw StateError('Timed out waiting for $target');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Quality, countdown, timed auto-stop and every supported audio mode',
    (tester) async {
      final service = AndroidRecordingService();
      final media = AndroidMediaRepository();
      final caps = await service.capabilities();
      expect(caps.configurations, isNotEmpty);
      for (final source in AudioSource.values.where(
        caps.audioSources.contains,
      )) {
        debugPrint('CONFIG_TEST_CONSENT_${source.name}');
        await service.start(
          RecordingSettings(
            width: 1280,
            height: 720,
            fps: 30,
            bitrate: 8000000,
            audioSource: source,
            orientation: CaptureOrientation.portrait,
            countdown: const Duration(seconds: 1),
            durationLimit: const Duration(seconds: 4),
            micGain: .75,
            internalGain: .5,
          ),
        );
        final running = await state(service, RecordingState.recording);
        expect(running.configSnapshot.width, 720);
        expect(running.configSnapshot.height, 1280);
        expect(running.configSnapshot.fps, 30);
        expect(running.configSnapshot.audioSource, source);
        expect(running.configSnapshot.micGain, .75);
        expect(running.configSnapshot.internalGain, .5);
        final done = await state(service, RecordingState.completed);
        final item = await media.find(done.outputUri.toString());
        expect(item, isNotNull);
        expect(item!.duration!.inMilliseconds, inInclusiveRange(3500, 6500));
        expect(item.hasAudio, source != AudioSource.mute);
        debugPrint('CONFIG_TEST_OUTPUT_${source.name}=${done.outputUri}');
      }
      media.dispose();
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
