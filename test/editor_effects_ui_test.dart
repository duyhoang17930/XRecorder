import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:xrecorder/app/theme/app_theme.dart';
import 'package:xrecorder/features/editor/audio_tracks_editor.dart';
import 'package:xrecorder/features/editor/layers_editor.dart';
import 'package:xrecorder/features/editor/project_effects.dart';
import 'package:xrecorder/features/editor/transcription_dialog.dart';
import 'package:xrecorder/core/domain/models.dart';

void main() {
  for (final width in [320.0, 411.0]) {
    testWidgets('audio/layers/effects remain usable at $width and text200', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      Future<void> open(
        String label,
        Future<Object?> Function(BuildContext) dialog,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => dialog(context),
                  child: Text(label),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await open(
        'Audio',
        (context) => editAudioTracks(context, [
          {
            'uri': 'content://qa/audio',
            'sourceDurationMs': 4000,
            'inMs': 0,
            'outMs': 3000,
            'offsetMs': 500,
            'volume': .5,
          },
        ], 4000),
      );
      await tester.ensureVisible(find.text('Track 1'));
      await tester.tap(find.text('Track 1'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Use audio'));
      await tester.tap(find.text('Use audio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use tracks'));
      await tester.pumpAndSettle();
      await open(
        'Layers',
        (context) => editLayers(context, [
          {
            'kind': 'text',
            'text': 'Xin chào Việt Nam',
            'startMs': 0,
            'endMs': 4000,
          },
        ], 4000),
      );
      await tester.ensureVisible(find.text('1. text'));
      await tester.tap(find.text('1. text'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Use layer'));
      await tester.tap(find.text('Use layer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use layers'));
      await tester.pumpAndSettle();
      await open(
        'Effects',
        (context) => editProjectEffects(context, {}, durationMs: 4000),
      );
      await tester.ensureVisible(find.text('Apply to project'));
      await tester.tap(find.text('Apply to project'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      const channel = MethodChannel('com.xrecorder/editor');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => switch (call.method) {
              'transcriptionModels' => [
                {'id': 'tiny', 'installed': false, 'bytes': 77691713},
              ],
              'transcriptionJobs' => <Object>[],
              _ => null,
            },
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await open(
        'ASR',
        (context) => generateSubtitles(
          context,
          EditProject(
            id: 'ui_qa',
            updatedAt: DateTime(2026),
            clips: [
              TimelineClip(
                mediaId: 'content://qa/video',
                inPoint: Duration.zero,
                outPoint: const Duration(seconds: 4),
                sourceDuration: const Duration(seconds: 4),
              ),
            ],
          ),
        ),
      );
      expect(find.text('Download model'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
