import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/domain/repositories.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

class TestRecorder implements RecordingService {
  @override
  Future<RecordingCapabilities> capabilities() async => RecordingCapabilities(
    audioSources: AudioSource.values.toSet(),
    configurations: [],
    noiseReduction: false,
    hevc: false,
  );
  final events = StreamController<RecordingSession>.broadcast();
  RecordingSession? current;
  bool stopFails = false;
  RecordingSession make(RecordingState state, {Uri? output}) =>
      RecordingSession(
        id: 'test',
        state: state,
        configSnapshot: const RecordingSettings(),
        elapsedActive: Duration.zero,
        outputUri: output,
      );
  @override
  Stream<RecordingSession> get sessions => events.stream;
  @override
  Future<RecordingSession?> currentSession() async => current;
  @override
  Future<RecordingSession> start(RecordingSettings settings) async =>
      current = make(RecordingState.awaitingPermission);
  @override
  Future<void> stop(String id) async {
    if (stopFails) throw const DomainFailure(FailureCode.io, 'Stop failed');
  }

  @override
  Future<void> cancel(String id) async {
    current = make(RecordingState.idle);
    events.add(current!);
  }

  @override
  Future<void> pause(String id) async {}
  @override
  Future<void> resume(String id) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
