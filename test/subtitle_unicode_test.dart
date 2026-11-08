import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/features/editor/subtitles.dart';

void main() {
  test('SRT reports ambiguous empty lines and retains original draft text', () {
    for (final separator in ['\n\n', '\r\n\r\n', '\n \t\n']) {
      final text = 'العربية$separatorहिन्दी';
      final track = SubtitleTrack([
        SubtitleCue(startMs: 0, endMs: 1000, text: text),
      ], durationMs: 1000);
      expect(track.toSrt, throwsFormatException);
      expect(SubtitleTrack.decode(track.toJson(), 1000).cues.single.text, text);
    }
    const text = '第一行\r\n第二行';
    expect(
      SubtitleTrack([
        SubtitleCue(startMs: 0, endMs: 1000, text: text),
      ], durationMs: 1000).toSrt(),
      contains(text),
    );
  });
  for (final text in ['你好世界字幕测试', '日本語の字幕テスト', '👩🏽‍💻👨‍👩‍👧‍👦']) {
    test('split and merge preserve no-space graphemes: $text', () {
      final original = SubtitleTrack([
        SubtitleCue(startMs: 0, endMs: 2000, text: text),
      ], durationMs: 2000);
      final split = original.split(0);
      expect(split.cues.length, 2);
      expect(split.merge(0).cues.single.text, text);
      final reopened = SubtitleTrack.decode(
        jsonDecode(jsonEncode(split.toJson())),
        2000,
      );
      expect(reopened.merge(0).cues.single.text, text);
      if (text.startsWith('👩')) {
        expect(split.cues.first.text, '👩🏽‍💻');
        expect(split.cues.last.text, '👨‍👩‍👧‍👦');
      }
    });
  }
  test(
    'split retains exact whitespace, line breaks, combining marks and timing',
    () {
      const text = 'Tiếng  Việt\n👩🏽‍💻 works';
      final track = SubtitleTrack([
        SubtitleCue(startMs: 200, endMs: 1800, text: text),
      ], durationMs: 2000);
      final split = track.split(0);
      expect(split.merge(0).cues.single.text, text);
      final speed = split.retime(1, 2, 1000);
      expect(speed.cues.first.startMs, 100);
      expect(speed.cues.last.endMs, 900);
      expect(speed.merge(0).cues.single.text, text);
      expect(track.toSrt(), contains('00:00:00,200 --> 00:00:01,800\n$text'));
    },
  );
  test('reject incomplete UTF16 and non-text controls without normalizing valid Unicode', () {
    for (final text in [
      'a\u0000b',
      'a\u0008b',
      'a\u007fb',
      'a\ud800b',
      'a\udc00b',
      '\u200b\u2067\u2069',
    ]) {
      expect(
        () => SubtitleCue(startMs: 0, endMs: 1000, text: text),
        throwsFormatException,
        reason: jsonEncode(text),
      );
    }
    const mixed = 'العربية 12:30\n\u2066Video 2\u2069 · हिन्दी 👩🏽‍💻';
    expect(SubtitleCue(startMs: 0, endMs: 1000, text: mixed).text, mixed);
    expect(
      SubtitleCue(startMs: 0, endMs: 1000, text: 'e\u0301').text,
      'e\u0301',
    );
  });
}
