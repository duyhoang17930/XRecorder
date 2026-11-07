class SubtitleCue {
  SubtitleCue({
    required this.startMs,
    required this.endMs,
    required this.text,
  }) {
    if (startMs < 0 ||
        endMs <= startMs ||
        text.trim().isEmpty ||
        text.length > 2000) {
      throw const FormatException(
        'Enter subtitle text and an end time after its start.',
      );
    }
  }
  final int startMs, endMs;
  final String text;
  Map<String, Object> toJson() => {
    'startMs': startMs,
    'endMs': endMs,
    'text': text,
  };
  factory SubtitleCue.fromJson(Map<String, dynamic> value) => SubtitleCue(
    startMs: value['startMs'] as int,
    endMs: value['endMs'] as int,
    text: value['text'] as String,
  );
}

class SubtitleTrack {
  SubtitleTrack(Iterable<SubtitleCue> values, {required this.durationMs})
    : cues = List.unmodifiable(
        values.toList()..sort((a, b) => a.startMs.compareTo(b.startMs)),
      ) {
    if (cues.length > 200) {
      throw const FormatException('Maximum 200 subtitle segments.');
    }
    var previousEnd = 0;
    for (final cue in cues) {
      if (cue.startMs < previousEnd || cue.endMs > durationMs) {
        throw const FormatException(
          'Subtitles must fit the timeline without overlapping.',
        );
      }
      previousEnd = cue.endMs;
    }
  }
  final int durationMs;
  final List<SubtitleCue> cues;
  factory SubtitleTrack.decode(Object? data, int durationMs) => SubtitleTrack(
    ((data as List?) ?? []).map(
      (v) => SubtitleCue.fromJson((v as Map).cast<String, dynamic>()),
    ),
    durationMs: durationMs,
  );
  List<Object> toJson() => cues.map((c) => c.toJson()).toList();
  SubtitleTrack retime(double oldSpeed, double newSpeed, int newDurationMs) {
    if (!oldSpeed.isFinite ||
        !newSpeed.isFinite ||
        oldSpeed <= 0 ||
        newSpeed <= 0) {
      throw const FormatException('Invalid subtitle playback speed.');
    }
    final ratio = oldSpeed / newSpeed;
    return SubtitleTrack(
      cues.map(
        (c) => SubtitleCue(
          startMs: (c.startMs * ratio).round(),
          endMs: (c.endMs * ratio).round().clamp(1, newDurationMs),
          text: c.text,
        ),
      ),
      durationMs: newDurationMs,
    );
  }

  SubtitleTrack split(int index) {
    final cue = cues[index],
        midpoint = (cues[index].startMs + cues[index].endMs) ~/ 2;
    final words = cue.text.split(RegExp(r'\s+'));
    if (words.length < 2 || cue.endMs - cue.startMs < 400) {
      throw const FormatException(
        'Use at least two words and 0.4 seconds to split.',
      );
    }
    final cut = (words.length / 2).ceil();
    final next = cues.toList()
      ..replaceRange(index, index + 1, [
        SubtitleCue(
          startMs: cue.startMs,
          endMs: midpoint,
          text: words.take(cut).join(' '),
        ),
        SubtitleCue(
          startMs: midpoint,
          endMs: cue.endMs,
          text: words.skip(cut).join(' '),
        ),
      ]);
    return SubtitleTrack(next, durationMs: durationMs);
  }

  SubtitleTrack merge(int index) {
    final a = cues[index], b = cues[index + 1];
    final next = cues.toList()
      ..replaceRange(index, index + 2, [
        SubtitleCue(
          startMs: a.startMs,
          endMs: b.endMs,
          text: '${a.text} ${b.text}',
        ),
      ]);
    return SubtitleTrack(next, durationMs: durationMs);
  }

  String toSrt() {
    String time(int ms) =>
        '${(ms ~/ 3600000).toString().padLeft(2, '0')}:${(ms ~/ 60000 % 60).toString().padLeft(2, '0')}:${(ms ~/ 1000 % 60).toString().padLeft(2, '0')},${(ms % 1000).toString().padLeft(3, '0')}';
    return [
      for (var i = 0; i < cues.length; i++)
        '${i + 1}\n${time(cues[i].startMs)} --> ${time(cues[i].endMs)}\n${cues[i].text}\n',
    ].join('\n');
  }
}
