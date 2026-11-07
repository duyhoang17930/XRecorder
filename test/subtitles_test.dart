import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:xrecorder/app/theme/app_theme.dart';
import 'package:xrecorder/features/editor/subtitle_editor.dart';
import 'package:xrecorder/features/editor/subtitles.dart';
import 'package:xrecorder/features/editor/transcription_service.dart';

void main() {
  test(
    'speed changes retime long subtitles while keeping SRT Unicode text',
    () {
      final text = List.filled(40, 'Tiếng Việt').join(' ');
      final track = SubtitleTrack([
        SubtitleCue(startMs: 500, endMs: 3500, text: text),
      ], durationMs: 4000);
      final fast = track.retime(1, 2, 2000);
      expect(fast.cues.single.startMs, 250);
      expect(fast.cues.single.endMs, 1750);
      expect(fast.toSrt(), contains('00:00:00,250 --> 00:00:01,750'));
      expect(fast.toSrt(), contains(text));
      expect(fast.retime(2, 1, 4000).toJson(), track.toJson());
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final width in [320.0, 411.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'manual subtitles fit $width dark$dark at text200 and apply real cue',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });
          SubtitleTrack? result;
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async {
                      result = await editSubtitles(
                        context,
                        SubtitleTrack([], durationMs: 5000),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byType(TextField).at(0),
            'Xin chào Việt Nam',
          );
          tester.testTextInput.hide();
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Add subtitle'));
          await tester.tap(find.text('Add subtitle'));
          await tester.pumpAndSettle();
          expect(find.text('Xin chào Việt Nam'), findsOneWidget);
          await tester.enterText(find.byType(TextField).at(0), 'Invalid range');
          await tester.enterText(find.byType(TextField).at(2), '1e308');
          tester.testTextInput.hide();
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Add subtitle'));
          await tester.tap(find.text('Add subtitle'));
          await tester.pumpAndSettle();
          expect(
            find.text('Enter valid times within the video.'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Apply subtitles'));
          await tester.tap(find.text('Apply subtitles'));
          await tester.pumpAndSettle();
          expect(result!.cues.single.text, 'Xin chào Việt Nam');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  test(
    'Vietnamese SRT, sorted non-overlap, split/merge and range validation',
    () {
      final track = SubtitleTrack([
        SubtitleCue(startMs: 100, endMs: 2100, text: 'Xin chào thế giới'),
      ], durationMs: 5000);
      expect(
        track.toSrt(),
        '1\n00:00:00,100 --> 00:00:02,100\nXin chào thế giới\n',
      );
      final split = track.split(0);
      expect(split.cues.map((c) => c.text), ['Xin chào', 'thế giới']);
      expect(split.cues.first.endMs, split.cues.last.startMs);
      expect(split.merge(0).cues.single.text, 'Xin chào thế giới');
      expect(
        () => SubtitleTrack([
          SubtitleCue(startMs: 0, endMs: 2000, text: 'a'),
          SubtitleCue(startMs: 1999, endMs: 3000, text: 'b'),
        ], durationMs: 5000),
        throwsFormatException,
      );
      expect(
        () => SubtitleTrack(track.cues, durationMs: 1000),
        throwsFormatException,
      );
    },
  );
  test(
    'unconfigured or unsupported remote ASR never receives the source',
    () async {
      var starts = 0;
      var mode = 'notConfigured';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidTranscriptionService.channel, (
            call,
          ) async {
            if (call.method == 'transcriptionAvailability') return mode;
            if (call.method == 'transcriptionStart') starts++;
            return 'id';
          });
      const service = AndroidTranscriptionService();
      final request = TranscriptionRequest(
        audioUri: Uri.parse('content://fixture/audio'),
        durationMs: 1000,
        language: 'vi',
        operationId: 'op',
      );
      await expectLater(service.start(request), throwsException);
      mode = 'remote';
      await expectLater(service.start(request), throwsException);
      expect(starts, 0);
    },
  );
}
