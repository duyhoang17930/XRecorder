import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

import 'fixtures/recorder.dart';

class ConsentRecorder extends TestRecorder {
  var starts = 0;
  final pausedIds = <String>[];
  final resumedIds = <String>[];

  void snapshot(RecordingState state, {String? id}) {
    current = RecordingSession(
      id: id ?? current!.id,
      state: state,
      configSnapshot: const RecordingSettings(),
      elapsedActive: const Duration(seconds: 12),
    );
    events.add(current!);
  }

  @override
  Future<RecordingSession> start(RecordingSettings settings) async {
    starts++;
    snapshot(RecordingState.awaitingPermission, id: 'fresh-$starts');
    return current!;
  }

  @override
  Future<void> pause(String id) async {
    pausedIds.add(id);
    snapshot(RecordingState.paused);
  }

  @override
  Future<void> resume(String id) async {
    resumedIds.add(id);
    snapshot(RecordingState.recording);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'reopen and pause/resume reconnect to the same live session without Start',
    () async {
      final service = ConsentRecorder();
      service.snapshot(RecordingState.paused, id: 'live-native');
      var controller = CaptureController(service, onSaved: () {});
      try {
        await controller.refresh();
        controller.didChangeAppLifecycleState(AppLifecycleState.paused);
        controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await controller.refresh();
        controller.dispose();
        controller = CaptureController(service, onSaved: () {});
        await controller.refresh();
        await controller.togglePause();
        await controller.togglePause();
        expect(service.resumedIds, ['live-native']);
        expect(service.pausedIds, ['live-native']);
        expect(controller.session!.id, 'live-native');
        expect(controller.session!.state, RecordingState.paused);
        expect(controller.session!.elapsedActive, const Duration(seconds: 12));
        expect(service.starts, 0);
      } finally {
        controller.dispose();
        await service.events.close();
      }
    },
  );

  test(
    'duplicate Start stays blocked through consent, pause and finalization',
    () async {
      final service = ConsentRecorder();
      final controller = CaptureController(service, onSaved: () {});
      try {
        await controller.start(const RecordingSettings());
        final firstId = controller.session!.id;
        for (final state in [
          RecordingState.awaitingPermission,
          RecordingState.recording,
          RecordingState.paused,
          RecordingState.finalizing,
        ]) {
          service.snapshot(state);
          await controller.refresh();
          await controller.start(const RecordingSettings());
          expect(service.starts, 1);
          expect(controller.session!.id, firstId);
        }
        service.snapshot(RecordingState.completed);
        await controller.refresh();
        await controller.start(const RecordingSettings());
        expect(service.starts, 2);
        expect(controller.session!.id, isNot(firstId));
        expect(controller.session!.state, RecordingState.awaitingPermission);
      } finally {
        controller.dispose();
        await service.events.close();
      }
    },
  );

  test('revoked session is refreshed without automatic restart; explicit Start is fresh', () async {
    final service = ConsentRecorder();
    service.snapshot(RecordingState.failed, id: 'revoked');
    final controller = CaptureController(service, onSaved: () {});
    try {
      await controller.refresh();
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await controller.refresh();
      await controller.togglePause();
      expect(service.starts, 0);
      expect(service.resumedIds, isEmpty);
      await controller.start(const RecordingSettings());
      expect(service.starts, 1);
      expect(controller.session!.id, isNot('revoked'));
      expect(controller.session!.state, RecordingState.awaitingPermission);
    } finally {
      controller.dispose();
      await service.events.close();
    }
  });
}
