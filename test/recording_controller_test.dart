import 'package:flutter_test/flutter_test.dart';

import 'dart:async';

import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

import 'fixtures/recorder.dart';

class DelayedScreenshot extends TestRecorder {
  final pending = Completer<RecordingSession>();
  @override
  Future<RecordingSession> screenshot() => pending.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'late screenshot completion never notifies a disposed catalog',
    () async {
      final service = DelayedScreenshot();
      var saved = 0;
      final controller = CaptureController(service, onSaved: () => saved++);
      final pending = controller.screenshot();
      controller.dispose();
      service.pending.complete(
        service.make(
          RecordingState.completed,
          output: Uri.parse('content://test/late'),
        ),
      );
      await pending;
      expect(saved, 0);
      await service.events.close();
    },
  );
  test('Consent pending/denied never fabricates an active recording or saved output', () async {
    final service = TestRecorder();
    var saved = 0;
    final controller = CaptureController(service, onSaved: () => saved++);
    await controller.start(const RecordingSettings());
    expect(controller.session!.state, RecordingState.awaitingPermission);
    expect(controller.busy, isTrue);
    expect(saved, 0);
    await service.cancel('test');
    await Future<void>.delayed(Duration.zero);
    expect(controller.busy, isFalse);
    expect(saved, 0);
    controller.dispose();
    await service.events.close();
  });
  test(
    'Only completed sessions with output refresh catalog, once per session',
    () async {
      final service = TestRecorder();
      var saved = 0;
      final controller = CaptureController(service, onSaved: () => saved++);
      service.events.add(service.make(RecordingState.finalizing));
      service.events.add(service.make(RecordingState.completed));
      await Future<void>.delayed(Duration.zero);
      expect(saved, 0);
      final completed = service.make(
        RecordingState.completed,
        output: Uri.parse('content://media/1'),
      );
      service.events.add(completed);
      service.events.add(completed);
      await Future<void>.delayed(Duration.zero);
      expect(saved, 1);
      controller.dispose();
      await service.events.close();
    },
  );
  test('Failed stop retains native state and shows error', () async {
    final service = TestRecorder()..stopFails = true;
    final controller = CaptureController(service, onSaved: () {});
    await controller.start(const RecordingSettings());
    await controller.stop();
    expect(controller.busy, isTrue);
    expect(controller.error, 'Stop failed');
    controller.dispose();
    await service.events.close();
  });
}
