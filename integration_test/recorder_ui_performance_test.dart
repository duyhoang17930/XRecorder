import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/media/media_actions.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/recording/recording_service.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';

import '../test/fixtures/visual_catalog.dart';
import 'recording_configuration_test.dart' show state;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Library scroll and visible controls while native capture is active',
    (tester) async {
      final service = AndroidRecordingService();
      final media = AndroidMediaRepository();
      final existing = await media.list(kind: MediaKind.video);
      final current = await service.currentSession();
      expect(
        current?.state,
        anyOf(
          isNull,
          RecordingState.idle,
          RecordingState.completed,
          RecordingState.failed,
        ),
        reason: 'Never interrupt an existing recording.',
      );
      final image = await fixtureImage();
      final catalog = VisualCatalog(image);
      await tester.pumpWidget(
        XRecorderApp(settings: SettingsController(), mediaRepository: catalog),
      );
      await tester.pumpAndSettle();
      await precacheImage(
        MemoryImage(image),
        tester.element(find.text('Video Library')),
      );
      debugPrint('TASK02_NATIVE_CAPTURE_CONSENT');
      final request = await service.start(
        const RecordingSettings(
          width: 1280,
          height: 720,
          fps: 30,
          bitrate: 8000000,
          audioSource: AudioSource.mute,
          countdown: Duration.zero,
        ),
      );
      try {
        await state(service, RecordingState.recording);
        await tester.pumpAndSettle();
        expect(find.text('Recording'), findsWidgets);
        await binding.watchPerformance(() async {
          for (final direction in [-350.0, 350.0]) {
            for (var i = 0; i < 6; i++) {
              await tester.timedDrag(
                find.byType(Scrollable).first,
                Offset(0, direction),
                const Duration(milliseconds: 350),
              );
              await tester.pumpAndSettle();
            }
          }
        }, reportKey: 'emulator_library_scroll_while_recording');
        await tester.tap(find.text('Pause'));
        final paused = await state(service, RecordingState.paused);
        await tester.pumpAndSettle();
        expect(find.text('Paused'), findsWidgets);
        await Future<void>.delayed(const Duration(milliseconds: 900));
        expect(
          (await service.currentSession())!.elapsedActive,
          paused.elapsedActive,
        );
        await tester.tap(find.text('Resume'));
        await state(service, RecordingState.recording);
        await tester.pumpAndSettle();
        await tester.timedDrag(
          find.byType(Scrollable).first,
          const Offset(0, -350),
          const Duration(milliseconds: 700),
        );
        await tester.tap(find.text('Stop'));
        final saved = await state(service, RecordingState.completed);
        await tester.pumpAndSettle();
        expect(find.text('Video saved'), findsOneWidget);
        expect(saved.id, request.id);
        expect(saved.outputUri, isNotNull);
        expect(existing.any((item) => item.uri == saved.outputUri), isFalse);
        final item = await media.find(saved.outputUri.toString());
        expect(item, isNotNull);
        expect(item!.duration!.inMilliseconds, greaterThan(4000));
        expect(item.hasAudio, isFalse);
        binding.reportData!['nativeCaptureVerification'] = {
          'device': 'emulator-5554; Android API 36; x86_64; profile',
          'requestedFps': 30,
          'dimensions': '${item.width}x${item.height}',
          'durationMs': item.duration!.inMilliseconds,
          'sizeBytes': item.sizeBytes,
          'hasAudio': item.hasAudio,
          'pauseResumeStop': true,
          'pausedElapsedStable': true,
          'fixture': '30 generated library rows; actual native MediaProjection/encoder running',
          'limits': 'Flutter frame timings on emulator; no physical device, encoder FPS or thermal claim',
        };
        // Remove only this test's newly created, identity-checked output through app APIs.
        final actions = AndroidMediaActions();
        final entry = await actions.trash(item);
        await actions.permanentlyDelete(entry.id);
        expect(await media.find(saved.outputUri.toString()), isNull);
        binding.reportData!['nativeCaptureVerification']['testOutputRemoved'] =
            true;
      } finally {
        final last = await service.currentSession();
        if (last?.id == request.id &&
            ![
              RecordingState.idle,
              RecordingState.completed,
              RecordingState.failed,
            ].contains(last?.state)) {
          await service.cancel(request.id);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        media.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
