import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/app/theme/app_theme.dart';
import 'package:xrecorder/features/editor/audio_tracks_editor.dart';
import 'package:xrecorder/features/editor/layers_editor.dart';
import 'package:xrecorder/features/editor/project_effects.dart';
import 'package:xrecorder/features/editor/subtitle_editor.dart';
import 'package:xrecorder/features/editor/subtitles.dart';
import 'package:xrecorder/l10n/localization.dart';

import 'fixtures/interaction_probe.dart';

void main() => registerEditorInteractionTests();

void registerEditorInteractionTests({InteractionProbe? evidence}) {
  final probe =
      evidence ??
      InteractionProbe(
        'widget / editing dialog result assertions; no native encoder',
      );
  tearDownAll(() {
    final path = Platform.environment['TASK09B_EDITOR_EVIDENCE'];
    if (path != null) {
      final file = File(path)..createSync(exclusive: true);
      file.writeAsStringSync(probe.encode(), encoding: utf8, flush: true);
    }
  });
  Future<void> open(
    WidgetTester tester,
    Future<Object?> Function(BuildContext) action,
  ) async {
    tester.view.physicalSize = const Size(411, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => action(context),
              child: const Text('Open QA dialog'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open QA dialog'));
    await tester.pumpAndSettle();
  }

  Future<void> click(WidgetTester tester, String label) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final finder = find.text(label).last;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    expect(finder.hitTestable(), findsOneWidget);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> field(WidgetTester tester, String label, String value) async {
    final finder = find.widgetWithText(TextField, label);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.enterText(finder, value);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(finder).controller!.text, value);
  }

  Future<void> choose(WidgetTester tester, String label, String option) async {
    final finder = find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is DropdownButtonFormField),
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
    await click(tester, option);
    final value = (tester.state(finder) as FormFieldState).value as Object;
    expect(tester.element(finder).effectValue(value), option);
  }

  Future<void> step(
    WidgetTester tester,
    String id,
    String locator,
    Future<void> Function() action,
    void Function() verify,
  ) => probe.step(
    tester,
    id: id,
    route: 'editor dialogs',
    state: id,
    locator: locator,
    expected:
        'Action updates rendered control and committed dialog data as asserted',
    action: action,
    verify: verify,
    owner: 'P3',
  );

  testWidgets(
    'audio edit all numeric fields gain voice noise and remove without mutating input',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final original = <String, Object>{
        'uri': 'content://qa/audio',
        'sourceDurationMs': 10000,
        'inMs': 0,
        'outMs': 3000,
        'offsetMs': 0,
      };
      List<Map<String, Object>>? output;
      try {
        await open(
          tester,
          (context) async =>
              output = await editAudioTracks(context, [original], 10000),
        );
        await click(tester, 'Track 1');
        for (final entry in [
          ('Start in audio (seconds)', '1'),
          ('End in audio (seconds)', '6'),
          ('Start in video (seconds)', '2'),
          ('Fade in (seconds)', '0.2'),
          ('Fade out (seconds)', '0.4'),
        ]) {
          await step(
            tester,
            'G3-AUDIO-${entry.$1}',
            entry.$1,
            () => field(tester, entry.$1, entry.$2),
            () {},
          );
        }
        final slider = find.byType(Slider);
        await tester.ensureVisible(slider);
        await tester.pumpAndSettle();
        await step(tester, 'G3-AUDIO-GAIN', 'Slider', () async {
          await tester.tapAt(tester.getRect(slider).center);
          await tester.pumpAndSettle();
        }, () => expect(tester.widget<Slider>(slider).value, closeTo(1, .06)));
        await choose(tester, 'Voice effect', 'Deep voice');
        await click(tester, 'Reduce background noise');
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isTrue,
        );
        await click(tester, 'Use audio');
        await click(tester, 'Use tracks');
        final row = output!.single;
        expect(row['inMs'], 1000);
        expect(row['outMs'], 6000);
        expect(row['offsetMs'], 2000);
        expect(row['fadeInMs'], 200);
        expect(row['fadeOutMs'], 400);
        expect(row['voice'], 'deep');
        expect(row['noiseReduction'], isTrue);
        expect(original['inMs'], 0);
        await tester.tap(find.text('Open QA dialog'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Remove audio track 1'));
        await tester.pumpAndSettle();
        expect(find.text('Track 1'), findsNothing);
        await click(tester, 'Cancel');
        expect(original['outMs'], 3000);
      } finally {
        await tester.pumpWidget(const SizedBox());
        semantics.dispose();
      }
    },
  );

  testWidgets('audio invalid range retains editor then corrected input saves', (
    tester,
  ) async {
    List<Map<String, Object>>? output;
    await open(
      tester,
      (context) async => output = await editAudioTracks(context, [
        {
          'uri': 'content://qa/audio',
          'sourceDurationMs': 10000,
          'inMs': 0,
          'outMs': 3000,
          'offsetMs': 0,
        },
      ], 10000),
    );
    await click(tester, 'Track 1');
    await field(tester, 'End in audio (seconds)', '-1');
    await click(tester, 'Use audio');
    expect(find.text('Trim & mix audio'), findsOneWidget);
    expect(output, isNull);
    await field(tester, 'End in audio (seconds)', '2');
    await click(tester, 'Use audio');
    await click(tester, 'Use tracks');
    expect(output!.single['outMs'], 2000);
  });

  testWidgets(
    'layers add text transforms sticker drawing order delete and commit',
    (tester) async {
      final semantics = tester.ensureSemantics();
      List<Map<String, Object>>? output;
      try {
        await open(
          tester,
          (context) async => output = await editLayers(context, [], 10000),
        );
        await click(tester, 'Add Text');
        await field(tester, 'Layer text', 'Tiếng Việt 日本語 👩🏽‍💻');
        await field(tester, 'Start (seconds)', '1');
        await field(tester, 'End (seconds)', '8');
        for (var i = 0; i < 4; i++) {
          final slider = find.byType(Slider).at(i);
          await tester.ensureVisible(slider);
          await tester.pumpAndSettle();
          await step(
            tester,
            'G3-LAYER-TRANSFORM-$i',
            'Slider#$i',
            () async {
              final rect = tester.getRect(slider);
              await tester.tapAt(
                Offset(rect.left + rect.width * .7, rect.center.dy),
              );
              await tester.pumpAndSettle();
            },
            () => expect(
              tester.widget<Slider>(slider).value,
              greaterThan(tester.widget<Slider>(slider).min),
            ),
          );
        }
        await click(tester, 'Use layer');
        await click(tester, 'Add Sticker');
        await choose(tester, 'Sticker', 'Heart');
        await click(tester, 'Use layer');
        await click(tester, 'Add Drawing');
        final pad = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label?.startsWith('Drawing pad') == true,
        );
        await tester.ensureVisible(pad);
        await tester.pumpAndSettle();
        await tester.drag(pad, const Offset(40, 25));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await click(tester, 'Clear drawing');
        await click(tester, 'Add straight line');
        await click(tester, 'Use layer');
        await tester.ensureVisible(find.byTooltip('Move layer forward').first);
        await tester.tap(find.byTooltip('Move layer forward').first);
        await tester.pumpAndSettle();
        await click(tester, 'Use layers');
        expect(output!.map((v) => v['kind']), ['sticker', 'text', 'drawing']);
        final text = output![1];
        expect(text['startMs'], 1000);
        expect(text['endMs'], 8000);
        expect(text['text'], 'Tiếng Việt 日本語 👩🏽‍💻');
        expect(text['rotation'], isNot(0));
        expect(output!.first['sticker'], 'heart');
        expect(output!.last['points'], isNotEmpty);
        await tester.tap(find.text('Open QA dialog'));
        await tester.pumpAndSettle();
        await click(tester, 'Add Text');
        await field(tester, 'Layer text', 'Temporary layer');
        await click(tester, 'Use layer');
        await tester.tap(find.byTooltip('Delete layer 1'));
        await tester.pumpAndSettle();
        expect(find.text('1. Text'), findsNothing);
        await click(tester, 'Cancel');
      } finally {
        await tester.pumpWidget(const SizedBox());
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'subtitle actual add select update split merge invalid overlap delete cancel',
    (tester) async {
      final semantics = tester.ensureSemantics();
      SubtitleTrack? output;
      try {
        await open(
          tester,
          (context) async => output = await editSubtitles(
            context,
            SubtitleTrack([], durationMs: 10000),
          ),
        );
        await field(tester, 'Subtitle text', 'Xin chào thế giới 🌏');
        await field(tester, 'Start (seconds)', '0');
        await field(tester, 'End (seconds)', '4');
        await click(tester, 'Add subtitle');
        await click(tester, 'Xin chào thế giới 🌏');
        await click(tester, 'Split');
        expect(find.byTooltip('Delete subtitle'), findsNWidgets(2));
        final firstCue = find.byType(ListTile).first;
        await tester.ensureVisible(firstCue);
        await tester.tap(firstCue);
        await tester.pumpAndSettle();
        await click(tester, 'Merge next');
        await click(tester, 'Apply subtitles');
        expect(output!.cues.single.text, 'Xin chào thế giới 🌏');
        expect(output!.cues.single.startMs, 0);
        expect(output!.cues.single.endMs, 4000);
        expect(output!.toSrt(), contains('00:00:00,000 --> 00:00:04,000'));
        await tester.tap(find.text('Open QA dialog'));
        await tester.pumpAndSettle();
        await field(tester, 'Subtitle text', 'Invalid time');
        await field(tester, 'End (seconds)', '-1');
        await click(tester, 'Add subtitle');
        expect(
          find.text('Enter valid times within the video.'),
          findsOneWidget,
        );
        await field(tester, 'End (seconds)', '2');
        await click(tester, 'Add subtitle');
        await click(tester, 'Invalid time');
        await field(tester, 'Subtitle text', 'Updated cue');
        await click(tester, 'Update subtitle');
        expect(find.text('Updated cue'), findsOneWidget);
        await field(tester, 'Subtitle text', 'Overlapping');
        await click(tester, 'Add subtitle');
        expect(find.byType(ListTile), findsOneWidget);
        await tester.ensureVisible(find.byTooltip('Delete subtitle'));
        await tester.tap(find.byTooltip('Delete subtitle'));
        await tester.pumpAndSettle();
        expect(find.byType(ListTile), findsNothing);
        await click(tester, 'Cancel');
        probe.actions.add({
          'id': 'G3-SUBTITLE-ROUNDTRIP',
          'route': 'subtitles',
          'locator': 'fields/Add/Select/Split/Merge/Apply',
          'expected': 'Unicode text and full timing survive split merge',
          'actual': 'Assertions passed',
          'owner': 'P3',
          'modality': probe.modality,
          'status': 'PASS',
        });
      } finally {
        await tester.pumpWidget(const SizedBox());
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'effects dropdowns commit selected values and retime timed overlays',
    (tester) async {
      final semantics = tester.ensureSemantics();
      Map<String, Object>? output;
      try {
        await open(
          tester,
          (context) async => output = await editProjectEffects(context, {
            'subtitles': [
              SubtitleCue(
                startMs: 0,
                endMs: 8000,
                text: 'Timed subtitle',
              ).toJson(),
            ],
            'layers': [
              {
                'kind': 'text',
                'text': 'Timed layer',
                'startMs': 2000,
                'endMs': 8000,
              },
            ],
          }, durationMs: 10000),
        );
        for (final row in [
          ('Playback speed (audio pitch also changes)', '2', 'speed', 2.0),
          ('Original audio gain (0 mutes)', '0.5', 'volume', .5),
          ('Audio pitch (applies to all clip audio)', '1.25', 'pitch', 1.25),
          ('Original audio voice effect', 'Robot voice', 'voice', 'robot'),
          ('Original audio fade in (milliseconds)', '250', 'fadeInMs', 250),
          ('Original audio fade out (milliseconds)', '500', 'fadeOutMs', 500),
          ('Output height / compression', '480', 'height', 480),
          ('Target output FPS (variable)', '24', 'fps', 24),
          (
            'Target video bitrate (bits/s; 0 = automatic)',
            '1,000,000',
            'bitrate',
            1000000,
          ),
          ('Color filter', 'Invert colors', 'filter', 'invert'),
          ('Subtitle color', 'Yellow', 'subtitleColor', 'yellow'),
          ('Subtitle text size', 'Large', 'subtitleSize', 'large'),
          ('Subtitle background', 'None', 'subtitleBackground', 'none'),
          ('Subtitle position', 'Top', 'subtitlePosition', 'top'),
          ('Export format', 'gif', 'format', 'gif'),
          ('GIF frames per second', '5', 'gifFps', 5),
          ('GIF longest edge (pixels)', '160', 'gifEdge', 160),
          ('GIF repeat count (0 = forever)', '2', 'gifRepeats', 2),
        ]) {
          await step(
            tester,
            'G3-EFFECT-${row.$3}',
            row.$1,
            () => choose(tester, row.$1, row.$2),
            () {},
          );
        }
        await click(tester, 'Apply to project');
        expect(output!['speed'], 2.0);
        expect(output!['volume'], .5);
        expect(output!['pitch'], 1.25);
        expect(output!['voice'], 'robot');
        expect(output!['format'], 'gif');
        expect(output!['gifRepeats'], 2);
        expect((output!['layers'] as List).single['startMs'], 1000);
        expect((output!['subtitles'] as List).single['endMs'], 4000);
      } finally {
        await tester.pumpWidget(const SizedBox());
        semantics.dispose();
      }
    },
  );
}
