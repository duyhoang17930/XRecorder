import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/domain/models.dart';
import 'subtitles.dart';
import 'speech_languages.dart';

enum TranscriptionAvailability { notConfigured, onDevice }

enum TranscriptionState { queued, running, completed, failed, cancelled }

/// Stable audio/timeline identity; titles, locale and visual subtitle styles
/// must not detach an in-progress job. Legacy journals have no signature.
String transcriptionSourceSignature(EditProject project) {
  Object? canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: canonical(value[key])};
    }
    if (value is List) return value.map(canonical).toList();
    return value;
  }

  return jsonEncode(
    canonical({
      'clips': [
        for (final clip in project.clips)
          {
            'mediaId': clip.mediaId,
            'inMs': clip.inPoint.inMilliseconds,
            'outMs': clip.outPoint.inMilliseconds,
            'sourceDurationMs': clip.sourceDuration.inMilliseconds,
            'image': clip.isImage,
          },
      ],
      'effects': {
        for (final key in [
          'speed',
          'volume',
          'pitch',
          'voice',
          'noiseReduction',
          'fadeInMs',
          'fadeOutMs',
          'music',
          'musicVolume',
          'audioTracks',
        ])
          if (project.effects.containsKey(key)) key: project.effects[key],
      },
    }),
  );
}

class TranscriptionRequest {
  const TranscriptionRequest({
    required this.audioUri,
    required this.durationMs,
    required this.language,
    required this.operationId,
    this.model = 'tiny',
    this.project,
    this.allowUncertainSpeech = false,
  });
  final Uri audioUri;
  final int durationMs;
  final String language, operationId;
  final String model;
  final EditProject? project;
  final bool allowUncertainSpeech;
  Map<String, Object> toJson() {
    if (audioUri.scheme != 'content' ||
        durationMs < 100 ||
        durationMs > 600000 ||
        !SpeechLanguages.supports(language) ||
        !RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(operationId) ||
        !['tiny', 'base', 'small-q5_1'].contains(model)) {
      throw const FormatException('Invalid transcription input.');
    }
    return {
      'audioUri': audioUri.toString(),
      'durationMs': durationMs,
      'language': language,
      'contractVersion': 2,
      'allowUncertainSpeech': allowUncertainSpeech,
      'operationId': operationId,
      'model': model,
      if (project != null) 'project': project!.toJson(),
      if (project != null)
        'sourceSignature': transcriptionSourceSignature(project!),
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
    this.language = 'auto',
    this.resultLanguage,
    this.detectedLanguage,
    this.errorCode,
    this.type = 'speech',
    this.allowUncertainSpeech = false,
    this.noSpeechDetected = false,
    this.speechActivity,
  });
  final String id;
  final TranscriptionState state;
  final double progress;
  final List<SubtitleCue> cues;
  final String phase;
  final String? error;
  final int elapsedMs;
  final String language;
  final String? resultLanguage, detectedLanguage, errorCode;
  final String type;
  final bool allowUncertainSpeech, noSpeechDetected;
  final Map<String, dynamic>? speechActivity;
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
      language: value['language'] as String? ?? 'auto',
      resultLanguage: value['resultLanguage'] as String?,
      detectedLanguage: value['detectedLanguage'] as String?,
      errorCode: value['errorCode'] as String?,
      type: value['type'] as String? ?? 'speech',
      allowUncertainSpeech: value['allowUncertainSpeech'] == true,
      noSpeechDetected: value['noSpeechDetected'] == true,
      speechActivity: (value['speechActivity'] as Map?)
          ?.cast<String, dynamic>(),
    );
  }

  @override
  Future<void> cancel(String id) =>
      channel.invokeMethod<void>('transcriptionCancel', id);
}
