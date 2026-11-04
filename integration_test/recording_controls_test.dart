import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

import 'recording_configuration_test.dart' show state;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Pause excludes wall time and reconnect returns native session', (
    tester,
  ) async {
    final service = AndroidRecordingService();
    final media = AndroidMediaRepository();
    debugPrint('CONTROLS_TEST_CONSENT');
    await service.start(
      const RecordingSettings(
        width: 1280,
        height: 720,
        fps: 30,
        bitrate: 8000000,
        audioSource: AudioSource.microphone,
        countdown: Duration.zero,
      ),
    );
    final active = await state(service, RecordingState.recording);
    await Future<void>.delayed(const Duration(seconds: 3));
    await service.pause(active.id);
    final paused = await state(service, RecordingState.paused);
    await Future<void>.delayed(const Duration(seconds: 4));
    final reconnected = await AndroidRecordingService().currentSession();
    expect(reconnected!.state, RecordingState.paused);
    expect(reconnected.elapsedActive, paused.elapsedActive);
    await service.resume(active.id);
    await state(service, RecordingState.recording);
    await Future<void>.delayed(const Duration(seconds: 3));
    await service.pause(active.id);
    await service.stop(active.id);
    final saved = await state(service, RecordingState.completed);
    final item = await media.find(saved.outputUri.toString());
    expect(item!.duration!.inMilliseconds, inInclusiveRange(5500, 8000));
    expect(item.hasAudio, isTrue);
    debugPrint('CONTROLS_TEST_OUTPUT=${saved.outputUri}');
    await service.stop(active.id);
    expect((await service.currentSession())!.outputUri, saved.outputUri);
    media.dispose();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
