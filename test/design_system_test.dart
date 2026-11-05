import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/app/theme/app_theme.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/persistence/settings_store.dart';
import 'package:xrecorder/core/widgets/studio_widgets.dart';
import 'package:xrecorder/core/widgets/studio_create_sheet.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/media/media_library_screen.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';

import 'fixtures/catalog.dart';

class AppearanceStore implements SettingsStore {
  String? document;
  @override
  Future<String?> read() async => document;
  @override
  Future<void> write(String value) async => document = value;
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          AndroidEditProjectRepository.channel,
          (call) async => switch (call.method) {
            'list' => <Object?>[],
            'find' => jsonEncode(
              EditProject(
                id: 'fixture',
                title: 'Untitled project',
                clips: [],
                updatedAt: DateTime(2026),
              ).toJson(),
            ),
            _ => null,
          },
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEditProjectRepository.channel, null);
  });

  test('semantic palette meets readable contrast in both modes', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
    }

    for (final c in [StudioColors.dark, StudioColors.light]) {
      for (final surface in [c.background, c.surface, c.card, c.elevated]) {
        for (final ink in [c.text, c.muted, c.primary, c.cyan, c.warning]) {
          expect(
            contrast(ink, surface),
            greaterThanOrEqualTo(4.5),
            reason: '$ink on $surface',
          );
        }
      }
      expect(
        contrast(c.primaryForeground, c.primary),
        greaterThanOrEqualTo(4.5),
      );
      expect(contrast(c.onRecording, c.recording), greaterThanOrEqualTo(4.5));
      expect(contrast(c.outline, c.surface), greaterThanOrEqualTo(3));
    }
    expect(
      StudioColors.dark.lerp(StudioColors.light, 1).text,
      StudioColors.light.text,
    );
    expect(AppTheme.dark.extension<StudioColors>(), StudioColors.dark);
    expect(AppTheme.light.extension<StudioColors>(), StudioColors.light);
  });

  test(
    'appearance persists without changing recording snapshot or schema',
    () async {
      final store = AppearanceStore();
      final first = SettingsController(store: store);
      var appearanceNotifications = 0;
      first.themeModeListenable.addListener(() => appearanceNotifications++);
      first.update(() => first.fps = '30');
      expect(appearanceNotifications, 0);
      final before = first.recordingSnapshot;
      first.setThemeMode(ThemeMode.light);
      first.setThemeMode(ThemeMode.light);
      await first.flushed;
      expect(appearanceNotifications, 1);
      final after = first.recordingSnapshot;
      expect(
        (
          after.width,
          after.height,
          after.fps,
          after.bitrate,
          after.audioSource,
          after.facecam,
        ),
        (
          before.width,
          before.height,
          before.fps,
          before.bitrate,
          before.audioSource,
          before.facecam,
        ),
      );
      expect(jsonDecode(store.document!)['version'], 2);
      final restored = SettingsController(store: store);
      await restored.restore();
      expect(restored.themeMode, ThemeMode.light);
      expect(restored.fps, '30');
      restored.reset();
      await restored.flushed;
      expect(restored.themeMode, ThemeMode.dark);
      first.dispose();
      restored.dispose();
    },
  );

  Future<SettingsController> start(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    ThemeMode mode = ThemeMode.dark,
    TestCatalog? catalog,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final settings = SettingsController()..setThemeMode(mode);
    await tester.pumpWidget(
      XRecorderApp(
        settings: settings,
        mediaRepository: catalog ?? TestCatalog(),
      ),
    );
    await tester.pumpAndSettle();
    return settings;
  }

  testWidgets('theme switching follows system and retains library state', (
    tester,
  ) async {
    final settings = await start(tester);
    expect(
      tester.getSize(find.byType(StudioRecordHero)).width,
      closeTo(390 - AppSpacing.md * 2, .1),
    );
    await tester.enterText(find.byType(TextField), 'Clip 0');
    settings.setThemeMode(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Video Library'))).brightness,
      Brightness.light,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Clip 0',
    );
    settings.setThemeMode(ThemeMode.system);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Video Library'))).brightness,
      Brightness.dark,
    );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Video Library'))).brightness,
      Brightness.light,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Create is an action and unavailable tools have no tap behavior',
    (tester) async {
      await start(tester);
      final router = GoRouter.of(tester.element(find.text('Video Library')));
      await tester.tap(find.byTooltip('Create'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/videos');
      expect(find.text('Screen recording'), findsOneWidget);
      for (final name in ['Recording region', 'Livestream', 'AI subtitles']) {
        expect(
          tester.widget<BentoCard>(find.widgetWithText(BentoCard, name)).onTap,
          isNull,
        );
      }
      await tester.tap(find.byTooltip('Close create menu'));
      await tester.pumpAndSettle();
      expect(find.text('Video Library'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large catalogs build only visible media rows', (tester) async {
    final catalog = TestCatalog();
    final sample = catalog.items.first;
    catalog.items.addAll(List.filled(1000, sample));
    await start(tester, catalog: catalog);
    expect(find.byType(MediaThumbnail).evaluate().length, lessThan(20));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.byType(MediaThumbnail).evaluate().length, lessThan(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion uses static loading and zero switch duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const Scaffold(
            body: Column(
              children: [
                StudioLoadingState(),
                StudioAnimatedSwitcher(child: Text('Ready')),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
      Duration.zero,
    );
  });

  for (final width in [320.0, 600.0, 1024.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final mode in [ThemeMode.dark, ThemeMode.light]) {
        testWidgets('routes fit width=$width scale=$scale theme=${mode.name}', (
          tester,
        ) async {
          await start(tester, size: Size(width, 900), scale: scale, mode: mode);
          final router = GoRouter.of(
            tester.element(find.text('Video Library')),
          );
          for (final path in [
            '/photos',
            '/editor',
            '/settings',
            '/settings/audio-video',
            '/editor/project/fixture',
          ]) {
            if (path.contains('/project/')) {
              router.push(path);
            } else {
              router.go(path);
            }
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: path);
          }
          expect(
            Theme.of(tester.element(find.text('Add your first clip')))
                .brightness,
            mode == ThemeMode.light ? Brightness.light : Brightness.dark,
          );
          router.go('/videos');
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Create'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'Create menu');
          await tester.tap(find.byTooltip('Close create menu'));
          await tester.pumpAndSettle();
        });
      }
    }
  }

  testWidgets('main controls meet Android touch and label guidelines', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      await start(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      handle.dispose();
    }
  });

  for (final theme in [AppTheme.dark, AppTheme.light]) {
    testWidgets(
      'dialog scrolls at 200 percent text in ${theme.brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showStudioDialog<void>(
                    context: context,
                    builder: (dialog) => StudioDialog(
                      title: const Text('Reset preferences?'),
                      content: const Text(
                        'Restore recording and appearance preferences to their defaults. Media and editor drafts are kept.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialog),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('Open dialog'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open dialog'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Open dialog'), findsOneWidget);
      },
    );
  }

  testWidgets('two quick tools fill the available tablet row', (tester) async {
    await start(tester, size: const Size(1024, 900));
    final tiles = find.byType(QuickActionTile);
    expect(tiles, findsNWidgets(2));
    final expected = (1024 - AppSpacing.md * 2 - AppSpacing.sm) / 2;
    expect(tester.getSize(tiles.first).width, closeTo(expected, .1));
    expect(tester.getSize(tiles.last).width, closeTo(expected, .1));
  });

  testWidgets(
    'concise settings disclose the complete storage and privacy information',
    (tester) async {
      await start(tester, size: const Size(320, 640));
      final router = GoRouter.of(tester.element(find.text('Video Library')));
      router.go('/settings');
      await tester.pumpAndSettle();
      for (final sample in [
        ('Media storage', 'Movies/XRecorder'),
        ('Privacy', 'Only explicit sharing'),
      ]) {
        await tester.scrollUntilVisible(
          find.text(sample.$1),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(sample.$1));
        await tester.pumpAndSettle();
        expect(find.textContaining(sample.$2), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
}
