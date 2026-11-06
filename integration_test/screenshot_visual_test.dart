import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/features/recording/recording_service.dart';
import 'package:xrecorder/features/recording/recording_setup_sheet.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';

import '../test/fixtures/catalog.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Screenshot UI and visual hierarchy, synthetic states only', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(AndroidRecordingService.commands, (
      call,
    ) async {
      if (call.method == 'capabilities') {
        return {
          'presets': [],
          'audioSources': ['mute'],
          'hevc': false,
        };
      }
      return {'id': '', 'state': 'idle'};
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.xrecorder/capture/events'),
      (_) async => null,
    );
    final settings = SettingsController()..setThemeMode(ThemeMode.light);
    await tester.pumpWidget(
      XRecorderApp(
        settings: settings,
        mediaRepository: TestCatalog()..items.clear(),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.text('Video Library')));
    await binding.convertFlutterSurfaceToImage();
    Future<void> shot(String name) async {
      await tester.pumpAndSettle();
      await binding.takeScreenshot(name);
    }

    Future<void> state(String value) async {
      binding.channelBuffers.push(
        AndroidRecordingService.events.name,
        const StandardMethodCodec().encodeSuccessEnvelope({
          'id': 'task022-visual',
          'state': value,
          'screenshot': true,
          'countdownRemaining': 3,
          if (value == 'completed')
            'outputUri': 'content://test/screenshot.png',
        }),
        (_) {},
      );
      await tester.pumpAndSettle();
    }

    await shot('01_home_light');
    await state('awaitingPermission');
    await shot('02_permission_pending');
    await state('countdown');
    await shot('03_countdown');
    await state('finalizing');
    await shot('04_saving');
    if (const bool.fromEnvironment('TASK022_AFTER')) {
      expect(find.text('Stop'), findsNothing);
      expect(find.text('Processing'), findsNothing);
    }
    await state('completed');
    await shot('05_saved_light');
    settings.setThemeMode(ThemeMode.dark);
    await shot('06_saved_dark');
    if (const bool.fromEnvironment('TASK022_AFTER')) {
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Screenshot saved'), findsNothing);
    }
    CaptureScope.of(tester.element(find.text('Video Library'))).dismiss();
    settings.setThemeMode(ThemeMode.light);
    await tester.pumpAndSettle();
    openRecordingSetup(tester.element(find.text('Video Library')));
    await shot('07_recording_settings');
    await tester.tap(find.byTooltip('Close setup'));
    await tester.pumpAndSettle();
    router.go('/photos');
    await shot('08_photos_empty');
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    await shot('09_photos_large_text');
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    binding.reportData ??= {};
    binding.reportData!['fixture'] = 'Synthetic capture events and empty catalog only. No capture, output, or persisted settings.';
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
