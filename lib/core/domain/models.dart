/// Platform-independent contracts. URIs are opaque: never infer filesystem paths.
enum MediaKind { video, image, gif }

enum MediaSource { recording, edit, imported }

enum MediaStatus { available, missing, trashed, processing }

class MediaItem {
  const MediaItem({
    required this.id,
    required this.uri,
    required this.kind,
    required this.displayName,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
    required this.modifiedAt,
    required this.source,
    this.status = MediaStatus.available,
    this.duration,
    this.width,
    this.height,
    this.fps,
    this.bitrate,
    this.folderUri,
    this.thumbnailUri,
    this.originalMediaId,
  });
  final String id, displayName, mimeType;
  final Uri uri;
  final MediaKind kind;
  final MediaSource source;
  final MediaStatus status;
  final int sizeBytes;
  final DateTime createdAt, modifiedAt;
  final Duration? duration;
  final int? width, height, bitrate;
  final double? fps;
  final Uri? folderUri, thumbnailUri;
  final String? originalMediaId;
}

enum RecordingMode { normal, performance }

enum AudioSource { mute, microphone, internal, mixed }

enum CaptureOrientation { automatic, portrait, landscape }

enum VideoCodec { avc, hevc }

/// Immutable request, validated against native capabilities before starting.
/// A session owns a snapshot; changing preferences cannot mutate that session.
class RecordingSettings {
  const RecordingSettings({
    this.mode = RecordingMode.normal,
    this.audioSource = AudioSource.mute,
    this.width = 1920,
    this.height = 1080,
    this.fps = 60,
    this.bitrate = 16000000,
    this.codec = VideoCodec.avc,
    this.orientation = CaptureOrientation.automatic,
    this.countdown = const Duration(seconds: 3),
    this.durationLimit,
    this.micGain = 1,
    this.internalGain = 1,
    this.noiseReduction = false,
    this.constantFrameRate = true,
    this.hardwareEncoding = true,
    this.shakeToStop = false,
    this.allowScreenOff = false,
    this.showTouches = false,
    this.recoveryCache = true,
  });
  final RecordingMode mode;
  final AudioSource audioSource;
  final int width, height, fps;
  final int? bitrate; // null requests automatic bitrate selection.
  final VideoCodec codec;
  final CaptureOrientation orientation;
  final Duration countdown;
  final Duration?
  durationLimit; // Auto-stop, distinct from pre-start countdown.
  final double micGain, internalGain;
  final bool noiseReduction,
      constantFrameRate,
      hardwareEncoding,
      shakeToStop,
      allowScreenOff,
      showTouches,
      recoveryCache;
}

enum RecordingState {
  idle,
  preparing,
  awaitingPermission,
  countdown,
  starting,
  recording,
  paused,
  stopping,
  finalizing,
  completed,
  failed,
}

class RecordingSession {
  const RecordingSession({
    required this.id,
    required this.state,
    required this.configSnapshot,
    required this.elapsedActive,
    this.startedAt,
    this.outputUri,
    this.error,
  });
  final String id;
  final RecordingState state;
  final RecordingSettings configSnapshot;
  final DateTime? startedAt;
  final Duration elapsedActive;
  final Uri? outputUri;
  final DomainFailure? error;
}

class TimelineClip {
  const TimelineClip({
    required this.mediaId,
    required this.inPoint,
    required this.outPoint,
  }) : assert(inPoint >= Duration.zero),
       assert(outPoint > inPoint);
  final String mediaId;
  final Duration inPoint, outPoint;
}

class EditProject {
  EditProject({
    required this.id,
    required List<TimelineClip> clips,
    required this.updatedAt,
    this.dirty = false,
  }) : clips = List.unmodifiable(clips);
  final String id;
  final List<TimelineClip> clips;
  final DateTime updatedAt;
  final bool dirty;
}

enum DeletionMode { appManaged, systemManaged }

class TrashEntry {
  const TrashEntry({
    required this.id,
    required this.originalMetadata,
    required this.deletedAt,
    required this.expiresAt,
    required this.mode,
    this.trashUri,
  });
  final String id;
  final MediaItem originalMetadata;
  Uri get originalUri => originalMetadata.uri;
  final Uri? trashUri;
  final DateTime deletedAt, expiresAt;
  final DeletionMode mode;
}

enum JobKind { export, transcription }

enum JobState { queued, running, completed, failed, cancelled }

class BackgroundJob {
  const BackgroundJob({
    required this.id,
    required this.kind,
    required this.state,
    required this.updatedAt,
    this.progress = 0,
    this.outputUri,
    this.error,
  }) : assert(progress >= 0 && progress <= 1);
  final String id;
  final JobKind kind;
  final JobState state;
  final DateTime updatedAt;
  final double progress;
  final Uri? outputUri;
  final DomainFailure? error;
}

enum FailureCode {
  denied,
  unavailable,
  missing,
  revoked,
  invalid,
  io,
  cancelled,
}

class DomainFailure implements Exception {
  const DomainFailure(this.code, this.message);
  final FailureCode code;
  final String message;
  @override
  String toString() => message;
}
