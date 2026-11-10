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
    this.hasAudio,
    this.owned = false,
    this.revision,
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
  final bool? hasAudio;
  final bool owned;

  /// MediaStore generation, when provided; cache invalidation only.
  final int? revision;
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
    this.facecam = false,
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
      facecam,
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
    this.countdownRemaining = Duration.zero,
    this.screenshot = false,
  });
  final String id;
  final RecordingState state;
  final RecordingSettings configSnapshot;
  final DateTime? startedAt;
  final Duration elapsedActive;
  final Uri? outputUri;
  final DomainFailure? error;
  final Duration countdownRemaining;
  final bool screenshot;
}

class VideoConfiguration {
  const VideoConfiguration({
    required this.width,
    required this.height,
    required this.fps,
    this.codec = VideoCodec.avc,
  });
  final int width, height, fps;
  final VideoCodec codec;
}

class RecordingCapabilities {
  RecordingCapabilities({
    required Set<AudioSource> audioSources,
    required List<VideoConfiguration> configurations,
    required this.noiseReduction,
    required this.hevc,
    this.facecam = false,
  }) : audioSources = Set.unmodifiable(audioSources),
       configurations = List.unmodifiable(configurations);
  final Set<AudioSource> audioSources;
  final List<VideoConfiguration> configurations;
  final bool noiseReduction, hevc, facecam;
}

class TimelineClip {
  TimelineClip({
    required this.mediaId,
    required this.inPoint,
    required this.outPoint,
    required this.sourceDuration,
    this.title = 'Clip',
    this.rotation = 0,
    this.cropLeft = 0,
    this.cropTop = 0,
    this.cropRight = 1,
    this.cropBottom = 1,
    this.isImage = false,
    this.flipH = false,
    this.flipV = false,
  }) {
    if (Uri.tryParse(mediaId)?.scheme != 'content' ||
        inPoint < Duration.zero ||
        outPoint - inPoint < const Duration(milliseconds: 200) ||
        outPoint > sourceDuration ||
        sourceDuration > const Duration(hours: 24) ||
        ![0, 90, 180, 270].contains(rotation) ||
        ![
          cropLeft,
          cropTop,
          cropRight,
          cropBottom,
        ].every((v) => v.isFinite && v >= 0 && v <= 1) ||
        cropRight - cropLeft < .02 ||
        cropBottom - cropTop < .02) {
      throw const FormatException('Invalid clip range or crop');
    }
  }
  final String mediaId;
  final String title;
  final Duration inPoint, outPoint, sourceDuration;
  Duration get duration => outPoint - inPoint;
  final int rotation;
  final bool isImage, flipH, flipV;
  final double cropLeft, cropTop, cropRight, cropBottom;
  TimelineClip copyWith({
    Duration? inPoint,
    Duration? outPoint,
    int? rotation,
    double? cropLeft,
    double? cropTop,
    double? cropRight,
    double? cropBottom,
    String? mediaId,
    String? title,
    Duration? sourceDuration,
    bool? flipH,
    bool? flipV,
  }) => TimelineClip(
    mediaId: mediaId ?? this.mediaId,
    title: title ?? this.title,
    inPoint: inPoint ?? this.inPoint,
    outPoint: outPoint ?? this.outPoint,
    sourceDuration: sourceDuration ?? this.sourceDuration,
    isImage: isImage,
    flipH: flipH ?? this.flipH,
    flipV: flipV ?? this.flipV,
    rotation: rotation ?? this.rotation,
    cropLeft: cropLeft ?? this.cropLeft,
    cropTop: cropTop ?? this.cropTop,
    cropRight: cropRight ?? this.cropRight,
    cropBottom: cropBottom ?? this.cropBottom,
  );
  Map<String, Object> toJson() => {
    'mediaId': mediaId,
    'title': title,
    'inMs': inPoint.inMilliseconds,
    'outMs': outPoint.inMilliseconds,
    'sourceDurationMs': sourceDuration.inMilliseconds,
    'rotation': rotation,
    'isImage': isImage,
    'flipH': flipH,
    'flipV': flipV,
    'cropLeft': cropLeft,
    'cropTop': cropTop,
    'cropRight': cropRight,
    'cropBottom': cropBottom,
  };
  factory TimelineClip.fromJson(Map<String, dynamic> json) => TimelineClip(
    mediaId: json['mediaId'] as String,
    title: json['title'] as String? ?? 'Clip',
    inPoint: Duration(milliseconds: json['inMs'] as int),
    outPoint: Duration(milliseconds: json['outMs'] as int),
    sourceDuration: Duration(milliseconds: json['sourceDurationMs'] as int),
    rotation: json['rotation'] as int? ?? 0,
    isImage: json['isImage'] as bool? ?? false,
    flipH: json['flipH'] as bool? ?? false,
    flipV: json['flipV'] as bool? ?? false,
    cropLeft: (json['cropLeft'] as num?)?.toDouble() ?? 0,
    cropTop: (json['cropTop'] as num?)?.toDouble() ?? 0,
    cropRight: (json['cropRight'] as num?)?.toDouble() ?? 1,
    cropBottom: (json['cropBottom'] as num?)?.toDouble() ?? 1,
  );
}

Object _immutableEditorValue(Object value) {
  if (value is List) {
    // Drawing paths use null to separate strokes; freeze every point while
    // retaining those separators for undo, autosave and native rendering.
    return List<Object?>.unmodifiable(
      value.map(
        (entry) =>
            entry == null ? null : _immutableEditorValue(entry as Object),
      ),
    );
  }
  if (value is Map) {
    return Map<String, Object>.unmodifiable(
      value.map(
        (key, value) =>
            MapEntry(key as String, _immutableEditorValue(value as Object)),
      ),
    );
  }
  return value;
}

class EditProject {
  EditProject({
    required this.id,
    required List<TimelineClip> clips,
    required this.updatedAt,
    this.dirty = false,
    this.title = 'Untitled project',
    Map<String, Object> effects = const {},
  }) : clips = List.unmodifiable(clips),
       effects = Map<String, Object>.unmodifiable(
         effects.map(
           (key, value) => MapEntry(key, _immutableEditorValue(value)),
         ),
       ) {
    if (!speed.isFinite || speed < .5 || speed > 2) {
      throw const FormatException('Unsupported project speed');
    }
  }
  final Map<String, Object> effects;
  double get speed => (effects['speed'] as num? ?? 1).toDouble();
  final String id;
  final List<TimelineClip> clips;
  final DateTime updatedAt;
  final bool dirty;
  final String title;
  Duration get duration => Duration(
    microseconds:
        (clips.fold<int>(
                  0,
                  (total, clip) => total + clip.duration.inMicroseconds,
                ) /
                speed)
            .round(),
  );
  EditProject copyWith({
    List<TimelineClip>? clips,
    String? title,
    bool? dirty,
    Map<String, Object>? effects,
  }) => EditProject(
    id: id,
    clips: clips ?? this.clips,
    title: title ?? this.title,
    updatedAt: DateTime.now(),
    dirty: dirty ?? true,
    effects: effects ?? this.effects,
  );
  Map<String, Object> toJson() => {
    'version': 1,
    'id': id,
    'title': title,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'clips': clips.map((c) => c.toJson()).toList(),
    'effects': effects,
  };
  factory EditProject.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 ||
        json['clips'] is! List ||
        (json['clips'] as List).length > 30) {
      throw const FormatException('Unsupported project document');
    }
    return EditProject(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled project',
      effects: (json['effects'] as Map?)?.cast<String, Object>() ?? const {},
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
      clips: (json['clips'] as List)
          .map((c) => TimelineClip.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
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
