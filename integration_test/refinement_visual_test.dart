import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/recording/recording_service.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';
import 'package:xrecorder/core/widgets/studio_widgets.dart';

import '../test/fixtures/visual_catalog.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Task 02.1 before/after screens with synthetic test-only data', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final project = EditProject(
      id: 'ui-refinement',
      clips: [],
      updatedAt: DateTime(2026),
    );
    messenger.setMockMethodCallHandler(
      AndroidEditProjectRepository.channel,
      (call) async => switch (call.method) {
        'list' => <Object?>[],
        'find' => jsonEncode(project.toJson()),
        _ => null,
      },
    );
    messenger.setMockMethodCallHandler(
      AndroidRecordingService.commands,
      (call) async =>
          call.method == 'current' ? {'id': '', 'state': 'idle'} : null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.xrecorder/capture/events'),
      (_) async => null,
    );
    final settings = SettingsController()..setThemeMode(ThemeMode.light);
    await tester.pumpWidget(
      XRecorderApp(
        settings: settings,
        mediaRepository: VisualCatalog(await fixtureImage()),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.text('Video Library')));
    await binding.convertFlutterSurfaceToImage();
    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await binding.takeScreenshot(name);
    }

    await shot('01_home');
    router.go('/editor');
    await tester.pumpAndSettle();
    await tester.tap(find.text('New video project'));
    await shot('02_editor_light');
    if (const bool.fromEnvironment('TASK021_AFTER')) {
      expect(
        Theme.of(tester.element(find.text('Add your first clip'))).brightness,
        Brightness.light,
      );
      settings.setThemeMode(ThemeMode.dark);
      await shot('07_editor_dark');
      settings.setThemeMode(ThemeMode.system);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await shot('08_editor_system_light');
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      settings.setThemeMode(ThemeMode.light);
    }
    await tester.tap(find.byTooltip('Back'));
    await shot('03_editing_return');
    if (const bool.fromEnvironment('TASK021_AFTER')) {
      expect(find.textContaining('setState()'), findsNothing);
    }
    ScaffoldMessenger.of(tester.element(find.text('Editing Studio')))
        .clearSnackBars();
    router.go('/help');
    await tester.pumpAndSettle();
    await tester.tap(find.text('How do I record my screen?'));
    await shot('04_help');
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await shot('05_help_large_text');
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    router.go('/videos');
    settings.setThemeMode(ThemeMode.dark);
    await shot('06_home_dark');
    if (const bool.fromEnvironment('TASK021_AFTER')) {
      showFailure(
        tester.element(find.text('Video Library')),
        PlatformException(
          code: 'io',
          message: 'InternalDatabaseException secret_method',
        ),
        operation: UserOperation.createDraft,
      );
      await shot('09_friendly_notice');
      expect(find.textContaining('InternalDatabaseException'), findsNothing);
    }
    binding.reportData ??= {};
    binding.reportData!['fixture'] = 'UI-only generated catalog; capture commands mocked; no user data or draft persisted';
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
