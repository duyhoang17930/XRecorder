import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/widgets/studio_shell.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';
import 'package:xrecorder/l10n/app_languages.dart';
import 'package:xrecorder/l10n/localization.dart';
import 'package:xrecorder/features/editor/editor_preview.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/editor/subtitles.dart';

Future<void> _capture(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  if (const bool.fromEnvironment('G4_GLOBAL')) {
    debugPrint('TASK07_GLOBAL_SCREEN=$name');
    await Future<void>.delayed(const Duration(milliseconds: 1400));
  } else {
    await binding.takeScreenshot(name);
  }
}

Future<Map<String, Object>> _globalScreens(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
  SettingsController settings,
  GoRouter router,
) async {
  const engine = AndroidEditProjectRepository.channel;
  const media = AndroidMediaRepository.channel;
  const root = 'content://com.xrecorder.xrecorder.files/media/';
  final originals = (await engine.invokeListMethod<String>('list'))!;
  final originalJobs = (await engine.invokeListMethod<dynamic>(
    'transcriptionJobs',
  ))!;
  final legacyBoundary = const int.fromEnvironment('TASK07_START_MS');
  final legacyJobs = originalJobs
      .cast<Map>()
      .where(
        (v) =>
            (v['createdAt'] as num? ?? 0) < legacyBoundary &&
            ['vi', 'en'].contains(v['language']),
      )
      .toList();
  // Read and decode retained documents; never save/migrate/delete them here.
  var reopened = 0, oldTimedCues = 0;
  for (final document in originals) {
    try {
      final project = EditProject.fromJson(
        jsonDecode(document) as Map<String, dynamic>,
      );
      final restored = await AndroidEditProjectRepository().find(project.id);
      expect(restored?.toJson(), project.toJson());
      oldTimedCues += SubtitleTrack.decode(
        project.effects['subtitles'],
        project.duration.inMilliseconds,
      ).cues.length;
      reopened++;
    } on FormatException {
      /* Corrupt/future drafts remain retained and reported by the repository. */
    } on TypeError {
      /* No implicit repair or overwrite. */
    }
  }
  final project = EditProject(
    id: 'task07_locale_${DateTime.now().microsecondsSinceEpoch}',
    title: 'TASK07 العربية हिन्दी 日本語',
    updatedAt: DateTime.now(),
    clips: [
      TimelineClip(
        mediaId: '${root}task07_subtitle_input.mp4',
        inPoint: Duration.zero,
        outPoint: const Duration(seconds: 4),
        sourceDuration: const Duration(seconds: 4),
      ),
    ],
    effects: {
      'subtitles': [
        SubtitleCue(
          startMs: 100,
          endMs: 3900,
          text: 'العربية हिन्दी 日本語 👩🏽‍💻',
        ).toJson(),
      ],
    },
  );
  await AndroidEditProjectRepository().save(project);
  router.go('/editor/project/${project.id}');
  await tester.pumpAndSettle();
  for (
    var i = 0;
    i < 60 &&
        tester.state<EditorPreviewState>(find.byType(EditorPreview)).channel ==
            null;
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  final preview = tester.state<EditorPreviewState>(find.byType(EditorPreview));
  await preview.command('seek', 800);
  var rendered = false;
  for (var i = 0; i < 100; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
    final state = (await preview.channel!.invokeMapMethod<String, dynamic>(
      'state',
    ))!;
    expect(state['error'], isNull);
    rendered =
        state['playbackState'] == 3 && state['renderedFirstFrame'] == true;
    if (rendered) break;
  }
  expect(
    rendered,
    isTrue,
    reason: 'Locale screenshots must include actual rendered media.',
  );
  final diag = (await engine.invokeMapMethod<String, dynamic>(
    'editorDiagnostics',
  ))!;
  final screens = <String>[];
  for (final locale in AppLanguages.supported) {
    debugPrint('TASK07_EDITOR_LOCALE=${locale.toLanguageTag()}');
    settings.setAppLocale(locale);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 15),
    );
    expect(
      tester.state<EditorPreviewState>(find.byType(EditorPreview)),
      same(preview),
    );
    final current = (await engine.invokeMapMethod<String, dynamic>(
      'editorDiagnostics',
    ))!;
    expect(
      current['previewLoads'],
      diag['previewLoads'],
      reason: 'Locale must not reload native playback',
    );
    final state = (await preview.channel!.invokeMapMethod<String, dynamic>(
      'state',
    ))!;
    expect(state['positionMs'], closeTo(800, 100));
    final name =
        'g4_editor_${locale.toLanguageTag().toLowerCase().replaceAll('-', '_')}';
    await _capture(binding, name);
    screens.add(name);
    expect(tester.takeException(), isNull);
  }
  router.go('/settings');
  await tester.pumpAndSettle();
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  try {
    for (final locale in AppLanguages.supported) {
      settings.setAppLocale(locale);
      settings.setThemeMode(
        locale.languageCode == 'ar' || locale.languageCode == 'de'
            ? ThemeMode.light
            : ThemeMode.dark,
      );
      for (final route in [
        '/settings',
        '/videos',
        '/photos',
        '/editor',
        '/exports',
        '/help',
        '/photo-tools/${Uri.encodeComponent('${root}task07_subtitle_fresh.png')}',
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: '${locale.toLanguageTag()} $route',
        );
        final label = route.startsWith('/photo-tools/')
            ? 'photo_tools'
            : route == '/editor'
            ? 'drafts'
            : route.substring(1);
        final name =
            'g4_${label}_${locale.toLanguageTag().toLowerCase().replaceAll('-', '_')}';
        await _capture(binding, name);
        screens.add(name);
      }
      await media.invokeMethod<void>('setAppLocale', locale.toLanguageTag());
      final shortcuts = (await media.invokeMapMethod<String, dynamic>(
        'shortcutStatus',
      ))!;
      final labels = (shortcuts['labels'] as Map).cast<String, String>();
      router.go('/settings');
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(StudioBottomNavigation));
      if (labels.containsKey('pinned_edit_video')) {
        expect(labels['pinned_edit_video'], context.l10n.editVideo);
      }
      if (labels.containsKey('pinned_edit_photo')) {
        expect(labels['pinned_edit_photo'], context.l10n.editPhoto);
      }
    }
  } finally {
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  }
  final retained = (await engine.invokeListMethod<String>('list'))!;
  expect(retained.toSet().containsAll(originals), isTrue);
  final jobs = (await engine.invokeListMethod<dynamic>('transcriptionJobs'))!
      .cast<Map>();
  for (final old in originalJobs.cast<Map>()) {
    final now = jobs.firstWhere((v) => v['id'] == old['id']);
    expect(now['segments'], old['segments']);
    expect(now['language'], old['language']);
  }
  expect(
    screens.toSet().length,
    screens.length,
    reason: 'Every surface needs its own screenshot filename',
  );
  debugPrint('TASK07_ACCESSIBILITY_READY');
  if (const bool.fromEnvironment('G4_ACCESSIBILITY')) {
    settings.setAppLocale(const Locale('ar'));
    router.go('/settings');
    await tester.pumpAndSettle();
    await Future<void>.delayed(const Duration(seconds: 40));
  }
  return {
    'screens': screens,
    'existingDraftDocumentsPreserved': originals.length,
    'draftsReopened': reopened,
    'retainedTimedCues': oldTimedCues,
    'legacyViEnJobsPreserved': legacyJobs.length,
    'allExistingJobsPreserved': originalJobs.length,
    'preTask07JobsAvailable': legacyJobs.isNotEmpty,
    'editorPreviewStateAndPlayheadRetained': true,
    'trashNativeScreen': 'NOT RUN: opening existing trash can purge expired media; widget matrix covers layout safely.',
  };
}

class CountingNativeCatalog extends AndroidMediaRepository {
  int queries = 0;
  @override
  Future<List<MediaItem>> list({required MediaKind kind, Uri? folder}) {
    queries++;
    return super.list(kind: kind, folder: folder);
  }
}

void main() {
  debugPrint('TASK07_GLOBAL_ENTRY');
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  debugPrint('TASK07_GLOBAL_BINDING_READY');
  testWidgets('G1 native locale switching retains library and router state', (
    tester,
  ) async {
    final catalog = CountingNativeCatalog();
    final imagesBefore = (await catalog.list(kind: MediaKind.image))
        .map((item) => item.id)
        .toSet();
    final settings = SettingsController()..setAppLocale(const Locale('en'));
    await tester.pumpWidget(
      XRecorderApp(settings: settings, mediaRepository: catalog),
    );
    await tester.pumpAndSettle();
    final shell = tester.element(find.byType(StudioBottomNavigation));
    final router = GoRouter.of(shell);
    final videoState = tester.state(find.byType(Scrollable).first);
    router.go('/settings');
    await tester.pumpAndSettle();
    final queriesBeforeSwitch = catalog.queries;
    // Android's actual surface is captured by the host in the native-view
    // matrix. Do not convert FlutterView to an image before embedding PlayerView.
    if (!const bool.fromEnvironment('G4_GLOBAL')) {
      await binding.convertFlutterSurfaceToImage();
    }
    final results = <Map<String, Object>>[];
    for (final locale in AppLanguages.supported) {
      settings.setAppLocale(locale);
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(StudioBottomNavigation));
      final strings = context.l10n;
      expect(GoRouter.of(context), same(router));
      expect(find.text(strings.appLanguage), findsOneWidget);
      expect(
        Directionality.of(context),
        locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      await AndroidMediaRepository.channel.invokeMethod<void>(
        'setAppLocale',
        locale.toLanguageTag(),
      );
      expect(
        catalog.queries,
        queriesBeforeSwitch,
        reason: 'Locale alone must not reload media',
      );
      expect(tester.takeException(), isNull);
      await _capture(
        binding,
        'g1_settings_${locale.toLanguageTag().toLowerCase().replaceAll('-', '_')}',
      );
      results.add({
        'locale': locale.toLanguageTag(),
        'direction': Directionality.of(context).name,
        'catalogQueries': catalog.queries,
      });
    }
    Map<String, Object>? global;
    settings.setAppLocale(const Locale('en'));
    router.go('/videos');
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(Scrollable).first), same(videoState));
    if (const bool.fromEnvironment('G4_GLOBAL')) {
      global = await _globalScreens(tester, binding, settings, router);
    }
    await expectLater(
      AndroidMediaRepository.channel.invokeMethod<void>(
        'setAppLocale',
        'invalid-locale',
      ),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'invalid_locale',
        ),
      ),
    );
    settings.setAppLocale(const Locale('en'));
    router.go('/videos');
    await tester.pumpAndSettle();
    final imagesAfter = (await catalog.list(kind: MediaKind.image))
        .map((item) => item.id)
        .toSet();
    expect(imagesAfter, imagesBefore);
    settings.setAppLocale(null);
    await tester.pumpAndSettle();
    binding.reportData = {
      ...binding.reportData ?? {},
      'g1Locales': results,
      'imagesBefore': imagesBefore.length,
      'imagesAfter': imagesAfter.length,
      'mediaIdsUnchanged': true,
      'routerRetained': true,
      'libraryStateRetained': true,
      'translationHumanReview': 'PENDING',
      'g4': ?global,
    };
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }, timeout: const Timeout(Duration(minutes: 8)));
}
