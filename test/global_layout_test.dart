import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/app/theme/app_theme.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/widgets/studio_shell.dart';
import 'package:xrecorder/core/widgets/studio_widgets.dart';
import 'package:xrecorder/l10n/localization.dart';
import 'package:xrecorder/features/editor/audio_tracks_editor.dart';
import 'package:xrecorder/features/editor/layers_editor.dart';
import 'package:xrecorder/features/editor/project_effects.dart';
import 'package:xrecorder/features/editor/editing_hub_screen.dart';
import 'package:xrecorder/features/editor/export_screen.dart';
import 'package:xrecorder/features/media/media_library_screen.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/media/photo_tools_screen.dart';
import 'package:xrecorder/features/media/trash_screen.dart';
import 'package:xrecorder/features/editor/subtitle_editor.dart';
import 'package:xrecorder/features/editor/subtitles.dart';
import 'package:xrecorder/features/editor/transcription_dialog.dart';
import 'package:xrecorder/features/settings/app_language_dialog.dart';
import 'package:xrecorder/features/settings/help_screen.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';
import 'package:xrecorder/features/settings/settings_hub_screen.dart';
import 'package:xrecorder/l10n/app_languages.dart';

import 'fixtures/visual_catalog.dart';
import 'fixtures/recorder.dart';

import 'package:xrecorder/features/recording/recording_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const engine = MethodChannel('com.xrecorder/editor');
  setUp(
    () => messenger.setMockMethodCallHandler(
      engine,
      (call) async => switch (call.method) {
        'transcriptionModels' => [
          {'id': 'base', 'installed': true, 'bytes': 147951465},
        ],
        'transcriptionJobs' => <Object>[],
        'list' => <Object>[],
        'exportList' => '[{"id":"layout_failed","project":{"title":"Long project العربية हिन्दी 日本語"},"state":"failed","progress":45,"error":"Test fixture failure"}]',
        _ => null,
      },
    ),
  );
  tearDown(() => messenger.setMockMethodCallHandler(engine, null));
  testWidgets(
    'Arabic forward navigation and effect names follow the resolved locale',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                expect(context.effectValue('circle'), context.l10n.circle);
                return SettingsRow(
                  context.l10n.appLanguage,
                  icon: AppIcons.settings,
                  onTap: () {},
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(AppIcons.back), findsOneWidget);
    },
  );
  for (final locale in AppLanguages.supported) {
    for (final width in [320.0, 360.0, 411.0, 840.0]) {
      testWidgets(
        '${locale.toLanguageTag()} ${width}dp text${width == 360 ? 150 : 200} ${width == 320 ? 'dark' : 'light'}',
        (tester) async {
          tester.view.physicalSize = Size(width, width == 840 ? 411 : 900);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = width == 360
              ? 1.5
              : 2;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });
          final settings = SettingsController();
          addTearDown(settings.dispose);
          final image = (await tester.runAsync(fixtureImage))!;
          final catalog = VisualCatalog(image);
          addTearDown(catalog.dispose);
          final recorder = TestRecorder();
          addTearDown(recorder.events.close);
          final capture = CaptureController(recorder, onSaved: () {});
          addTearDown(capture.dispose);
          const media = MethodChannel('com.xrecorder/media');
          messenger.setMockMethodCallHandler(
            media,
            (call) async => switch (call.method) {
              'decodePhoto' => image,
              'listTrash' => <Object>[],
              _ => null,
            },
          );
          addTearDown(() => messenger.setMockMethodCallHandler(media, null));
          final navigator = GlobalKey<NavigatorState>();
          final theme = width == 320 ? AppTheme.dark : AppTheme.light;
          Widget host(Widget child) => MediaScope(
            repository: catalog,
            child: SettingsScope(
              controller: settings,
              child: CaptureScope(
                controller: capture,
                child: MaterialApp(
                  navigatorKey: navigator,
                  locale: locale,
                  theme: theme,
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  home: child,
                ),
              ),
            ),
          );
          await tester.pumpWidget(
            host(
              Scaffold(
                body: const SettingsHubScreen(),
                bottomNavigationBar: StudioBottomNavigation(
                  selected: 3,
                  onDestination: (_) {},
                  onCreate: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final scroll = find.byType(Scrollable).first;
          await tester.drag(scroll, const Offset(0, -600));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(host(const HelpScreen()));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final screen in [
            const Scaffold(body: MediaLibraryScreen(kind: MediaKind.video)),
            const Scaffold(body: MediaLibraryScreen(kind: MediaKind.image)),
            const Scaffold(body: EditingHubScreen()),
            const ExportScreen(),
            const TrashScreen(),
            const PhotoToolsScreen(uri: 'content://layout/photo'),
          ]) {
            await tester.pumpWidget(host(screen));
            if (screen is PhotoToolsScreen) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 80)),
              );
              await tester.pump();
            }
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason:
                  '${screen is Scaffold ? screen.body.runtimeType : screen.runtimeType}',
            );
          }

          Future<void> open(
            Future<Object?> Function(BuildContext) action,
          ) async {
            await tester.pumpWidget(
              host(
                Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => action(context),
                      child: const Text('QA_OPEN'),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('QA_OPEN'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            navigator.currentState!.pop();
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }

          await open(showAppLanguageDialog);
          await open(
            (context) => editProjectEffects(context, {}, durationMs: 4000),
          );
          await open((context) => editAudioTracks(context, [], 4000));
          await open((context) => editLayers(context, [], 4000));
          await open(
            (context) => editSubtitles(
              context,
              SubtitleTrack([
                SubtitleCue(
                  startMs: 0,
                  endMs: 1000,
                  text:
                      'العربية हिन्दी 日本語 👩🏽‍💻\n${List.filled(10, 'Long subtitle').join(' ')}',
                ),
              ], durationMs: 4000),
            ),
          );
          await open(
            (context) => generateSubtitles(
              context,
              EditProject(
                id: 'layout',
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
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
