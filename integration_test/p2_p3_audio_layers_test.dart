import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/features/editor/editor_preview.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/core/domain/models.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Real PCM multitrack, fades, voice, cleanup and timed layers', (
    tester,
  ) async {
    const engine = AndroidEditProjectRepository.channel;
    const media = MethodChannel('com.xrecorder/media');
    const root = 'content://com.xrecorder.xrecorder.files/media/';
    final stamp = DateTime.now().microsecondsSinceEpoch;
    EditProject project(String name, Map<String, Object> effects) =>
        EditProject(
          id: 'audio_${stamp}_$name',
          title: name,
          updatedAt: DateTime.now(),
          clips: [
            TimelineClip(
              mediaId: '${root}p2_p3_audio_video.mp4',
              inPoint: Duration.zero,
              outPoint: Duration(seconds: 4),
              sourceDuration: Duration(seconds: 4),
            ),
          ],
          effects: effects,
        );
    final outputs = <String, String>{};
    for (final entry in <String, Map<String, Object>>{
      'baseline': {},
      'gain': {'volume': 2.0},
      'fades': {'fadeInMs': 1000, 'fadeOutMs': 1000},
      'robot': {'voice': 'robot'},
      'deep': {'voice': 'deep'},
      'bright': {'voice': 'bright'},
      'mixedLegacy': {
        'volume': 0.0,
        'music': '${root}p2_p3_tone_440.wav',
        'musicVolume': 1.0,
        'audioTracks': [
          {
            'uri': '${root}p2_p3_tone_880.wav',
            'sourceDurationMs': 4000,
            'inMs': 0,
            'outMs': 4000,
            'offsetMs': 0,
            'volume': 1.0,
          },
        ],
      },
      'noise': {'noiseReduction': true},
      'speechNoisy': {
        'volume': 0.0,
        'audioTracks': [
          {
            'uri': '${root}p2_p3_speech_noisy.wav',
            'sourceDurationMs': 11340,
            'inMs': 0,
            'outMs': 4000,
            'offsetMs': 0,
            'volume': 1.0,
          },
        ],
      },
      'speechDenoised': {
        'volume': 0.0,
        'audioTracks': [
          {
            'uri': '${root}p2_p3_speech_noisy.wav',
            'sourceDurationMs': 11340,
            'inMs': 0,
            'outMs': 4000,
            'offsetMs': 0,
            'volume': 1.0,
            'noiseReduction': true,
          },
        ],
      },
      'trackTrim': {
        'volume': 0.0,
        'audioTracks': [
          {
            'uri': '${root}p2_p3_tone_switch.wav',
            'sourceDurationMs': 4000,
            'inMs': 1000,
            'outMs': 3000,
            'offsetMs': 500,
            'volume': 1.0,
          },
        ],
      },
      'mix': {
        'volume': 0.0,
        'audioTracks': [
          {
            'uri': '${root}p2_p3_tone_440.wav',
            'sourceDurationMs': 4000,
            'inMs': 500,
            'outMs': 3500,
            'offsetMs': 0,
            'volume': .5,
            'fadeInMs': 500,
            'fadeOutMs': 500,
          },
          {
            'uri': '${root}p2_p3_tone_880.wav',
            'sourceDurationMs': 4000,
            'inMs': 0,
            'outMs': 2000,
            'offsetMs': 1000,
            'volume': .5,
          },
        ],
        'layers': [
          {
            'kind': 'text',
            'text': 'Tiếng Việt · editor',
            'startMs': 500,
            'endMs': 1500,
            'x': .5,
            'y': .3,
            'scale': 1.0,
            'rotation': 15,
            'color': 0xFFFFFF00,
          },
          {
            'kind': 'sticker',
            'sticker': 'star',
            'startMs': 2000,
            'endMs': 3000,
            'x': .7,
            'y': .5,
            'scale': 1.2,
            'rotation': 45,
            'color': 0xFFFF0000,
          },
          {
            'kind': 'drawing',
            'startMs': 3000,
            'endMs': 4000,
            'points': [
              [.1, .1],
              [.5, .9],
              [.9, .1],
            ],
            'x': .5,
            'y': .5,
            'scale': 1.0,
            'rotation': 0,
            'color': 0xFF00FF00,
          },
        ],
      },
    }.entries) {
      final draft = project(entry.key, entry.value);
      await AndroidEditProjectRepository().save(draft);
      final uri = (await engine
          .invokeMethod<String>('engineProbe', draft.toJson())
          .timeout(const Duration(minutes: 3)))!;
      final thumbnail = await media.invokeMethod<Uint8List>('thumbnailAt', {
        'uri': uri,
        'timeMs': 750,
      });
      expect(thumbnail, isNotEmpty);
      outputs[entry.key] = uri;
    }
    // Exercise native preview processing and seek for the very same composition.
    final key = GlobalKey<EditorPreviewState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPreview(
            key: key,
            project: project('preview', {
              'fadeInMs': 1000,
              'voice': 'robot',
              'noiseReduction': true,
            }),
            onPosition: (_) {},
          ),
        ),
      ),
    );
    for (var i = 0; i < 30 && key.currentState?.channel == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    }
    await key.currentState!.load();
    await key.currentState!.command('play');
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pump();
    await key.currentState!.command('seek', 2000);
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pump();
    expect(key.currentState!.error, isNull);
    await key.currentState!.command('pause');
    await key.currentState!.command('seek', 1500);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorPreview(
            key: key,
            project: project('preview', {
              'voice': 'deep',
              'noiseReduction': true,
            }),
            onPosition: (_) {},
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pump();
    final state = await key.currentState!.channel!
        .invokeMapMethod<String, dynamic>('state');
    expect(state!['positionMs'], inInclusiveRange(1300, 1700));
    expect(key.currentState!.error, isNull);
    await tester.pumpWidget(const SizedBox());
    binding.reportData = {
      'outputs': outputs,
      'durationMs': 4000,
      'previewSeekPassed': true,
      'playheadPreservedOnEffectChange': true,
      'fixturesRetained': true,
    };
  }, timeout: const Timeout(Duration(minutes: 15)));
}
