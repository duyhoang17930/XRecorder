import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/persistence/settings_store.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/recording/recording_service.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';

import '../test/fixtures/visual_catalog.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Current studio themes, navigation and screenshots on Android', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var captureValue = <String, Object?>{'id': '', 'state': 'idle'};
    late MockStreamHandlerEventSink captureSink;
    final emptyProject = EditProject(
      id: 'visual-fixture',
      title: 'Untitled project',
      clips: [],
      updatedAt: DateTime(2026, 11, 5),
    );
    messenger.setMockMethodCallHandler(
      AndroidEditProjectRepository.channel,
      (call) async => switch (call.method) {
        'list' => <Object?>[],
        'find' => jsonEncode(emptyProject.toJson()),
        _ => null,
      },
    );
    messenger.setMockMethodCallHandler(AndroidRecordingService.commands, (
      call,
    ) async {
      if (call.method == 'current') return captureValue;
      if (call.method == 'capabilities') {
        return {
          'presets': [
            {'width': 1920, 'height': 1080, 'fps': 60, 'codec': 'avc'},
          ],
          'audioSources': ['mute', 'microphone', 'internal', 'mixed'],
          'facecam': true,
        };
      }
      throw StateError(
        'Visual verification must never invoke capture: ${call.method}',
      );
    });
    messenger.setMockStreamHandler(
      AndroidRecordingService.events,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          captureSink = sink;
        },
      ),
    );

    final settings = SettingsController();
    final image = await fixtureImage();
    await tester.pumpWidget(
      XRecorderApp(settings: settings, mediaRepository: VisualCatalog(image)),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.text('Video Library')));
    await precacheImage(
      MemoryImage(image),
      tester.element(find.text('Video Library')),
    );
    await tester.pumpAndSettle();
    void top() => tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await binding.watchPerformance(() async {
      for (var i = 0; i < 6; i++) {
        await tester.timedDrag(
          find.byType(Scrollable).first,
          const Offset(0, -350),
          const Duration(milliseconds: 350),
        );
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 6; i++) {
        await tester.timedDrag(
          find.byType(Scrollable).first,
          const Offset(0, 350),
          const Duration(milliseconds: 350),
        );
        await tester.pumpAndSettle();
      }
    }, reportKey: 'emulator_library_scroll');
    top();
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    Future<void> shot(String name) async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await binding.takeScreenshot(name);
    }

    await shot('01_dark_home');
    await tester.scrollUntilVisible(
      find.text('Recent videos'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await shot('02_dark_library');
    await tester.tap(find.byTooltip('Create'));
    await tester.pumpAndSettle();
    await shot('03_dark_create');
    await tester.scrollUntilVisible(
      find.text('AI subtitles'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    tester
        .state<ScrollableState>(find.byType(Scrollable).last)
        .position
        .jumpTo(
          tester
              .state<ScrollableState>(find.byType(Scrollable).last)
              .position
              .maxScrollExtent,
        );
    await tester.pumpAndSettle();
    await shot('04_unavailable_tools');
    await tester.ensureVisible(find.byTooltip('Close create menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close create menu'));
    await tester.pumpAndSettle();
    router.go('/settings');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Light'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.light);
    top();
    await tester.pumpAndSettle();
    await shot('05_light_settings');
    router.go('/videos');
    await tester.pumpAndSettle();
    top();
    await tester.pumpAndSettle();
    await shot('06_light_home');
    await tester.tap(find.byTooltip('Create'));
    await tester.pumpAndSettle();
    await shot('07_light_create');
    await tester.tap(find.byTooltip('Close create menu'));
    await tester.pumpAndSettle();
    router.go('/photos');
    await tester.pumpAndSettle();
    await shot('08_photo_empty');
    router.go('/editor');
    await tester.pumpAndSettle();
    await shot('09_editing_hub');
    router.push('/editor/project/visual-fixture');
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Add your first clip'))).brightness,
      Brightness.light,
    );
    await shot('10_editor_dark_workspace');
    router.go('/settings');
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await tester.pumpAndSettle();
    top();
    await tester.pumpAndSettle();
    await shot('11_large_text_settings');
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.pumpAndSettle();
    router.go('/videos');
    await tester.pumpAndSettle();
    top();
    for (final sample in const [
      (RecordingState.recording, '12_recording_dark', 'Recording'),
      (RecordingState.paused, '13_paused_dark', 'Paused'),
      (RecordingState.finalizing, '14_processing_dark', 'Processing'),
      (RecordingState.completed, '15_saved_light', 'Saved'),
      (RecordingState.failed, '16_error_large_text', 'Error'),
    ]) {
      settings.setThemeMode(
        sample.$1 == RecordingState.completed ||
                sample.$1 == RecordingState.failed
            ? ThemeMode.light
            : ThemeMode.dark,
      );
      if (sample.$1 == RecordingState.failed) {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
      }
      captureValue = {
        'id': 'ui-state-fixture',
        'state': sample.$1.name,
        'elapsedMs': 42000,
        if (sample.$1 == RecordingState.completed)
          'outputUri': 'content://ui-fixture/saved',
        if (sample.$1 == RecordingState.failed)
          'error': 'Could not save this recording. Check available storage.',
      };
      captureSink.success(captureValue);
      await tester.pumpAndSettle();
      expect(find.text(sample.$3), findsWidgets);
      await shot(sample.$2);
    }
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    binding.reportData!['verification'] = {
      'fixture':
          'test-only generated video thumbnails; no capture or draft mutation',
      'physicalViewport': {
        'width': tester.view.physicalSize.width,
        'height': tester.view.physicalSize.height,
      },
      'logicalViewport': {
        'width': tester.view.physicalSize.width / tester.view.devicePixelRatio,
        'height':
            tester.view.physicalSize.height / tester.view.devicePixelRatio,
      },
      'devicePixelRatio': tester.view.devicePixelRatio,
      'performanceMode': 'emulator profile; physical hardware not available',
    };
    await tester.pumpWidget(const SizedBox.shrink());
    messenger.setMockMethodCallHandler(
      AndroidEditProjectRepository.channel,
      null,
    );
    messenger.setMockMethodCallHandler(AndroidRecordingService.commands, null);
    messenger.setMockStreamHandler(AndroidRecordingService.events, null);
  });

  testWidgets(
    'Appearance modes persist through the actual Android settings adapter',
    (tester) async {
      const store = AndroidSettingsStore();
      final original = await store.read();
      try {
        for (final mode in ThemeMode.values) {
          final first = SettingsController(store: store);
          await first.restore();
          final capture = first.recordingSnapshot;
          first.setThemeMode(mode);
          await first.flushed;
          expect(first.persistenceError, isNull);
          first.dispose();
          final restored = SettingsController(store: store);
          await restored.restore();
          expect(restored.themeMode, mode);
          expect(
            (
              restored.recordingSnapshot.width,
              restored.recordingSnapshot.fps,
              restored.recordingSnapshot.audioSource,
            ),
            (capture.width, capture.fps, capture.audioSource),
          );
          restored.dispose();
        }
      } finally {
        await store.write(original ?? '{"version":2,"values":{}}');
      }
      expect(await store.read(), original ?? '{"version":2,"values":{}}');
      binding.reportData!['nativeAppearancePersistence'] = {
        'modes': ['system', 'light', 'dark'],
        'restoredExpectedDocument': true,
        'restoreUsedEmptyFallback': original == null,
      };
    },
  );
}
