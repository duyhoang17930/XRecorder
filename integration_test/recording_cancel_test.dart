import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

import 'recording_configuration_test.dart' show state;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Native cancel aborts without publishing or Saved', (
    tester,
  ) async {
    debugPrint('CANCEL_SEMANTICS_START platform=${binding.platformDispatcher.semanticsEnabled} handles=${binding.debugOutstandingSemanticsHandles}');
    final service = AndroidRecordingService();
    final catalog = AndroidMediaRepository();
    var saved = 0;
    final controller = CaptureController(service, onSaved: () => saved++);
    final completedIds = <String>{};
    final subscription = service.sessions.listen((value) {
      if (value.state == RecordingState.completed) completedIds.add(value.id);
    });
    try {
      // Drain the initial snapshot; a previous committed session may replay.
      await controller.refresh();
      final savedBefore = saved;
      final before = (await catalog.list(kind: MediaKind.video))
          .map((item) => item.uri)
          .toSet();
      for (final target in [
        RecordingState.countdown,
        RecordingState.recording,
        RecordingState.paused,
        // Last: Android may keep the consent dialog open after native cancel.
        RecordingState.awaitingPermission,
      ]) {
        debugPrint('CANCEL_TEST_CONSENT_${target.name}');
        final request = await service.start(
          RecordingSettings(
            width: 1280,
            height: 720,
            audioSource: AudioSource.mute,
            countdown: target == RecordingState.countdown
                ? const Duration(seconds: 10)
                : Duration.zero,
          ),
        );
        if (target == RecordingState.paused) {
          await state(service, RecordingState.recording);
          await service.pause(request.id);
        }
        await state(service, target);
        await expectLater(
          service.cancel('stale-${request.id}'),
          throwsA(isA<DomainFailure>()),
        );
        expect((await service.currentSession())!.state, target);
        await service.cancel(request.id);
        final cancelled = await state(service, RecordingState.idle);
        expect(cancelled.id, request.id);
        expect(cancelled.outputUri, isNull);
        // Exercise duplicate cancellation and late queued encoder callbacks.
        await service.cancel(request.id);
        await Future<void>.delayed(const Duration(seconds: 1));
        await controller.refresh();
        expect(controller.session!.state, RecordingState.idle);
        expect(saved, savedBefore);
        expect(completedIds, isNot(contains(request.id)));
        expect(
          (await catalog.list(kind: MediaKind.video))
              .map((item) => item.uri)
              .toSet(),
          before,
        );
      }
    } finally {
      try {
        final current = await service.currentSession();
        if (current != null && controller.busy) await service.cancel(current.id);
      } finally {
        controller.dispose();
        try {
          await subscription.cancel();
        } finally {
          catalog.dispose();
          debugPrint('CANCEL_SEMANTICS_END platform=${binding.platformDispatcher.semanticsEnabled} handles=${binding.debugOutstandingSemanticsHandles}');
        }
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
