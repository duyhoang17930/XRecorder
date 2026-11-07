import 'package:flutter/services.dart';

import '../../core/domain/models.dart';
import 'subtitles.dart';

enum TranscriptionAvailability { notConfigured, onDevice }

enum TranscriptionState { queued, running, completed, failed, cancelled }

class TranscriptionRequest {
  const TranscriptionRequest({
    required this.audioUri,
    required this.durationMs,
    required this.language,
    required this.operationId,
    this.model = 'tiny',
    this.project,
  });
  final Uri audioUri;
  final int durationMs;
  final String language, operationId;
  final String model;
  final EditProject? project;
  Map<String, Object> toJson() {
    if (audioUri.scheme != 'content' ||
        durationMs <= 0 ||
        !['vi', 'en', 'auto'].contains(language) ||
        operationId.isEmpty) {
      throw const FormatException('Invalid transcription input.');
    }
    return {
      'audioUri': audioUri.toString(),
      'durationMs': durationMs,
      'language': language,
      'operationId': operationId,
      'model': model,
      if (project != null) 'project': project!.toJson(),
    };
  }
}

class TranscriptionJob {
  TranscriptionJob({
    required this.id,
    required this.state,
    required this.progress,
    this.cues = const [],
    this.phase = '',
    this.error,
    this.elapsedMs = 0,
  });
  final String id;
  final TranscriptionState state;
  final double progress;
  final List<SubtitleCue> cues;
  final String phase;
  final String? error;
  final int elapsedMs;
}

abstract interface class TranscriptionService {
  Future<TranscriptionAvailability> availability();
  Future<String> start(TranscriptionRequest request);
  Future<TranscriptionJob> poll(String id, int durationMs);
  Future<void> cancel(String id);
}

/// Native/backend implementations must report availability before accepting source media.
class AndroidTranscriptionService implements TranscriptionService {
  const AndroidTranscriptionService();
  static const channel = MethodChannel('com.xrecorder/editor');
  @override
  Future<TranscriptionAvailability> availability() async {
    try {
      final mode = await channel.invokeMethod<String>(
        'transcriptionAvailability',
      );
      return TranscriptionAvailability.values.firstWhere(
        (v) => v.name == mode,
        orElse: () => TranscriptionAvailability.notConfigured,
      );
    } on MissingPluginException {
      return TranscriptionAvailability.notConfigured;
    }
  }

  @override
  Future<String> start(TranscriptionRequest request) async {
    final payload = request.toJson();
    final mode = await availability();
    if (mode == TranscriptionAvailability.notConfigured) {
      throw const DomainFailure(
        FailureCode.unavailable,
        'Download or import a multilingual speech model before generating subtitles.',
      );
    }
    return (await channel.invokeMethod<String>('transcriptionStart', payload))!;
  }

  @override
  Future<TranscriptionJob> poll(String id, int durationMs) async {
    final value = (await channel.invokeMapMethod<String, dynamic>(
      'transcriptionPoll',
      id,
    ))!;
    final state = TranscriptionState.values.byName(value['state'] as String);
    final progress = (value['progress'] as num).toDouble();
    if (!progress.isFinite || progress < 0 || progress > 1) {
      throw const FormatException('Invalid transcription progress.');
    }
    final cues = SubtitleTrack.decode(value['segments'], durationMs).cues;
    return TranscriptionJob(
      id: id,
      state: state,
      progress: progress,
      cues: cues,
      phase: value['phase'] as String? ?? '',
      error: value['error'] as String?,
      elapsedMs: (value['elapsedMs'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> cancel(String id) =>
      channel.invokeMethod<void>('transcriptionCancel', id);
}
