import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/media/media_actions.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

import 'recording_configuration_test.dart' show state;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Saved URI plays using native clock and opens Android share sheet',
    (tester) async {
      final capture = AndroidRecordingService();
      final actions = AndroidMediaActions();
      debugPrint('PREVIEW_TEST_CAPTURE_CONSENT');
      await capture.start(
        const RecordingSettings(
          width: 1280,
          height: 720,
          fps: 30,
          bitrate: 8000000,
          countdown: Duration.zero,
          durationLimit: Duration(seconds: 4),
        ),
      );
      final saved = await state(capture, RecordingState.completed);
      await actions.preview(saved.outputUri!);
      Map<Object?, Object?>? playback;
      for (var i = 0; i < 30; i++) {
        playback = await AndroidMediaActions.channel
            .invokeMapMethod<Object?, Object?>('playbackState');
        if (((playback?['positionMs'] as num?) ?? 0) > 500) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      expect((playback!['positionMs'] as num), greaterThan(500));
      expect((playback['durationMs'] as num), greaterThan(3500));
      debugPrint('PREVIEW_TEST_NATIVE_CLOCK=$playback');
      await actions.share(saved.outputUri!);
      debugPrint('PREVIEW_TEST_SHARE_SHEET_OPEN');
      await Future<void>.delayed(const Duration(seconds: 15));
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
