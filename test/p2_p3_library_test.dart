import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/media/media_library_screen.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/recording/recording_service.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';

import 'fixtures/catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader('packages/lucide_flutter/LucideIcons')..addFont(
          rootBundle.load('packages/lucide_flutter/assets/lucide.ttf'),
        ))
        .load();
  });
  setUp(() {
    messenger.setMockMethodCallHandler(
      AndroidRecordingService.commands,
      (call) async => call.method == 'current'
          ? {'id': '', 'state': 'idle'}
          : {
              'presets': [],
              'audioSources': ['mute'],
            },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.xrecorder/capture/events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      AndroidEditProjectRepository.channel,
      (call) async => call.method == 'list' ? <Object?>[] : null,
    );
  });
  const phase = String.fromEnvironment('P2_P3_UI_PHASE');
  testWidgets('rename dialog locks synchronously and cancel permits retry', (
    tester,
  ) async {
    final catalog = TestCatalog()..items.clear();
    catalog.items.add(
      MediaItem(
        id: 'content://owned/1',
        uri: Uri.parse('content://owned/1'),
        kind: MediaKind.video,
        displayName: 'Owned.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 100,
        createdAt: DateTime(2026),
        modifiedAt: DateTime(2026),
        source: MediaSource.recording,
        owned: true,
      ),
    );
    await tester.pumpWidget(XRecorderApp(mediaRepository: catalog));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('Video Library')))
        .push('/media/${Uri.encodeComponent(catalog.items.single.id)}');
    await tester.pumpAndSettle();
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Rename'),
    );
    button.onPressed!();
    button.onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Rename media'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(TextButton, 'Rename'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Rename media'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
  testWidgets('1000 items stay lazy, search survives saved-event refresh', (
    tester,
  ) async {
    final catalog = TestCatalog()..items.clear();
    for (var i = 0; i < 1000; i++) {
      catalog.items.add(
        MediaItem(
          id: 'content://large/$i',
          uri: Uri.parse('content://large/$i'),
          kind: MediaKind.video,
          displayName: 'Video ${i.toString().padLeft(4, '0')}.mp4',
          mimeType: 'video/mp4',
          sizeBytes: 1000 + i,
          createdAt: DateTime(2026).add(Duration(seconds: i)),
          modifiedAt: DateTime(2026),
          source: MediaSource.recording,
        ),
      );
    }
    await tester.pumpWidget(XRecorderApp(mediaRepository: catalog));
    await tester.pumpAndSettle();
    expect(find.byType(MediaThumbnail).evaluate().length, lessThan(20));
    for (var i = 0; i < 20; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.byType(MediaThumbnail).evaluate().length, lessThan(20));
    }
    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0999');
    await tester.pumpAndSettle();
    catalog.refresh();
    await tester.pumpAndSettle();
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Video 0999.mp4'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Video 0999.mp4'), findsOneWidget);
    expect(find.text('Video 0998.mp4'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 411.0]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('empty library $width $theme text$scale', (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });
          final catalog = TestCatalog()..items.clear();
          await tester.pumpWidget(
            XRecorderApp(
              settings: SettingsController()..setThemeMode(theme),
              mediaRepository: catalog,
            ),
          );
          await tester.pumpAndSettle();
          final router = GoRouter.of(
            tester.element(find.text('Video Library')),
          );
          for (final tab in ['videos', 'photos', 'editor', 'settings']) {
            router.go('/$tab');
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (phase.isNotEmpty) {
              await expectLater(
                find.byType(MaterialApp),
                matchesGoldenFile(
                  '../build/verification/p2_p3/m1/$phase/${tab}_${width.toInt()}_${theme.name}_$scale.png',
                ),
              );
            }
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        });
      }
    }
  }
}
