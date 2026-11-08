import 'package:characters/characters.dart';

class SubtitleCue {
  SubtitleCue({
    required this.startMs,
    required this.endMs,
    required this.text,
    this.joinerBefore = ' ',
  }) {
    if (!_validUtf16(text) ||
        RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]').hasMatch(text)) {
      throw const FormatException(
        'Subtitle text contains unsupported control characters or incomplete symbols.',
      );
    }
    if (text.length > 2000) {
      throw const FormatException(
        'Subtitle text is too long. Shorten it before applying.',
      );
    }
    if (joinerBefore.length > 2000 ||
        !RegExp(r'^\s*$').hasMatch(joinerBefore)) {
      throw const FormatException('Invalid subtitle separator.');
    }
    if (startMs < 0 ||
        endMs <= startMs ||
        text
            .replaceAll(
              RegExp(r'[\s\u200B-\u200F\u202A-\u202E\u2060-\u206F\uFEFF]'),
              '',
            )
            .isEmpty) {
      throw const FormatException(
        'Enter subtitle text and an end time after its start.',
      );
    }
  }
  final int startMs, endMs;
  final String text;

  /// Exact split separator; optional in stored drafts, ignored by renderers/SRT.
  final String joinerBefore;
  Map<String, Object> toJson() => {
    'startMs': startMs,
    'endMs': endMs,
    'text': text,
    if (joinerBefore != ' ') 'joinerBefore': joinerBefore,
  };
  factory SubtitleCue.fromJson(Map<String, dynamic> value) => SubtitleCue(
    startMs: value['startMs'] as int,
    endMs: value['endMs'] as int,
    text: value['text'] as String,
    joinerBefore: value['joinerBefore'] as String? ?? ' ',
  );

  static bool _validUtf16(String text) {
    final units = text.codeUnits;
    for (var i = 0; i < units.length; i++) {
      final value = units[i];
      if (value >= 0xd800 && value <= 0xdbff) {
        if (++i >= units.length || units[i] < 0xdc00 || units[i] > 0xdfff) {
          return false;
        }
      } else if (value >= 0xdc00 && value <= 0xdfff) {
        return false;
      }
    }
    return true;
  }
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
          joinerBefore: c.joinerBefore,
        ),
      ),
      durationMs: newDurationMs,
    );
  }

  SubtitleTrack split(int index) {
    final cue = cues[index],
        midpoint = (cues[index].startMs + cues[index].endMs) ~/ 2;
    final graphemes = cue.text.characters.toList(growable: false);
    if (graphemes.length < 2 || cue.endMs - cue.startMs < 400) {
      throw const FormatException(
        'Use at least two characters or words and 0.4 seconds to split.',
      );
    }
    final boundaries = <int>{0};
    var offset = 0;
    for (final grapheme in graphemes) {
      offset += grapheme.length;
      boundaries.add(offset);
    }
    final spaces = RegExp(r'\s+')
        .allMatches(cue.text)
        .where(
          (match) =>
              boundaries.contains(match.start) &&
              boundaries.contains(match.end) &&
              cue.text.substring(0, match.start).trim().isNotEmpty &&
              cue.text.substring(match.end).trim().isNotEmpty,
        )
        .toList();
    final String first, second, joiner;
    if (spaces.isNotEmpty) {
      final separator = spaces[spaces.length ~/ 2];
      first = cue.text.substring(0, separator.start);
      second = cue.text.substring(separator.end);
      joiner = separator.group(0)!;
    } else {
      final cut = (graphemes.length / 2).ceil();
      first = graphemes.take(cut).join();
      second = graphemes.skip(cut).join();
      joiner = '';
    }
    final next = cues.toList()
      ..replaceRange(index, index + 1, [
        SubtitleCue(
          startMs: cue.startMs,
          endMs: midpoint,
          text: first,
          joinerBefore: cue.joinerBefore,
        ),
        SubtitleCue(
          startMs: midpoint,
          endMs: cue.endMs,
          text: second,
          joinerBefore: joiner,
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
          text: '${a.text}${b.joinerBefore}${b.text}',
          joinerBefore: a.joinerBefore,
        ),
      ]);
    return SubtitleTrack(next, durationMs: durationMs);
  }

  String toSrt() {
    for (final cue in cues) {
      final lines = cue.text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
      if (RegExp(r'\n[ \t]*\n').hasMatch(lines)) {
        throw const FormatException(
          'SRT uses blank lines between cues. Remove empty lines within a cue before saving SRT. Your draft and MP4 keep the original text.',
        );
      }
    }
    String time(int ms) =>
        '${(ms ~/ 3600000).toString().padLeft(2, '0')}:${(ms ~/ 60000 % 60).toString().padLeft(2, '0')}:${(ms ~/ 1000 % 60).toString().padLeft(2, '0')},${(ms % 1000).toString().padLeft(3, '0')}';
    return [
      for (var i = 0; i < cues.length; i++)
        '${i + 1}\n${time(cues[i].startMs)} --> ${time(cues[i].endMs)}\n${cues[i].text}\n',
    ].join('\n');
  }
}
