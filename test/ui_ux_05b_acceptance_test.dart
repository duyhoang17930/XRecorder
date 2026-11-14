import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/app/theme/app_theme.dart';
import 'package:xrecorder/core/ui/components/bottom_sheets/studio_bottom_sheet.dart';
import 'package:xrecorder/core/ui/components/bottom_sheets/studio_sheet_launch.dart';
import 'package:xrecorder/core/ui/components/cards/studio_cards.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/recording/recording_service.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';
import 'package:xrecorder/l10n/localization.dart';

import 'fixtures/catalog.dart';
import 'settings_persistence_test.dart' show MemoryStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    messenger.setMockMethodCallHandler(
      AndroidRecordingService.commands,
      (call) async => switch (call.method) {
        'current' => {'id': '', 'state': 'idle'},
        'capabilities' => {
          'audioSources': ['mute', 'microphone', 'internal', 'mixed'],
          'presets': [
            {'width': 1080, 'height': 1920, 'fps': 60, 'codec': 'avc'},
          ],
        },
        _ => null,
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.xrecorder/capture/events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      AndroidEditProjectRepository.channel,
      (call) async => call.method == 'list'
          ? <Object>[]
          : call.method == 'exportList'
          ? '[]'
          : null,
    );
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(AndroidRecordingService.commands, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.xrecorder/capture/events'),
      null,
    );
    messenger.setMockMethodCallHandler(
      AndroidEditProjectRepository.channel,
      null,
    );
  });

  testWidgets(
    'one recording entry opens existing P1 form and Back preserves preferences',
    (tester) async {
      tester.view.physicalSize = const Size(411, 920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryStore()
        ..document = jsonEncode({
          'version': 2,
          'values': {
            'resolution': '1080p FHD',
            'fps': '60',
            'codec': 'H.264 / AVC',
            'audio': 'Microphone',
            'countdown': '5s',
            'facecam': true,
            'themeMode': 'dark',
          },
        });
      final settings = SettingsController(store: store);
      await settings.restore();
      final before = store.document;
      await tester.pumpWidget(
        XRecorderApp(settings: settings, mediaRepository: TestCatalog()),
      );
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.text('Video Library')));
      for (final route in ['/videos', '/photos', '/editor', '/settings']) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(find.byType(StudioRootHeader), findsOneWidget);
        expect(find.text('3HRECORDER'), findsOneWidget);
      }
      expect(find.text('Recording settings'), findsOneWidget);
      expect(find.text('Video quality'), findsNothing);
      expect(find.text('Audio, countdown & facecam'), findsNothing);
      final target = tester.getRect(find.text('Recording settings'));
      expect(target.top, greaterThan(0));
      await tester.tap(find.text('Recording settings'));
      await tester.pumpAndSettle();
      expect(
        GoRouterState.of(tester.element(find.text('Recording settings')))
            .uri
            .path,
        '/settings/audio-video',
      );
      expect(
        find.text('Recording settings'),
        findsOneWidget,
      ); // Localized title; P1 route and preference-preservation contract kept.
      expect(find.byType(StudioRootHeader), findsNothing);
      router.pop();
      await tester.pumpAndSettle();
      await settings.flushed;
      expect(store.document, before);
      expect(settings.countdown, '5s');
      expect(settings.facecam, isTrue);
      expect(settings.audio, 'Microphone');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Vietnamese sort uses context and keeps every existing option', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = SettingsController()..setAppLocale(const Locale('vi'));
    await tester.pumpWidget(
      XRecorderApp(settings: settings, mediaRepository: TestCatalog()),
    );
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.byTooltip('Sắp xếp')),
      alignment: .3,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sắp xếp'));
    await tester.pumpAndSettle();
    for (final option in [
      'Sắp xếp',
      'Mới nhất',
      'Cũ nhất',
      'Tên',
      'Dung lượng lớn nhất',
      'Thời lượng dài nhất',
    ]) {
      expect(find.text(option), findsAtLeastNWidgets(1));
    }
    expect(find.text('Các phương tiện truyền thông'), findsNothing);
    await tester.tap(find.text('Cũ nhất'));
    await tester.pumpAndSettle();
    expect(find.text('Cũ nhất'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final tag in ['fr', 'de', 'ar', 'ja']) {
    testWidgets('long and RTL photo sort controls fit 320dp text200: $tag', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 920);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final settings = SettingsController()..setAppLocale(Locale(tag));
      await tester.pumpWidget(
        XRecorderApp(settings: settings, mediaRepository: TestCatalog()),
      );
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(StudioRootHeader)));
      router.go('/photos');
      await tester.pumpAndSettle();
      final strings = tester.element(find.byType(StudioRootHeader)).l10n;
      await Scrollable.ensureVisible(
        tester.element(find.byTooltip(strings.sortMedia)),
        alignment: .2,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(strings.sortMedia));
      await tester.pumpAndSettle();
      expect(find.text(strings.sortMedia), findsOneWidget);
      for (final label in [
        strings.newest,
        strings.oldest,
        strings.name,
        strings.largest,
      ]) {
        await Scrollable.ensureVisible(
          tester.element(find.text(label).last),
          alignment: .3,
        );
        await tester.pumpAndSettle();
        final bounds = tester.getRect(find.text(label).last);
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(320));
        expect(bounds.bottom, lessThanOrEqualTo(920));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final width in [320.0, 360.0, 393.0, 411.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets(
          'root headers width=$width scale=$scale dark=$dark in LTR/RTL and landscape',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPhysicalSize);
            for (final locale in [
              const Locale('vi'),
              const Locale('de'),
              const Locale('ar'),
            ]) {
              for (final size in [Size(width, 780), Size(780, width)]) {
                tester.view.physicalSize = size;
                await tester.pumpWidget(
                  MaterialApp(
                    locale: locale,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    theme: dark ? AppTheme.dark : AppTheme.light,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: Scaffold(
                      body: Builder(
                        builder: (context) => SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              StudioRootHeader(
                                context.l10n.videoLibrary,
                                trailing: const SizedBox(width: 96, height: 48),
                              ),
                              StudioRootHeader(
                                context.l10n.photoLibrary,
                                trailing: const SizedBox(width: 96, height: 48),
                              ),
                              StudioRootHeader(context.l10n.editingStudio),
                              StudioRootHeader(context.l10n.settings),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                expect(find.text('3HRECORDER'), findsNWidgets(4));
                final headers = tester
                    .getTopLeft(find.text('3HRECORDER').first)
                    .dx;
                for (final brand in find.text('3HRECORDER').evaluate()) {
                  expect(
                    tester
                        .getTopLeft(
                          find.byElementPredicate((e) => identical(e, brand)),
                        )
                        .dx,
                    headers,
                  );
                }
                expect(tester.takeException(), isNull);
              }
            }
          },
        );
      }
    }
  }

  for (final width in [411.0, 800.0]) {
    for (final taps in [2, 3, 5]) {
      for (final reduced in [false, true]) {
        testWidgets(
          'opening tap burst=$taps reduced=$reduced width=$width cannot activate sheet or scrim',
          (tester) async {
            tester.view.physicalSize = Size(width, 920);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            var opened = 0, activated = 0, other = 0;
            late BuildContext origin;
            await tester.pumpWidget(
              MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: reduced),
                  child: child!,
                ),
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.bottomRight,
                    child: Builder(
                      builder: (context) {
                        origin = context;
                        return SizedBox(
                          width: 52,
                          height: 52,
                          child: FilledButton(
                            onPressed: () => runStudioSheetLaunch(context, () {
                              opened++;
                              showStudioBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => SizedBox(
                                  height: 500,
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        left: 0,
                                        top: 0,
                                        child: TextButton(
                                          onPressed: () => other++,
                                          child: const Text('Other action'),
                                        ),
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: SizedBox(
                                          width: 52,
                                          height: 52,
                                          child: TextButton(
                                            onPressed: () => activated++,
                                            child: const Text('Risk'),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            child: const Text('+'),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
            final point = tester.getCenter(find.text('+'));
            await tester.tapAt(point);
            await tester.pump();
            for (var i = 1; i < taps; i++) {
              await tester.pump(const Duration(milliseconds: 80));
              await tester.tapAt(point);
            }
            await tester.pump();
            expect(opened, 1);
            expect(activated, 0);
            // Another location is immediately usable, even during the quiet period.
            if (reduced) {
              await tester.tap(find.text('Other action'));
              expect(other, 1);
            }
            await tester.pumpAndSettle();
            await tester.pump(const Duration(milliseconds: 310));
            expect(
              tester.getRect(find.text('Risk')).inflate(16).contains(point),
              width == 411,
            );
            await tester.tapAt(point);
            await tester.pumpAndSettle();
            if (width == 411) {
              expect(activated, 1);
              Navigator.of(origin, rootNavigator: true).pop();
            } else {
              // The same location is outside the centered sheet on a wide view.
              // It must dismiss normally after the burst, never during it.
              expect(find.text('Risk'), findsNothing);
              expect(activated, 0);
              expect(opened, 1);
            }
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
