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

class DelayedSnapshots extends TestRecorder {
  final reads = <Completer<RecordingSession?>>[];
  final startResult = Completer<RecordingSession>();
  int startCalls = 0;
  @override
  Future<RecordingSession?> currentSession() {
    final result = Completer<RecordingSession?>();
    reads.add(result);
    return result.future;
  }

  @override
  Future<RecordingSession> start(RecordingSettings settings) {
    startCalls++;
    return startResult.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'duplicate Start during request and recording starts native only once',
    () async {
      final service = DelayedSnapshots();
      final controller = CaptureController(service, onSaved: () {});
      final first = controller.start(const RecordingSettings());
      await controller.start(const RecordingSettings());
      expect(service.startCalls, 1);
      service.events.add(service.make(RecordingState.recording));
      await Future<void>.delayed(Duration.zero);
      service.startResult.complete(
        service.make(RecordingState.awaitingPermission),
      );
      await first;
      await controller.start(const RecordingSettings());
      expect(service.startCalls, 1);
      expect(controller.session!.state, RecordingState.recording);
      service.reads.single.complete(null);
      controller.dispose();
      await service.events.close();
    },
  );
  test(
    'reconnected controller restores active native session without stopping it',
    () async {
      final service = TestRecorder()
        ..current = RecordingSession(
          id: 'existing-native-session',
          state: RecordingState.paused,
          configSnapshot: const RecordingSettings(),
          elapsedActive: const Duration(seconds: 12),
        );
      var saved = 0;
      final first = CaptureController(service, onSaved: () => saved++);
      await first.refresh();
      first.dispose();
      final replacement = CaptureController(service, onSaved: () => saved++);
      await replacement.refresh();
      expect(replacement.session!.id, 'existing-native-session');
      expect(replacement.session!.state, RecordingState.paused);
      expect(replacement.session!.elapsedActive, const Duration(seconds: 12));
      expect(replacement.busy, isTrue);
      expect(service.stopCalls, 0);
      expect(saved, 0);
      replacement.dispose();
      await service.events.close();
    },
  );
  test(
    'late refresh and start acknowledgements cannot overwrite native events',
    () async {
      final service = DelayedSnapshots();
      final controller = CaptureController(service, onSaved: () {});
      final start = controller.start(const RecordingSettings());
      service.events.add(service.make(RecordingState.recording));
      await Future<void>.delayed(Duration.zero);
      service.reads.first.complete(service.make(RecordingState.idle));
      service.startResult.complete(
        service.make(RecordingState.awaitingPermission),
      );
      await start;
      expect(controller.session!.state, RecordingState.recording);
      final refresh = controller.refresh();
      service.events.add(service.make(RecordingState.failed));
      await Future<void>.delayed(Duration.zero);
      service.reads.last.complete(service.make(RecordingState.recording));
      await refresh;
      expect(controller.session!.state, RecordingState.failed);
      controller.dispose();
      await service.events.close();
    },
  );
  test('completion A B A refreshes each output once', () async {
    final service = TestRecorder();
    var saved = 0;
    final controller = CaptureController(service, onSaved: () => saved++);
    for (final id in ['A', 'B', 'A']) {
      service.events.add(
        RecordingSession(
          id: id,
          state: RecordingState.completed,
          configSnapshot: const RecordingSettings(),
          elapsedActive: Duration.zero,
          outputUri: Uri.parse('content://test/$id'),
        ),
      );
    }
    await Future<void>.delayed(Duration.zero);
    expect(saved, 2);
    controller.dispose();
    await service.events.close();
  });
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
  test('Failure or cancellation with an output never reports Saved', () async {
    final service = TestRecorder();
    var saved = 0;
    final controller = CaptureController(service, onSaved: () => saved++);
    for (final state in [RecordingState.failed, RecordingState.idle]) {
      service.events.add(
        service.make(state, output: Uri.parse('content://test/uncommitted')),
      );
    }
    await Future<void>.delayed(Duration.zero);
    expect(saved, 0);
    controller.dispose();
    await service.events.close();
  });
  test(
    'Completed snapshot replay refreshes once without new feedback',
    () async {
      final service = TestRecorder();
      service.current = service.make(
        RecordingState.completed,
        output: Uri.parse('content://test/committed'),
      );
      var saved = 0;
      final controller = CaptureController(service, onSaved: () => saved++);
      await controller.refresh();
      expect(saved, 1);
      expect(controller.feedback, isNull);
      service.events.add(service.current!);
      await Future<void>.delayed(Duration.zero);
      expect(saved, 1);
      expect(controller.feedback, isNull);
      controller.dispose();
      await service.events.close();
    },
  );
}
