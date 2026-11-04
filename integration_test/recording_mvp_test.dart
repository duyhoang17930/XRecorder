import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

Future<RecordingSession> waitFor(
  AndroidRecordingService service,
  RecordingState target,
) async {
  for (var i = 0; i < 120; i++) {
    final value = await service.currentSession();
    if (value?.state == target) return value!;
    if (value?.state == RecordingState.failed) {
      throw StateError(value?.error?.message ?? 'Recording failed');
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  throw StateError('Timed out waiting for $target');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'OS denial creates no file; consent produces a real multi-minute MP4',
    (tester) async {
      final service = AndroidRecordingService();
      final media = AndroidMediaRepository();
      final before = await media.list(kind: MediaKind.video);
      debugPrint('CAPTURE_TEST_CANCEL_PROMPT');
      await service.start(
        const RecordingSettings(
          width: 1280,
          height: 720,
          fps: 30,
          bitrate: 8000000,
          countdown: Duration.zero,
        ),
      );
      await expectLater(
        service.start(
          const RecordingSettings(
            width: 1280,
            height: 720,
            fps: 30,
            bitrate: 8000000,
            countdown: Duration.zero,
          ),
        ),
        throwsA(isA<DomainFailure>()),
      );
      await waitFor(service, RecordingState.idle);
      expect((await media.list(kind: MediaKind.video)).length, before.length);
      debugPrint('CAPTURE_TEST_ACCEPT_PROMPT');
      await service.start(
        const RecordingSettings(
          width: 1280,
          height: 720,
          fps: 30,
          bitrate: 8000000,
          countdown: Duration.zero,
        ),
      );
      final recording = await waitFor(service, RecordingState.recording);
      debugPrint('CAPTURE_TEST_RECORDING_${recording.id}');
      await Future<void>.delayed(const Duration(seconds: 125));
      await service.stop(recording.id);
      final completed = await waitFor(service, RecordingState.completed);
      expect(completed.outputUri, isNotNull);
      final item = await media.find(completed.outputUri.toString());
      expect(item, isNotNull);
      expect(item!.sizeBytes, greaterThan(0));
      expect(item.duration!.inSeconds, greaterThanOrEqualTo(120));
      expect(
        (await media.list(kind: MediaKind.video))
            .any((entry) => entry.uri == completed.outputUri),
        isTrue,
      );
      debugPrint('CAPTURE_TEST_OUTPUT=${completed.outputUri}');
      await service.stop(
        recording.id,
      ); // Repeated stop must not create another result.
      expect((await service.currentSession())?.outputUri, completed.outputUri);
      media.dispose();
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
