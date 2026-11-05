import 'dart:async';

import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/domain/repositories.dart';

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
  int pauseCalls = 0, resumeCalls = 0, stopCalls = 0;
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
  Future<RecordingSession> screenshot() async =>
      current = make(RecordingState.awaitingPermission);
  @override
  Future<RecordingSession> start(RecordingSettings settings) async =>
      current = make(RecordingState.awaitingPermission);
  @override
  Future<void> stop(String id) async {
    stopCalls++;
    if (stopFails) throw const DomainFailure(FailureCode.io, 'Stop failed');
    current = make(RecordingState.finalizing);
    events.add(current!);
  }

  @override
  Future<void> cancel(String id) async {
    current = make(RecordingState.idle);
    events.add(current!);
  }

  @override
  Future<void> pause(String id) async {
    pauseCalls++;
    current = make(RecordingState.paused);
    events.add(current!);
  }

  @override
  Future<void> resume(String id) async {
    resumeCalls++;
    current = make(RecordingState.recording);
    events.add(current!);
  }
}
