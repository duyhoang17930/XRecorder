import 'dart:math' as math;

/// All times are milliseconds on the output timeline. Audio in/out are source
/// times. Drafts without these additive fields retain their previous behavior.
class AudioTrack {
  const AudioTrack({
    required this.uri,
    required this.sourceDurationMs,
    required this.outMs,
    this.inMs = 0,
    this.offsetMs = 0,
    this.volume = 1,
    this.fadeInMs = 0,
    this.fadeOutMs = 0,
    this.voice = 'none',
    this.noiseReduction = false,
  });
  final String uri, voice;
  final int sourceDurationMs, inMs, outMs, offsetMs, fadeInMs, fadeOutMs;
  final double volume;
  final bool noiseReduction;
  void validate(int durationMs) {
    final length = math.min(outMs - inMs, durationMs - offsetMs);
    if (Uri.tryParse(uri)?.scheme != 'content' ||
        sourceDurationMs <= 0 ||
        sourceDurationMs > 86400000 ||
        inMs < 0 ||
        outMs <= inMs ||
        outMs > sourceDurationMs ||
        offsetMs < 0 ||
        offsetMs >= durationMs ||
        !volume.isFinite ||
        volume < 0 ||
        volume > 2 ||
        fadeInMs < 0 ||
        fadeOutMs < 0 ||
        fadeInMs + fadeOutMs > length ||
        !['none', 'deep', 'bright', 'robot'].contains(voice)) {
      throw const FormatException(
        'Check audio trim, timeline position, gain and fades. Fades must fit the audible track.',
      );
    }
  }

  Map<String, Object> toJson() => {
    'uri': uri,
    'sourceDurationMs': sourceDurationMs,
    'inMs': inMs,
    'outMs': outMs,
    'offsetMs': offsetMs,
    'volume': volume,
    'fadeInMs': fadeInMs,
    'fadeOutMs': fadeOutMs,
    'voice': voice,
    'noiseReduction': noiseReduction,
  };
  factory AudioTrack.fromJson(Map value) => AudioTrack(
    uri: value['uri'] as String,
    sourceDurationMs: (value['sourceDurationMs'] as num).toInt(),
    inMs: (value['inMs'] as num?)?.toInt() ?? 0,
    outMs: (value['outMs'] as num).toInt(),
    offsetMs: (value['offsetMs'] as num?)?.toInt() ?? 0,
    volume: (value['volume'] as num?)?.toDouble() ?? 1,
    fadeInMs: (value['fadeInMs'] as num?)?.toInt() ?? 0,
    fadeOutMs: (value['fadeOutMs'] as num?)?.toInt() ?? 0,
    voice: value['voice'] as String? ?? 'none',
    noiseReduction: value['noiseReduction'] == true,
  );
}

void validateLayer(Map<String, Object> value, int durationMs) {
  double n(String key, double fallback) =>
      (value[key] as num?)?.toDouble() ?? fallback;
  final start = n('startMs', 0), end = n('endMs', 0);
  if (!['text', 'sticker', 'drawing'].contains(value['kind']) ||
      !start.isFinite ||
      !end.isFinite ||
      start < 0 ||
      end <= start ||
      end > durationMs ||
      !n('x', .5).isFinite ||
      n('x', .5) < 0 ||
      n('x', .5) > 1 ||
      !n('y', .5).isFinite ||
      n('y', .5) < 0 ||
      n('y', .5) > 1 ||
      !n('scale', 1).isFinite ||
      n('scale', 1) < .1 ||
      n('scale', 1) > 4 ||
      !n('rotation', 0).isFinite ||
      n('rotation', 0).abs() > 360 ||
      (value['text'] as String? ?? '').length > 2000 ||
      (value['kind'] == 'text' &&
          (value['text'] as String? ?? '').trim().isEmpty)) {
    throw const FormatException(
      'Check layer text, position, size, rotation and times.',
    );
  }
  final points = value['points'] as List? ?? const [];
  if (points.length > 2048 ||
      (value['kind'] == 'drawing' && points.whereType<List>().length < 2)) {
    throw const FormatException(
      'Draw at least one stroke (up to 2048 points).',
    );
  }
  for (final point in points) {
    if (point == null) continue;
    if (point is! List ||
        point.length != 2 ||
        point.any((v) => v is! num || !v.isFinite || v < 0 || v > 1)) {
      throw const FormatException('Invalid drawing coordinates.');
    }
  }
}

/// Fit output-time annotations after a timeline cut. Undo owns the full previous
/// project, so a cut and all its annotation changes are restored together.
Map<String, Object> fitTimelineEffects(
  Map<String, Object> current,
  int durationMs,
) {
  final end = durationMs;
  final effects = Map<String, Object>.from(current);
  for (final key in ['subtitles', 'layers']) {
    final source = effects[key] as List?;
    if (source == null) continue;
    effects[key] = source
        .where((v) => ((v as Map)['startMs'] as num) < end)
        .map((v) {
          final row = Map<String, Object>.from(v as Map);
          row['endMs'] = (row['endMs'] as num).toInt().clamp(0, end);
          return row;
        })
        .toList();
  }
  final tracks = effects['audioTracks'] as List?;
  if (tracks != null) {
    effects['audioTracks'] = tracks
        .where((v) => ((v as Map)['offsetMs'] as num? ?? 0) < end)
        .map((v) {
          final row = Map<String, Object>.from(v as Map);
          final available = end - ((row['offsetMs'] as num?)?.toInt() ?? 0);
          final start = (row['inMs'] as num?)?.toInt() ?? 0;
          final out = (row['outMs'] as num).toInt().clamp(
            start,
            start + available,
          );
          row['outMs'] = out;
          final fadeIn = (row['fadeInMs'] as num?)?.toInt() ?? 0;
          final fadeOut = (row['fadeOutMs'] as num?)?.toInt() ?? 0;
          final sum = fadeIn + fadeOut;
          if (sum > out - start) {
            row['fadeInMs'] = ((out - start) * fadeIn / sum).floor();
            row['fadeOutMs'] = (out - start) - (row['fadeInMs'] as int);
          }
          return row;
        })
        .toList();
  }
  final fadeIn = (effects['fadeInMs'] as num?)?.toInt() ?? 0,
      fadeOut = (effects['fadeOutMs'] as num?)?.toInt() ?? 0;
  if (fadeIn + fadeOut > end) {
    effects['fadeInMs'] = (end * fadeIn / (fadeIn + fadeOut)).floor();
    effects['fadeOutMs'] = end - (effects['fadeInMs'] as int);
  }
  return effects;
}
