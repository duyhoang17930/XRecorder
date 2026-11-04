import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

import 'recording_configuration_test.dart' show state;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Front-camera overlay recording saves real output', (
    tester,
  ) async {
    final capture = AndroidRecordingService();
    final media = AndroidMediaRepository();
    debugPrint('FACECAM_TEST_PERMISSIONS');
    await capture.start(
      const RecordingSettings(
        width: 1280,
        height: 720,
        fps: 30,
        bitrate: 8000000,
        facecam: true,
        countdown: Duration(seconds: 3),
        durationLimit: Duration(seconds: 6),
      ),
    );
    final recording = await state(capture, RecordingState.recording);
    expect(recording.configSnapshot.facecam, isTrue);
    final saved = await state(capture, RecordingState.completed);
    final item = await media.find(saved.outputUri.toString());
    expect(item!.duration!.inMilliseconds, inInclusiveRange(5500, 8000));
    debugPrint('FACECAM_TEST_OUTPUT=${saved.outputUri}');
    media.dispose();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
