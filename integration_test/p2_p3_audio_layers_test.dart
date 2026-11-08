import 'package:flutter/material.dart';

import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/features/editor/editor_preview.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/core/domain/models.dart';

Future<void> _matrix(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
) async {
  const engine = AndroidEditProjectRepository.channel;
  const privateFixtures = bool.fromEnvironment('QA_PRIVATE_FIXTURES');
  const root = privateFixtures
      ? 'content://com.xrecorder.xrecorder.files/trash/'
      : 'content://com.xrecorder.xrecorder.files/media/';
  const dir = privateFixtures
      ? '/data/user/0/com.xrecorder.xrecorder/files/trash/'
      : '/sdcard/Android/data/com.xrecorder.xrecorder/files/media/';
  final outputs = <String, String>{};
  const codecsOnly = bool.fromEnvironment('MATRIX_CODECS');
  final sourceNames = codecsOnly
      ? ['quality_h264.mp4', 'quality_hevc.mp4']
      : [
          'quality_24.mp4',
          'quality_60.mp4',
          'quality_30.mp4',
          'quality_rot90.mp4',
          'quality_vfr.mp4',
          'quality_silent.mp4',
        ];
  final sources = <String, List<int>>{};
  for (final name in sourceNames) {
    sources[name] = await File('$dir$name').readAsBytes();
  }
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: Text('Real input/output matrix'))),
  );
  final cases = codecsOnly
      ? <String, (String, int, Map<String, Object>)>{
          'h264Input': ('quality_h264.mp4', 4000, {'fps': 30}),
          'hevcBframes': ('quality_hevc.mp4', 1000, {'fps': 30}),
        }
      : <String, (String, int, Map<String, Object>)>{
          'fps60_cap24': ('quality_60.mp4', 6000, {'fps': 24}),
          'stereo441': ('quality_24.mp4', 6000, {'fps': 30}),
          'rotation90': ('quality_rot90.mp4', 6000, {'fps': 30}),
          'variableFps': ('quality_vfr.mp4', 6000, {'fps': 30}),
          'noAudio': ('quality_silent.mp4', 6000, {'fps': 30}),
          'short200': ('quality_30.mp4', 200, {'fps': 30}),
        };
  for (final entry in cases.entries) {
    if (const bool.fromEnvironment('PREVIEW_ONLY')) break;
    final (name, duration, effects) = entry.value;
    final project = EditProject(
      id: 'matrix_${entry.key}_${DateTime.now().microsecondsSinceEpoch}',
      updatedAt: DateTime.now(),
      clips: [
        TimelineClip(
          mediaId: '$root$name',
          inPoint: Duration.zero,
          outPoint: Duration(milliseconds: duration),
          sourceDuration: Duration(milliseconds: codecsOnly ? duration : 6000),
        ),
      ],
      effects: effects,
    );
    outputs[entry.key] = (await engine.invokeMethod<String>(
      'engineProbe',
      project.toJson(),
    ))!;
    binding.reportData = {'outputs': outputs, 'partial': true};
  }
  for (final name in sourceNames) {
    expect(
      await File('$dir$name').readAsBytes(),
      orderedEquals(sources[name]!),
    );
  }
  final phase = const String.fromEnvironment('PREVIEW_PHASE');
  Map<String, Object?> layout = {};
  if (phase.isNotEmpty) {
    final project = EditProject(
      id: 'portrait_layout',
      updatedAt: DateTime.now(),
      clips: [
        TimelineClip(
          mediaId: '${root}quality_rot90.mp4',
          inPoint: Duration.zero,
          outPoint: const Duration(seconds: 6),
          sourceDuration: const Duration(seconds: 6),
        ),
      ],
    );
    final key = GlobalKey<EditorPreviewState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Portrait preview')),
          body: EditorPreview(key: key, project: project, onPosition: (_) {}),
        ),
      ),
    );
    for (var i = 0; i < 50 && key.currentState?.channel == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await key.currentState!.load();
    await key.currentState!.command('play');
    await tester.pump(const Duration(seconds: 1));
    await key.currentState!.command('pause');
    await key.currentState!.command('seek', 500);
    await tester.pump(const Duration(seconds: 1));
    // Hybrid surfaces commit asynchronously on Android14. Give both native
    // layout and Flutter's overlay image a real frame after the aspect changes.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await tester.pump();
    final state = (await key.currentState!.channel!
        .invokeMapMethod<String, dynamic>('state'))!;
    expect(state['error'], isNull);
    final size = tester.getSize(find.byType(PlatformViewLink));
    layout = {
      'phase': phase,
      'width': size.width,
      'height': size.height,
      'native': state,
      'physicalSize': tester.view.physicalSize.toString(),
      'devicePixelRatio': tester.view.devicePixelRatio,
    };
    debugPrint('FINALQA_PREVIEW_READY=$phase');
    await Future<void>.delayed(const Duration(seconds: 6));
  }
  binding.reportData = {
    'outputs': outputs,
    'sourceBytesUnchanged': true,
    'partial': false,
    'portraitLayout': layout,
  };
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Real PCM multitrack, fades, voice, cleanup and timed layers', (
    tester,
  ) async {
    const engine = AndroidEditProjectRepository.channel;
    const media = MethodChannel('com.xrecorder/media');
    const root = 'content://com.xrecorder.xrecorder.files/media/';
    final stamp = DateTime.now().microsecondsSinceEpoch;
    if (const bool.fromEnvironment('P2_P3_MATRIX')) {
      await _matrix(tester, binding);
      return;
    }
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
    final scenarios = <String, Map<String, Object>>{
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
    };
    const reuseOutputs = String.fromEnvironment('AUDIO_REUSE_OUTPUTS');
    if (const bool.fromEnvironment('TASK08_EIGHT_TRACKS')) {
      scenarios['eightTrackMix'] = {
        'volume': 0.0,
        'audioTracks': [
          for (var i = 0; i < 8; i++)
            {
              'uri': '${root}p2_p3_speech_noisy.wav',
              'sourceDurationMs': 11340,
              'inMs': i * 25,
              'outMs': 4000,
              'offsetMs': i * 50,
              'volume': .125,
              'fadeInMs': 500,
              'fadeOutMs': 500,
              'voice': ['deep', 'robot', 'bright'][i % 3],
              'noiseReduction': true,
            },
        ],
      };
    }
    if (reuseOutputs.isNotEmpty) {
      expect(
        RegExp(r'^task07_audio_[0-9]+\.json$').hasMatch(reuseOutputs),
        isTrue,
      );
      outputs.addAll(
        Map<String, String>.from(
          jsonDecode(
            await File(
              '/data/user/0/com.xrecorder.xrecorder/files/$reuseOutputs',
            ).readAsString(),
          ) as Map,
        ),
      );
      expect(outputs.keys.toSet(), scenarios.keys.toSet());
      for (final uri in outputs.values) {
        expect(
          await media.invokeMethod<Uint8List>('thumbnailAt', {
            'uri': uri,
            'timeMs': 750,
          }),
          isNotEmpty,
        );
      }
    } else {
      for (final entry in scenarios.entries) {
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
        binding.reportData = {
          'outputs': Map<String, String>.of(outputs),
          'partial': true,
          'fixturesRetained': true,
        };
      }
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
    final parity = <Map<String, Object?>>[];
    if (const bool.fromEnvironment('PREVIEW_PARITY')) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorPreview(
              key: key,
              project: project('parity', scenarios['mix']!),
              onPosition: (_) {},
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump();
      for (final time in [800, 1800, 2500, 3500]) {
        await key.currentState!.command('seek', time);
        Map<String, dynamic>? nativeState;
        var stable = 0;
        for (var attempt = 0; attempt < 100; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
          nativeState = await key.currentState!.channel!
              .invokeMapMethod<String, dynamic>('state');
          expect(nativeState!['error'], isNull);
          final ready =
              nativeState['playbackState'] == 3 &&
              nativeState['renderedFirstFrame'] == true &&
              ((nativeState['positionMs'] as num) - time).abs() < 50;
          stable = ready ? stable + 1 : 0;
          if (stable >= 3) break;
        }
        expect(
          stable,
          greaterThanOrEqualTo(3),
          reason: 'Capture an actually rendered, stable seek, not a buffering black frame.',
        );
        final rect = tester.getRect(find.byType(PlatformViewLink));
        parity.add({
          'timeMs': time,
          'left': rect.left,
          'top': rect.top,
          'width': rect.width,
          'height': rect.height,
          'dpr': tester.view.devicePixelRatio,
          'nativeState': nativeState,
        });
        debugPrint('FINALQA_PARITY=$time');
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    await tester.pumpWidget(const SizedBox());
    binding.reportData = {
      'outputs': outputs,
      'durationMs': 4000,
      'previewSeekPassed': true,
      'playheadPreservedOnEffectChange': true,
      'fixturesRetained': true,
      'previewParity': parity,
    };
  }, timeout: const Timeout(Duration(minutes: 15)));
}
