import '../../l10n/generated/app_localizations.dart';

import 'package:flutter/services.dart';

import '../../core/presentation/user_messages.dart';
import 'transcription_service.dart';

String speechRequestFailureMessage(Object error) =>
    error is PlatformException && error.code == 'history_unavailable'
    ? 'speech.history.unavailable'
    : error is PlatformException && error.code == 'history_write_failed'
    ? 'speech.history.write_failed'
    : UserMessages.failure(error, operation: UserOperation.editClip).text;

String speechPhaseText(AppLocalizations strings, TranscriptionJob job) {
  if (job.state == TranscriptionState.failed) return strings.speechJobFailed;
  if (job.state == TranscriptionState.completed) {
    return job.type == 'model'
        ? strings.modelInstalledAndVerified
        : job.noSpeechDetected && job.cues.isEmpty
        ? strings.speechNotDetected
        : strings.reviewSubtitles;
  }
  if (job.state == TranscriptionState.cancelled) return strings.cancelled;
  return switch (job.phase) {
    'saving job history' => strings.speechSavingHistory,
    'queued' => strings.speechQueued,
    'downloading' => strings.speechDownloading,
    'verifying' => strings.speechVerifying,
    'preparing edited audio' => strings.speechPreparing,
    'decoding audio' => strings.speechDecoding,
    'checking speech activity' => strings.speechCheckingActivity,
    'loading model on device' => strings.speechLoading,
    'recognizing on device' => strings.speechRecognizing,
    'ready' => strings.modelInstalledAndVerified,
    'completed' => strings.reviewSubtitles,
    'cancelled' => strings.cancelled,
    _ => strings.processing,
  };
}

/// A review warning only: preserve all recognized text and never transliterate it.
bool speechNeedsWritingSystemReview(TranscriptionJob job) {
  if ((job.resultLanguage ?? job.language) != 'hi') return false;
  final text = job.cues.map((cue) => cue.text).join(' ');
  final devanagari = RegExp(r'[\u0900-\u097f]').allMatches(text).length;
  final other = RegExp(r'[a-zA-Z\u0600-\u06ff]').allMatches(text).length;
  return other > 5 && other > devanagari;
}

String speechFailureText(AppLocalizations strings, TranscriptionJob job) =>
    switch (job.errorCode) {
      'history_write_failed' => strings.speechHistoryNotSaved,
      'history_unavailable' => strings.speechHistoryUnavailable,
      'interrupted' => strings.speechInterrupted,
      'low_memory' => strings.speechLowMemory,
      'permission_denied' => strings.speechPermissionDenied,
      'model_install_failed' => strings.speechModelInstallFailed,
      'audio_prepare_failed' => strings.speechAudioPrepareFailed,
      _ => strings.speechOperationFailedRetryOrChooseA,
    };
