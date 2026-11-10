import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/editor/editor_preview.dart';

class _Preview extends EditorPreview {
  const _Preview({required super.project}) : super(onPosition: position);

  static void position(Duration value) {}

  @override
  EditorPreviewState createState() => _PreviewState();
}

class _PreviewState extends EditorPreviewState {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  testWidgets(
    'viewport resize leaves playback and composition to the native surface',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(411, 920);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const channel = MethodChannel('ui04-preview-viewport');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final project = EditProject(
        id: 'viewport',
        updatedAt: DateTime(2026),
        clips: [
          TimelineClip(
            mediaId: 'content://qa/video',
            inPoint: Duration.zero,
            outPoint: const Duration(seconds: 4),
            sourceDuration: const Duration(seconds: 4),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp(home: _Preview(project: project)));
      final state = tester.state<EditorPreviewState>(find.byType(_Preview));
      state.channel = channel;
      await state.command('seek', 1234);
      calls.clear();
      tester.view.physicalSize = const Size(920, 411);
      await tester.pumpAndSettle();
      expect(calls, isEmpty, reason: 'Surface resize must not reload or seek');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      tester.view.resetViewInsets();
      state.playing = true;
      tester.view.physicalSize = const Size(411, 920);
      await tester.pumpAndSettle();
      expect(calls, isEmpty, reason: 'Do not interrupt running playback');
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'rapid effect updates serialize loads and keep the newest document',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('task09-preview-load-queue');
      final firstLoad = Completer<void>();
      final volumes = <double>[];
      var active = false;
      var overlaps = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'load') {
          if (active) {
            overlaps++;
            // Mirrors the real native EditorPreview.loading guard.
            throw PlatformException(
              code: 'editor_preview',
              message: 'Preview unavailable',
            );
          }
          active = true;
          final document = call.arguments as Map;
          volumes.add(
            ((document['effects'] as Map)['volume'] as num).toDouble(),
          );
          if (volumes.length == 1) await firstLoad.future;
          active = false;
        }
        return null;
      });
      var project = EditProject(
        id: 'load_queue',
        updatedAt: DateTime(2026),
        clips: [
          TimelineClip(
            mediaId: 'content://test/clip',
            inPoint: Duration.zero,
            outPoint: const Duration(seconds: 4),
            sourceDuration: const Duration(seconds: 4),
          ),
        ],
        effects: {'volume': 1.0, 'aspect': 1.0},
      );
      Future<void> mount() =>
          tester.pumpWidget(MaterialApp(home: _Preview(project: project)));
      try {
        await mount();
        final state = tester.state<EditorPreviewState>(find.byType(_Preview));
        state.channel = channel;
        final initial = state.load();
        await tester.pump();
        project = project.copyWith(effects: {'volume': .4, 'aspect': 1.0});
        await mount();
        project = project.copyWith(effects: {'volume': .2, 'aspect': 1.0});
        await mount();
        firstLoad.complete();
        await initial;
        await tester.pump();
        await tester.pump();
        expect(overlaps, 0);
        expect(volumes, [1.0, .2], reason: 'Skip the superseded pending edit.');
        expect(state.error, isNull);
      } finally {
        if (!firstLoad.isCompleted) firstLoad.complete();
        await tester.pumpWidget(const SizedBox());
        messenger.setMockMethodCallHandler(channel, null);
      }
    },
  );
}
