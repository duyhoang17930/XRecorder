import '../../core/domain/models.dart';

/// Native capabilities(activity) advertises canonical long/short-edge presets
/// only when both encoder orientations fit. Orientation selects the output axes,
/// not another preset; native preflight still checks the actual encoder tuple.
bool supportsRecordingTuple(
  RecordingCapabilities caps, {
  required int width,
  required int height,
  required int fps,
  required VideoCodec codec,
  RecordingMode mode = RecordingMode.normal,
}) {
  final longEdge = width > height ? width : height;
  final shortEdge = width < height ? width : height;
  if (shortEdge <= 0 || fps <= 0) return false;
  if (mode == RecordingMode.performance &&
      (longEdge > 1280 || shortEdge > 720 || fps > 30)) {
    return false;
  }
  return caps.configurations.any(
    (c) =>
        (c.width > c.height ? c.width : c.height) == longEdge &&
        (c.width < c.height ? c.width : c.height) == shortEdge &&
        c.fps == fps &&
        c.codec == codec,
  );
}

void validateRecordingSelection(
  RecordingSettings settings,
  RecordingCapabilities caps,
) {
  if (!supportsRecordingTuple(
        caps,
        width: settings.width,
        height: settings.height,
        fps: settings.fps,
        codec: settings.codec,
        mode: settings.mode,
      ) ||
      (settings.mode == RecordingMode.performance &&
          (settings.bitrate ?? 0) > 8000000) ||
      !caps.audioSources.contains(settings.audioSource)) {
    throw const DomainFailure(
      FailureCode.invalid,
      'The selected settings are unavailable. Choose a supported resolution, FPS, codec and audio source; Performance uses up to 720p, 30 FPS and 8 Mbps.',
    );
  }
}
