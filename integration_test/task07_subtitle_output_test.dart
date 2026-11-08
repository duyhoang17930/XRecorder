import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/editor/editor_preview.dart';
import 'package:xrecorder/features/editor/subtitles.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Real multilingual cues, preview, SAF read-back and MP4 burn-in',
    (tester) async {
      const engine = MethodChannel('com.xrecorder/editor');
      const media = MethodChannel('com.xrecorder/media');
      const path = '/sdcard/Android/data/com.xrecorder.xrecorder/files/media/';
      const root = 'content://com.xrecorder.xrecorder.files/media/';
      final cases = jsonDecode(
        await File('${path}task07_subtitles.json').readAsString(),
      ) as List;
      final outputs = <String, String>{}, previews = <String, Object>{};
      final all = <SubtitleCue>[];
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final before = (await engine.invokeMapMethod<String, dynamic>(
        'editorDiagnostics',
      ))!;
      for (var i = 0; i < cases.length; i++) {
        final row = cases[i] as Map;
        final code = row['code'] as String;
        // The second cue is verbatim real Whisper output, deliberately retimed
        // by this editing test. Original ASR segment times remain in the manifest.
        var track = SubtitleTrack([
          SubtitleCue(startMs: 100, endMs: 1800, text: row['manual'] as String),
          SubtitleCue(
            startMs: 2100,
            endMs: 3900,
            text: row['generated'] as String,
          ),
        ], durationMs: 4000);
        track = SubtitleTrack.decode(track.split(0).merge(0).toJson(), 4000);
        expect(track.cues.first.text, row['manual']);
        for (final cue in track.cues) {
          all.add(
            SubtitleCue(
              startMs: i * 4000 + cue.startMs,
              endMs: i * 4000 + cue.endMs,
              text: cue.text,
            ),
          );
        }
        final options = <String, Object>{
          'subtitles': track.toJson(),
          'subtitleColor': i.isEven ? 'white' : 'yellow',
          'subtitleSize': ['small', 'normal', 'large'][i % 3],
          'subtitlePosition': i.isEven ? 'bottom' : 'top',
          'subtitleBackground': i % 3 == 0 ? 'none' : 'dark',
        };
        final project = EditProject(
          id: 'global_${stamp}_$code',
          title: 'Unicode $code',
          updatedAt: DateTime.now(),
          clips: [
            TimelineClip(
              mediaId: '${root}task07_subtitle_input.mp4',
              inPoint: Duration.zero,
              outPoint: const Duration(seconds: 4),
              sourceDuration: const Duration(seconds: 4),
            ),
          ],
          effects: options,
        );
        final key = GlobalKey<EditorPreviewState>();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: EditorPreview(
                    key: key,
                    project: project,
                    onPosition: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        for (var n = 0; n < 100 && key.currentState?.channel == null; n++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await key.currentState!.load();
        await tester.pumpAndSettle();
        await key.currentState!.command('play');
        await Future<void>.delayed(const Duration(milliseconds: 700));
        await key.currentState!.command('pause');
        final captures = <String, Object>{};
        for (final phase in ['manual', 'generated']) {
          final time = phase == 'manual' ? 800 : 2800;
          await key.currentState!.command('seek', time);
          await Future<void>.delayed(const Duration(milliseconds: 600));
          await tester.pumpAndSettle();
          await Future<void>.delayed(const Duration(milliseconds: 300));
          await tester.pump();
          final state = await key.currentState!.channel!
              .invokeMapMethod<String, dynamic>('state');
          expect(state?['error'], isNull);
          final rect = tester.getRect(find.byType(PlatformViewLink));
          captures[phase] = {
            'timeMs': time,
            'rect': [rect.left, rect.top, rect.width, rect.height],
            'devicePixelRatio': tester.view.devicePixelRatio,
            'state': state,
          };
          debugPrint('TASK07_SUBTITLE_PREVIEW=${code}_$phase');
          // Host companion captures the actual Android surface, not an offscreen oracle.
          await Future<void>.delayed(const Duration(seconds: 3));
        }
        previews[code] = captures;
        await tester.pumpWidget(const MaterialApp(home: Scaffold()));
        await tester.pumpAndSettle();
        outputs[code] = (await engine
            .invokeMethod<String>('engineProbe', project.toJson())
            .timeout(const Duration(minutes: 2)))!;
        binding.reportData = {
          'outputs': outputs,
          'previews': previews,
          'partial': true,
        };
        for (final phase in ['manual', 'generated']) {
          final diag = (await engine.invokeMapMethod<String, dynamic>(
            'subtitleDiagnostics',
            {'text': row[phase], 'chunkText': row[phase], 'options': options},
          ))!;
          await File('${path}task07_oracle_${code}_$phase.png')
              .writeAsBytes(diag['fresh'] as Uint8List);
        }
      }
      final body = SubtitleTrack(all, durationMs: cases.length * 4000).toSrt();
      final after = (await engine.invokeMapMethod<String, dynamic>(
        'editorDiagnostics',
      ))!;
      expect(
        (after['previewLoads'] as int) - (before['previewLoads'] as int),
        cases.length,
      );
      expect(after['previewReleaseFailures'], before['previewReleaseFailures']);
      final name = 'TASK07_العربية_हिन्दी_日本語_中文_👩🏽‍💻_$stamp.srt';
      debugPrint('TASK07_SUBTITLE_SAVE_READY');
      final uri = (await media.invokeMethod<String>('exportSrt', {
        'text': body,
        'fileName': name,
      }))!;
      final read = (await media.invokeMapMethod<String, dynamic>(
        'readSubtitleDocument',
        {'uri': uri},
      ))!;
      final bytes = read['bytes'] as Uint8List;
      expect(listEquals(bytes, utf8.encode(body)), isTrue);
      expect(read['name'], name);
      await File('${path}task07_verified.srt').writeAsBytes(bytes);
      binding.reportData = {
        'outputs': outputs,
        'previews': previews,
        'srtUri': uri,
        'srtName': read['name'],
        'srtBytes': bytes.length,
        'srtByteExact': true,
        'sourceManifest': 'task07_subtitles.json',
        'diagnosticsBefore': before,
        'diagnosticsAfter': after,
        'locales': cases.map((v) => v['code']).toList(),
        'partial': false,
      };
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
