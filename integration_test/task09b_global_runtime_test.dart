import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/main.dart' as app;
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/persistence/settings_store.dart';
import 'package:xrecorder/core/widgets/studio_shell.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/editor/transcription_dialog.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';
import 'package:xrecorder/l10n/app_languages.dart';
import 'package:xrecorder/l10n/localization.dart';

import '../test/fixtures/interaction_probe.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => binding.testTextInput.register());
  testWidgets('locale real app controls dialogs RTL font200 both themes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final probe = InteractionProbe(
      'native real app/bridges; Flutter text200 override; actual OS viewport recorded',
    );
    final states = <Map<String, Object?>>[];
    final layouts = <Map<String, Object?>>[];
    final captureRun = DateTime.now().microsecondsSinceEpoch.toString();
    var captureIndex = 0;
    binding.reportData = {'status': 'IN_PROGRESS'};
    try {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await app.main();
      await tester.pumpAndSettle();
      final initial = tester.element(find.byType(StudioBottomNavigation));
      final settings = SettingsScope.of(initial);
      final router = GoRouter.of(initial);
      final initialSettings = await const AndroidSettingsStore().read();
      const image = String.fromEnvironment('TASK09B_IMAGE_URI');
      expect(image, startsWith('content://media/'));
      final originalPixels = (await AndroidMediaRepository.channel
          .invokeMethod<List<int>>('imageBytes', {'uri': image}))!;
      final projectId =
          'task09b_global_${DateTime.now().microsecondsSinceEpoch}';
      final project = EditProject(
        id: projectId,
        title: 'QA Tiếng Việt 日本語 العربية 👩🏽‍💻',
        updatedAt: DateTime.now(),
        clips: [
          TimelineClip(
            mediaId: image,
            isImage: true,
            inPoint: Duration.zero,
            outPoint: const Duration(seconds: 4),
            sourceDuration: const Duration(seconds: 4),
          ),
        ],
      );
      await AndroidEditProjectRepository().save(project);
      Future<void> reveal(Finder finder) async {
        FocusManager.instance.primaryFocus?.unfocus();
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        await tester.pumpAndSettle();
        if (finder.evaluate().isEmpty) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            finder,
            180,
            maxScrolls: 50,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        expect(finder, findsOneWidget);
      }

      Future<void> click(Finder finder) async {
        await reveal(finder);
        expect(finder.hitTestable(), findsOneWidget);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      BuildContext active() => tester.element(find.byType(Scaffold).last);
      Future<void> snapshot(
        String locale,
        String route, {
        bool screenshot = true,
      }) async {
        debugPrint('TASK09B_GLOBAL_STATE=$locale $route');
        expect(tester.takeException(), isNull);
        final context = active();
        final media = MediaQuery.of(context);
        expect(media.textScaler.scale(10), 20);
        expect(
          Directionality.of(context),
          locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        probe.observe(tester, route, '$locale/${settings.themeMode.name}');
        final clipped = <String>[];
        for (final element in find.byType(RichText).evaluate()) {
          final object = element.renderObject;
          if (object is RenderParagraph && object.didExceedMaxLines) {
            clipped.add(object.text.toPlainText());
          }
        }
        states.add({
          'activeUri': router.routeInformationProvider.value.uri.toString(),
          'locale': locale,
          'route': route,
          'theme': settings.themeMode.name,
          'width': media.size.width,
          'height': media.size.height,
          'textScale': 2,
          'rtl': Directionality.of(context) == TextDirection.rtl,
          'truncatedText': clipped,
          'status': 'RENDERED / behavior actions recorded separately',
        });
        if (screenshot) {
          final name =
              '${locale.toLowerCase()}_${route.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${settings.themeMode.name}';
          final request = File(
            '/data/user/0/com.xrecorder.xrecorder/files/task09b_capture_${captureRun}_${captureIndex++}.request.json',
          );
          await request.create(exclusive: true);
          await request.writeAsString(
            jsonEncode({
              'name': name,
              'run': captureRun,
              'route': route,
              'locale': locale,
              'physicalWidth': tester.view.physicalSize.width,
              'physicalHeight': tester.view.physicalSize.height,
            }),
            flush: true,
          );
          final ack = File('${request.path}.ack');
          for (
            var attempt = 0;
            attempt < 450 && !await ack.exists();
            attempt++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            await tester.pump();
          }
          expect(
            await ack.exists(),
            isTrue,
            reason: 'Host must capture actual OS pixels and acknowledge the fresh request.',
          );
        }
      }

      const requested = String.fromEnvironment('TASK09B_LOCALES');
      final requestedTags = requested
          .split(',')
          .where((tag) => tag.isNotEmpty)
          .toSet();
      final locales = AppLanguages.supported
          .where(
            (locale) =>
                requestedTags.isEmpty ||
                requestedTags.contains(locale.toLanguageTag()),
          )
          .toList();
      expect(locales, isNotEmpty);
      expect(
        requestedTags.difference(
          locales.map((locale) => locale.toLanguageTag()).toSet(),
        ),
        isEmpty,
      );
      for (final locale in locales) {
        debugPrint('TASK09B_GLOBAL_LOCALE=${locale.toLanguageTag()}');
        router.go('/settings');
        await tester.pumpAndSettle();
        final priorStrings = active().l10n;
        await click(find.text(priorStrings.appLanguage));
        await tester.enterText(find.byType(TextField), locale.toLanguageTag());
        await tester.pumpAndSettle();
        final languageName = AppLanguages.nativeName(locale);
        await probe.step(
          tester,
          id: 'G4-LANGUAGE-${locale.toLanguageTag()}',
          route: '/settings',
          state: 'language search',
          locator: languageName,
          expected:
              'Select language through actual dialog; saved locale matches',
          action: () => click(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.text(languageName),
            ),
          ),
          verify: () => expect(settings.appLocale, locale),
        );
        await settings.flushed;
        final restored = SettingsController(
          store: const AndroidSettingsStore(),
        );
        await restored.restore();
        expect(restored.appLocale, locale);
        restored.dispose();
        final tag = locale.toLanguageTag();
        settings.setThemeMode(ThemeMode.dark);
        await tester.pumpAndSettle();
        await snapshot(locale.languageCode, 'settings_dark');
        final strings = active().l10n;
        for (final tab in [
          (strings.video, strings.videoLibrary),
          (strings.photo, strings.photoLibrary),
          (strings.edit, strings.editingStudio),
          (strings.settings, strings.settings),
        ]) {
          final target = find
              .descendant(
                of: find.byType(StudioBottomNavigation),
                matching: find.text(tab.$1),
              )
              .last;
          await probe.step(
            tester,
            id: 'G4-$tag-TAB-${tab.$1}',
            route: 'shell',
            state: tag,
            locator: tab.$1,
            expected: 'Localized ${tab.$2} destination renders',
            action: () => click(target),
            verify: () => expect(find.text(tab.$2), findsWidgets),
          );
          await snapshot(
            locale.languageCode,
            'tab_${tab.$1.hashCode.abs()}',
            screenshot: false,
          );
        }
        await click(find.byTooltip(strings.create));
        await snapshot(locale.languageCode, 'create');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await click(find.text(strings.mediaStorage));
        await snapshot(locale.languageCode, 'storage_dialog');
        await click(find.text(strings.close));
        await click(find.text(strings.privacy));
        await snapshot(locale.languageCode, 'privacy_dialog');
        await click(find.text(strings.close));
        await click(find.text(strings.aboutLicenses));
        await snapshot(locale.languageCode, 'about_dialog');
        // AboutDialog owns Material's translated Close action, which can differ
        // from the app's custom dialog label (for example in Arabic).
        await click(
          find.text(MaterialLocalizations.of(active()).closeButtonLabel),
        );
        await click(find.text(strings.helpGuides));
        await snapshot(locale.languageCode, 'help');
        router.pop();
        await tester.pumpAndSettle();
        await click(find.text(strings.feedback));
        await click(find.text(strings.openShareSheet));
        expect(
          find.text(active().message('Write a report before sharing.')),
          findsOneWidget,
        );
        await snapshot(locale.languageCode, 'support_invalid');
        router.pop();
        await tester.pumpAndSettle();
        for (final route in ['/exports', '/trash']) {
          router.push(route);
          await tester.pumpAndSettle();
          await snapshot(locale.languageCode, route);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        }
        router.push('/photo-preview/${Uri.encodeComponent(image)}');
        await tester.pumpAndSettle();
        await snapshot(locale.languageCode, 'photo_preview');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        router.push('/photo-tools/${Uri.encodeComponent(image)}');
        await tester.pumpAndSettle();
        await click(find.text(strings.rotate90));
        final undoButton = find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == strings.undoPhotoEdit,
        );
        await reveal(undoButton);
        expect(tester.widget<IconButton>(undoButton).onPressed, isNotNull);
        await click(undoButton);
        await reveal(undoButton);
        expect(tester.widget<IconButton>(undoButton).onPressed, isNull);
        await snapshot(locale.languageCode, 'photo_tools_undo');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        router.push('/editor/project/$projectId');
        await tester.pumpAndSettle();
        expect(find.text(project.title), findsWidgets);
        await snapshot(locale.languageCode, 'editor');
        await click(find.text(strings.subtitles));
        await snapshot(locale.languageCode, 'subtitles');
        await click(find.text(strings.cancel));
        await generateSubtitlesForLayout(
          tester,
          project,
          probe,
          tag,
          snapshot,
          locale.languageCode,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        settings.setThemeMode(ThemeMode.light);
        await tester.pumpAndSettle();
        await snapshot(locale.languageCode, 'settings_light');
        layouts.add({
          'locale': tag,
          'status': 'PASS',
          'persistedReadback': true,
        });
      }
      // Leave the disposable QA in English/Dark via the existing controller.
      // Recording values are never changed by this test.
      settings.setAppLocale(const Locale('en'));
      settings.setThemeMode(ThemeMode.dark);
      await settings.flushed;
      expect(
        await AndroidMediaRepository.channel.invokeMethod<List<int>>(
          'imageBytes',
          {'uri': image},
        ),
        orderedEquals(originalPixels),
      );
      final previewDiagnostics = await AndroidEditProjectRepository.channel
          .invokeMapMethod<String, dynamic>('editorDiagnostics');
      expect(previewDiagnostics!['activePreviews'], 0);
      binding.reportData = {
        'status': 'PASS',
        'locales': layouts,
        'requestedLocales': locales
            .map((locale) => locale.toLanguageTag())
            .toList(),
        'states': states,
        'interactions': probe.toJson(),
        'physicalPixels': [
          tester.view.physicalSize.width,
          tester.view.physicalSize.height,
        ],
        'dpr': tester.view.devicePixelRatio,
        'initialSettingsRead': initialSettings != null,
        'humanTalkBack': 'NOT RUN',
        'captureInvoked': false,
        'captureRun': captureRun,
        'originalImageBytesExact': true,
        'previewDiagnosticsAfter': previewDiagnostics,
      };
    } finally {
      binding.reportData = {
        ...binding.reportData ?? {},
        'partialStates': states,
        'partialLocales': layouts,
        'interactions': probe.toJson(),
      };
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      semantics.dispose();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      final complete = File(
        '/data/user/0/com.xrecorder.xrecorder/files/task09b_capture_${captureRun}_complete.json',
      );
      await complete.create(exclusive: true);
      await complete.writeAsString(
        jsonEncode({
          'run': captureRun,
          'states': states.length,
          'locales': layouts.length,
          'captures': captureIndex,
          'status': binding.reportData?['status'],
        }),
        flush: true,
      );
    }
  }, timeout: const Timeout(Duration(minutes: 25)));
}

Future<void> generateSubtitlesForLayout(
  WidgetTester tester,
  EditProject project,
  InteractionProbe probe,
  String tag,
  Future<void> Function(String, String, {bool screenshot}) snapshot,
  String language,
) async {
  final context = tester.element(find.byType(Scaffold).last);
  final future = generateSubtitles(context, project);
  await tester.pumpAndSettle();
  await snapshot(language, 'ai');
  final close = find.text(context.l10n.close).last;
  await tester.ensureVisible(close);
  await tester.tap(close);
  await tester.pumpAndSettle();
  expect(await future, isNull);
}
