import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

import 'recording_configuration_test.dart' show state;

// Host grants/denies Android consent normally. With overlays enabled the host
// opts in via notification "Show controls in video", presses Home, then the
// actual floating Pause, Resume and Stop buttons.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const floating = bool.fromEnvironment(
    'EXPECT_FLOATING_OVERLAY',
    defaultValue: true,
  );
  testWidgets('Floating controls use the current native recording session', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xff1967d2),
          body: Center(child: Text('Floating recording controls verification')),
        ),
      ),
    );
    final service = AndroidRecordingService();
    final catalog = AndroidMediaRepository();
    var saved = 0;
    final controller = CaptureController(service, onSaved: () => saved++);
    try {
      await controller.refresh();
      final previousSaved = saved;
      debugPrint('FLOAT_TEST_CONSENT floating=$floating');
      final request = await service.start(
        const RecordingSettings(
          width: 1280,
          height: 720,
          fps: 30,
          bitrate: 8000000,
          audioSource: AudioSource.mute,
          countdown: Duration.zero,
          durationLimit: Duration(seconds: 90),
        ),
      );
      await state(service, RecordingState.recording);
      debugPrint('FLOAT_TEST_RECORDING id=${request.id}');
      if (floating) {
        debugPrint(
          'FLOAT_TEST_ENABLE_FROM_NOTIFICATION: Show controls in video',
        );
      }
      await Future<void>.delayed(const Duration(seconds: 3));
      debugPrint('FLOAT_TEST_HOME_AND_PAUSE');
      if (!floating) await service.pause(request.id);
      final paused = await state(service, RecordingState.paused);
      expect(paused.id, request.id);
      expect(paused.outputUri, isNull);
      await Future<void>.delayed(const Duration(seconds: 3));
      final restored = await AndroidRecordingService().currentSession();
      expect(restored!.id, request.id);
      expect(restored.elapsedActive, paused.elapsedActive);
      expect(saved, previousSaved);
      debugPrint('FLOAT_TEST_RESUME');
      if (!floating) await service.resume(request.id);
      final resumed = await state(service, RecordingState.recording);
      expect(resumed.id, request.id);
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(
        (await service.currentSession())!.elapsedActive,
        greaterThan(paused.elapsedActive),
      );
      debugPrint('FLOAT_TEST_STOP');
      if (!floating) await service.stop(request.id);
      final done = await state(service, RecordingState.completed);
      expect(done.id, request.id);
      expect(done.outputUri, isNotNull);
      final item = await catalog.find(done.outputUri.toString());
      expect(item, isNotNull);
      expect(item!.mimeType, 'video/mp4');
      expect(item.sizeBytes, greaterThan(0));
      expect(item.duration!.inMilliseconds, greaterThan(4000));
      // File duration can differ slightly from native wall time at encoder edges.
      expect(
        (item.duration!.inMilliseconds - done.elapsedActive.inMilliseconds)
            .abs(),
        lessThan(2500),
      );
      await service.stop(request.id);
      await controller.refresh();
      expect(saved, previousSaved + 1);
      expect((await service.currentSession())!.outputUri, done.outputUri);
      debugPrint(
        'FLOAT_TEST_SAVED uri=${done.outputUri} name=${item.displayName} durationMs=${item.duration!.inMilliseconds} elapsedMs=${done.elapsedActive.inMilliseconds}',
      );
    } finally {
      final current = await service.currentSession();
      if (current != null && controller.busy) {
        try {
          await service.cancel(current.id);
        } catch (_) {
          /* Finalizer may already own the output. */
        }
      }
      controller.dispose();
      catalog.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
