import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/domain/repositories.dart';
import 'package:xrecorder/core/ui/components/inputs/studio_fields.dart';
import 'package:xrecorder/core/ui/theme/app_theme.dart';
import 'package:xrecorder/l10n/localization.dart';
import 'package:xrecorder/features/editor/editor_entry.dart';
import 'package:xrecorder/features/editor/editing_hub_screen.dart';
import 'package:xrecorder/features/editor/editor_selection.dart';
import 'package:xrecorder/features/editor/editor_timeline.dart';
import 'package:xrecorder/features/editor/media_picker.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/media/video_details_screen.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

import 'fixtures/catalog.dart';

MediaItem media(String uri, MediaKind kind, {int milliseconds = 5000}) =>
    MediaItem(
      id: uri,
      uri: Uri.parse(uri),
      kind: kind,
      displayName: kind == MediaKind.video ? 'UI06 clip.mp4' : 'UI06 photo.png',
      mimeType: kind == MediaKind.video ? 'video/mp4' : 'image/png',
      sizeBytes: 1024,
      createdAt: DateTime(2026),
      modifiedAt: DateTime(2026),
      source: MediaSource.imported,
      duration: Duration(milliseconds: milliseconds),
    );

class _Catalog extends TestCatalog {
  _Catalog() {
    items
      ..clear()
      ..addAll([
        media('content://media/external/video/media/42', MediaKind.video),
        media(
          'content://com.android.externalstorage.documents/document/primary%3Aqa.png',
          MediaKind.image,
        ),
      ]);
  }
  @override
  Future<List<MediaItem>> list({required MediaKind kind, Uri? folder}) async =>
      items.where((item) => item.kind == kind).toList();
}

class _Projects implements EditProjectRepository {
  final saved = <EditProject>[];
  @override
  Future<EditProject?> find(String id) async =>
      saved.where((p) => p.id == id).firstOrNull;
  @override
  Future<void> save(EditProject project) async => saved.add(project);
  @override
  Future<void> delete(String id) async =>
      throw StateError('Deletion is not a launch operation');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  test('selection follows the clip through reorder, Undo and Redo', () {
    TimelineClip clip(int i) => TimelineClip(
      mediaId: 'content://qa/$i',
      inPoint: Duration.zero,
      outPoint: const Duration(seconds: 5),
      sourceDuration: const Duration(seconds: 5),
    );
    final a = clip(1), b = clip(2), c = clip(3);
    final original = [a, b, c], moved = [b, c, a];
    final selected = retainClipSelection(original, moved, 0);
    expect(selected, 2);
    expect(identical(moved[selected], a), isTrue);
    expect(retainClipSelection(moved, original, selected), 0);
    expect(retainClipSelection(original, moved, 0), 2);
    expect(retainClipSelection([a], [], 0), 0);
    expect(retainClipSelection([a, b], [a, a, b], 0), 0);
    expect(retainClipSelection([a, b], [a.copyWith(rotation: 90), b], 0), 0);
  });
  test('project launch validates every clip before the only save', () async {
    final repository = _Projects();
    for (final selection in [
      <MediaItem>[],
      [media('content://qa/too-short', MediaKind.video, milliseconds: 199)],
      [media('content://qa/gif', MediaKind.gif)],
      List.generate(31, (i) => media('content://qa/$i', MediaKind.video)),
    ]) {
      await expectLater(
        createEditorProject(
          media: selection,
          title: 'QA',
          repository: repository,
        ),
        throwsFormatException,
      );
      expect(repository.saved, isEmpty);
    }
    final catalog = _Catalog();
    final before = catalog.items.map((item) => item.uri).toList();
    final project = await createEditorProject(
      media: catalog.items,
      title: 'QA',
      repository: repository,
    );
    expect(repository.saved, [project]);
    expect(
      project.clips.map((clip) => clip.mediaId),
      before.map((uri) => uri.toString()),
    );
    expect(project.clips.last.isImage, isTrue);
    expect(project.clips.last.duration, const Duration(seconds: 5));
    expect(catalog.items.map((item) => item.uri), before);
    catalog.dispose();
  });

  for (final mode in ['batch', 'photo', 'cancel']) {
    testWidgets(
      'media picker $mode returns only explicit supported selection',
      (tester) async {
        final catalog = _Catalog();
        Object? result;
        await tester.pumpWidget(
          MediaScope(
            repository: catalog,
            child: MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async {
                      result = mode == 'photo'
                          ? await pickEditorPhoto(context)
                          : await pickEditorMediaBatch(context);
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        if (mode == 'cancel') {
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(result, isNull);
        } else if (mode == 'photo') {
          expect(find.widgetWithText(ChoiceChip, 'Videos'), findsNothing);
          await tester.tap(find.text('UI06 photo.png'));
          await tester.pumpAndSettle();
          expect((result as MediaItem).kind, MediaKind.image);
        } else {
          await tester.tap(find.text('UI06 clip.mp4'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(ChoiceChip, 'Photos'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('UI06 photo.png'));
          await tester.pumpAndSettle();
          final accept = tester.widget<FilledButton>(find.byType(FilledButton));
          accept.onPressed!();
          accept.onPressed!();
          await tester.pumpAndSettle();
          expect(
            (result as List<MediaItem>).map((item) => item.id),
            catalog.items.map((item) => item.id),
          );
          expect(find.text('Open'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        catalog.dispose();
      },
    );
  }

  for (final size in [const Size(320, 800), const Size(800, 320)]) {
    for (final photoOnly in [false, true]) {
      testWidgets('picker layout $size photo=$photoOnly RTL text200', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final catalog = _Catalog();
        await tester.pumpWidget(
          MediaScope(
            repository: catalog,
            child: MaterialApp(
              theme: AppTheme.dark,
              locale: const Locale('ar'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => photoOnly
                        ? pickEditorPhoto(context)
                        : pickEditorMediaBatch(context),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final dialog = find.byType(Dialog);
        final cancel = find
            .descendant(of: dialog, matching: find.byType(TextButton))
            .last;
        expect(tester.getRect(cancel).height, greaterThanOrEqualTo(48));
        await tester.tap(cancel);
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        catalog.dispose();
      });
    }
  }

  testWidgets('photo Save copy replacement does not lock Studio creation', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(
      AndroidEditProjectRepository.channel,
      (call) async => call.method == 'list' ? <Object?>[] : null,
    );
    final catalog = _Catalog();
    final router = GoRouter(
      initialLocation: '/editor',
      routes: [
        GoRoute(
          path: '/editor',
          builder: (_, _) => const Scaffold(body: EditingHubScreen()),
        ),
        GoRoute(
          path: '/photo-tools/:id',
          builder: (context, _) => Scaffold(
            body: TextButton(
              // The real PhotoToolsScreen uses this replacement after native
              // saveImage succeeds. Here we isolate its navigation contract.
              onPressed: () => context.pushReplacement('/media/saved'),
              child: const Text('Save copy'),
            ),
          ),
        ),
        GoRoute(
          path: '/media/:id',
          builder: (context, _) => Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: () => context.pop()),
              title: const Text('Saved media'),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MediaScope(
        repository: catalog,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UI06 photo.png'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save copy'));
    await tester.pumpAndSettle();
    expect(find.text('Saved media'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Opening your project…'), findsNothing);
    await tester.tap(find.text('New video project'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    catalog.dispose();
  });

  testWidgets('cancel New video leaves every draft untouched', (tester) async {
    var writes = 0;
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
    messenger.setMockMethodCallHandler(AndroidEditProjectRepository.channel, (
      call,
    ) async {
      if (call.method == 'save' || call.method == 'delete') writes++;
      return call.method == 'list' ? <Object?>[] : null;
    });
    final catalog = _Catalog();
    await tester.pumpWidget(XRecorderApp(mediaRepository: catalog));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('Video Library'))).go('/editor');
    await tester.pumpAndSettle();
    await tester.tap(find.text('New video project'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(find.text('New video project'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final target in ['Create', 'All tools']) {
    for (final taps in [2, 3, 5]) {
      testWidgets('compact $target preserves guard for $taps rapid taps', (
        tester,
      ) async {
        final commands = <String>[];
        messenger.setMockMethodCallHandler(AndroidRecordingService.commands, (
          call,
        ) async {
          commands.add(call.method);
          return call.method == 'current'
              ? {'id': '', 'state': 'idle'}
              : {
                  'presets': [],
                  'audioSources': ['mute'],
                };
        });
        messenger.setMockMethodCallHandler(
          const MethodChannel('com.xrecorder/capture/events'),
          (_) async => null,
        );
        messenger.setMockMethodCallHandler(
          AndroidEditProjectRepository.channel,
          (call) async => call.method == 'list' ? <Object?>[] : null,
        );
        await tester.pumpWidget(XRecorderApp(mediaRepository: _Catalog()));
        await tester.pumpAndSettle();
        final button = target == 'Create'
            ? find.byTooltip(target)
            : find.text(target);
        final point = tester.getCenter(button);
        await tester.tapAt(point);
        await tester.pump();
        for (var i = 1; i < taps; i++) {
          await tester.pump(const Duration(milliseconds: 80));
          await tester.tapAt(point);
        }
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 310));
        final modal = find.byType(BottomSheet);
        expect(modal, findsOneWidget);
        expect(
          find.descendant(of: modal, matching: find.text('Record screen')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: modal, matching: find.text('Screenshot')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: modal, matching: find.text('Livestream')),
          findsNothing,
        );
        expect(
          find.descendant(of: modal, matching: find.text('Facecam')),
          findsNothing,
        );
        expect(
          commands.where(
            (method) => method == 'start' || method == 'screenshot',
          ),
          isEmpty,
        );
        await tester.tap(
          find.descendant(of: modal, matching: find.byTooltip('Close')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Video Library'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
  for (final source in [
    'content://media/external/video/media/42',
    'content://com.android.externalstorage.documents/document/primary%3AMovies%2Fqa.mp4',
  ]) {
    testWidgets(
      'Media Details Edit keeps URI and reuses its launched project: $source',
      (tester) async {
        final catalog = _Catalog()..items.clear();
        catalog.items.add(media(source, MediaKind.video));
        final saved = <String, EditProject>{};
        var writes = 0;
        messenger.setMockMethodCallHandler(
          AndroidEditProjectRepository.channel,
          (call) async {
            if (call.method == 'save') {
              final p = EditProject.fromJson(
                jsonDecode(call.arguments as String) as Map<String, dynamic>,
              );
              saved[p.id] = p;
              writes++;
              return null;
            }
            if (call.method == 'find') {
              final found = saved[call.arguments];
              return found == null ? null : jsonEncode(found.toJson());
            }
            return null;
          },
        );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => VideoDetailsScreen(id: source),
            ),
            GoRoute(
              path: '/editor/project/:id',
              builder: (context, state) => Scaffold(
                appBar: AppBar(
                  leading: BackButton(onPressed: () => context.pop()),
                ),
                body: Text(state.pathParameters['id']!),
              ),
            ),
          ],
        );
        await tester.pumpWidget(
          MediaScope(
            repository: catalog,
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (var i = 0; i < 2; i++) {
          final button = find.widgetWithText(OutlinedButton, 'Edit video');
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(find.text(saved.keys.single), findsOneWidget);
          expect(saved.values.single.clips.single.mediaId, source);
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
        }
        expect(writes, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        catalog.dispose();
      },
    );
  }

  testWidgets(
    'timeline position does not decode again; trim commits once at gesture end',
    (tester) async {
      final catalog = _Catalog();
      final project = await createEditorProject(
        media: catalog.items,
        title: 'QA',
        repository: _Projects(),
      );
      final position = ValueNotifier(Duration.zero);
      final scroll = ScrollController();
      var frames = 0, commits = 0;
      RangeValues? committed;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EditorTimeline(
              project: project,
              selected: 0,
              position: position,
              scrollController: scroll,
              frame: (_, _) async {
                frames++;
                return null;
              },
              onSelect: (_) {},
              onSeek: (_) {},
              onTrim: (_, range) {
                commits++;
                committed = range;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final decoded = frames;
      for (var i = 0; i < 20; i++) {
        position.value = Duration(milliseconds: i * 100);
        await tester.pump();
      }
      expect(frames, decoded);
      var slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
      slider.onChangeStart!(slider.values);
      slider.onChanged!(const RangeValues(200, 4500));
      await tester.pump();
      expect(commits, 0);
      slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
      slider.onChangeEnd!(slider.values);
      expect(commits, 1);
      expect(committed, const RangeValues(200, 4500));
      expect(project.clips.first.inPoint, Duration.zero);
      await tester.pumpWidget(const SizedBox.shrink());
      position.dispose();
      scroll.dispose();
      catalog.dispose();
      expect(tester.takeException(), isNull);
    },
  );
  for (final tag in ['en', 'vi', 'ar', 'de']) {
    testWidgets('Clear text keeps focus and never submits: $tag', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'UI06 original name');
      final focus = FocusNode();
      var submissions = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: Locale(tag),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: TextField(
              controller: controller,
              focusNode: focus,
              onSubmitted: (_) => submissions++,
              decoration: InputDecoration(
                suffixIcon: StudioClearTextButton(controller: controller),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      final clear = find.descendant(
        of: find.byType(StudioClearTextButton),
        matching: find.byType(IconButton),
      );
      expect(tester.getSize(clear).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(clear).height, greaterThanOrEqualTo(48));
      await tester.tap(clear);
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(focus.hasFocus, isTrue);
      expect(submissions, 0);
      expect(clear, findsNothing);
      await tester.enterText(find.byType(TextField), 'next');
      await tester.pump();
      expect(clear, findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      focus.dispose();
      controller.dispose();
      expect(tester.takeException(), isNull);
    });
  }
}
