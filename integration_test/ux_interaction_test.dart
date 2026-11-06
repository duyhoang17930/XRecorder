import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/editor/media_picker.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/media/photo_tools_screen.dart';
import 'package:xrecorder/features/recording/recording_service.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';

import '../test/fixtures/visual_catalog.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Task 03.1 synthetic UI evidence; no real media mutations', (
    tester,
  ) async {
    const after = bool.fromEnvironment('UX_AFTER');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final image = await fixtureImage();
    final pendingExport = Completer<String>();
    var exports = 0;
    final project = EditProject(
      id: 'ux-fixture',
      title: 'My recording project',
      updatedAt: DateTime(2026),
      clips: [
        TimelineClip(
          mediaId: 'content://ui-fixture/0',
          title: 'Studio fixture 01.mp4',
          inPoint: Duration.zero,
          outPoint: const Duration(seconds: 8),
          sourceDuration: const Duration(seconds: 8),
        ),
      ],
    );
    messenger.setMockMethodCallHandler(
      AndroidEditProjectRepository.channel,
      (call) async => switch (call.method) {
        'list' => <Object?>[],
        'find' => jsonEncode(project.toJson()),
        'exportList' => '[]',
        'exportStart' => () {
          exports++;
          return pendingExport.future;
        }(),
        _ => null,
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.xrecorder/media'),
      (call) async => switch (call.method) {
        'imageBytes' || 'thumbnailAt' => image,
        _ => null,
      },
    );
    messenger.setMockMethodCallHandler(
      AndroidRecordingService.commands,
      (call) async => switch (call.method) {
        'current' => {'id': '', 'state': 'idle'},
        'capabilities' => {
          'presets': [],
          'audioSources': ['mute'],
          'hevc': false,
        },
        _ => null,
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.xrecorder/capture/events'),
      (_) async => null,
    );
    final settings = SettingsController()..setThemeMode(ThemeMode.light);
    await tester.pumpWidget(
      XRecorderApp(settings: settings, mediaRepository: VisualCatalog(image)),
    );
    await tester.pumpAndSettle();
    final host = tester.element(find.text('Video Library'));
    final router = GoRouter.of(host);
    await binding.convertFlutterSurfaceToImage();
    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      await binding.takeScreenshot(name);
    }

    final results = <String, Object?>{'syntheticOnly': true, 'after': after};
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      settings.setThemeMode(mode);
      router.push('/editor/project/ux-fixture');
      await tester.pumpAndSettle();
      await shot('01_editor_${mode.name}');
      if (after) {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        await shot('07_editor_large_${mode.name}');
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.pumpAndSettle();
      }
      if (mode == ThemeMode.light) {
        // Invoke twice in the same event turn, before a disabled button can rebuild.
        final button = tester.widget<ButtonStyleButton>(
          find
              .ancestor(
                of: find.text('Export'),
                matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
              )
              .first,
        );
        button.onPressed!();
        button.onPressed!();
        await tester.pump(const Duration(milliseconds: 150));
        results['exportRequestsForDoubleTap'] = exports;
        if (after) expect(exports, 1);
        await shot('02_export_pending');
      }
      router.pop();
      await tester.pumpAndSettle();
    }
    settings.setThemeMode(ThemeMode.light);
    router.push('/photo-tools/fixture');
    await tester.pumpAndSettle();
    final canvas = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is PhotoPainter,
    );
    await tester.ensureVisible(canvas);
    await tester.drag(canvas, const Offset(40, 15));
    await shot('03_photo_edits');
    if (after) {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await shot('08_photo_large');
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    results['protectsUnsavedPhotoEdits'] = find
        .text('Discard photo edits?')
        .evaluate()
        .isNotEmpty;
    if (after) {
      expect(find.text('Discard photo edits?'), findsOneWidget);
      await shot('04_photo_leave');
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(canvas, findsOneWidget);
    }
    router.go('/videos');
    await tester.pumpAndSettle();
    final picker = pickEditorMedia(tester.element(find.text('Video Library')));
    await shot('05_picker_light');
    settings.setThemeMode(ThemeMode.dark);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await shot('06_picker_dark_large_text');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await picker;
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.pumpWidget(const SizedBox.shrink());
    pendingExport.complete('synthetic-export');
    await tester.pumpAndSettle();
    binding.reportData ??= {};
    binding.reportData!['ux031'] = results;
    expect(tester.takeException(), isNull);
  });
}
