import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

import 'recording_configuration_test.dart' show state;

// Host accepts the normal Android capture consent. Files are intentionally kept
// for frame inspection; this test never deletes or alters existing media.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const sample = String.fromEnvironment(
    'OUTPUT_SAMPLE',
    defaultValue: 'no_overlay',
  );
  const pause = bool.fromEnvironment('OUTPUT_PAUSE');
  const seconds = int.fromEnvironment('OUTPUT_SECONDS', defaultValue: 12);
  testWidgets('MP4 output sample $sample', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xff1967d2),
          body: Center(child: Text('Recording output verification')),
        ),
      ),
    );
    final service = AndroidRecordingService();
    final catalog = AndroidMediaRepository();
    try {
      debugPrint('OUTPUT_CONSENT $sample');
      final request = await service.start(
        const RecordingSettings(
          width: 1280,
          height: 720,
          fps: 30,
          bitrate: 8000000,
          audioSource: AudioSource.mute,
          countdown: Duration.zero,
          durationLimit: Duration(seconds: 30),
        ),
      );
      await state(service, RecordingState.recording);
      debugPrint('OUTPUT_READY $sample');
      await Future<void>.delayed(const Duration(seconds: 5));
      if (pause) {
        await service.pause(request.id);
        final frozen = await state(service, RecordingState.paused);
        await Future<void>.delayed(const Duration(seconds: 3));
        expect(
          (await service.currentSession())!.elapsedActive,
          frozen.elapsedActive,
        );
        await service.resume(request.id);
        expect((await state(service, RecordingState.recording)).id, request.id);
        await Future<void>.delayed(const Duration(seconds: 5));
      } else {
        debugPrint('OUTPUT_HOME_OR_DRAG $sample');
        await Future<void>.delayed(const Duration(seconds: seconds - 5));
      }
      await service.stop(request.id);
      final done = await state(service, RecordingState.completed);
      expect(done.id, request.id);
      final item = (await catalog.find(done.outputUri.toString()))!;
      expect(item.sizeBytes, greaterThan(0));
      expect(item.duration!.inMilliseconds, greaterThan(pause ? 8500 : 10500));
      expect(
        (item.duration!.inMilliseconds - done.elapsedActive.inMilliseconds)
            .abs(),
        lessThan(2500),
      );
      debugPrint(
        'OUTPUT_SAVED $sample name=${item.displayName} uri=${item.uri} durationMs=${item.duration!.inMilliseconds} elapsedMs=${done.elapsedActive.inMilliseconds}',
      );
    } finally {
      final current = await service.currentSession();
      if (current != null &&
          ![
            RecordingState.completed,
            RecordingState.failed,
            RecordingState.idle,
          ].contains(current.state)) {
        try {
          await service.cancel(current.id);
        } catch (_) {
          /* Already finalizing. */
        }
      }
      catalog.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}
