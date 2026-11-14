import '../../core/domain/models.dart';

/// Native presets use long/short edges and support both capture orientations.
bool supportsRecordingTuple(
  RecordingCapabilities capabilities, {
  required int width,
  required int height,
  required int fps,
  required VideoCodec codec,
}) {
  final longEdge = width > height ? width : height;
  final shortEdge = width < height ? width : height;
  return capabilities.configurations.any(
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
  final longEdge = settings.width > settings.height
      ? settings.width
      : settings.height;
  final shortEdge = settings.width < settings.height
      ? settings.width
      : settings.height;
  final exceedsPerformance =
      settings.mode == RecordingMode.performance &&
      (longEdge > 1280 ||
          shortEdge > 720 ||
          settings.fps > 30 ||
          (settings.bitrate ?? 0) > 8000000);
  if (!supportsRecordingTuple(
        caps,
        width: settings.width,
        height: settings.height,
        fps: settings.fps,
        codec: settings.codec,
      ) ||
      exceedsPerformance ||
      !caps.audioSources.contains(settings.audioSource)) {
    throw const DomainFailure(
      FailureCode.invalid,
      'The selected settings are unavailable. Choose a supported resolution, FPS, codec and audio source; Performance uses up to 720p, 30 FPS and 8 Mbps.',
    );
  }
}
