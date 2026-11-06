import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/recording/recording_service.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';
import 'package:xrecorder/features/settings/help_screen.dart';
import 'package:xrecorder/features/editor/editor_screen.dart';
import 'package:xrecorder/features/editor/project_effects.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/media/media_library_screen.dart';
import 'package:xrecorder/core/widgets/studio_widgets.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'fixtures/catalog.dart';

class RefreshCatalog extends TestCatalog {
  int calls = 0;
  Uri? lastFolder;
  Completer<List<MediaItem>>? held;
  @override
  Future<List<MediaItem>> list({required MediaKind kind, Uri? folder}) async {
    calls++;
    lastFolder = folder;
    if (held case final pending?) {
      held = null;
      return pending.future;
    }
    return super.list(kind: kind, folder: folder);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
    await font.load();
  });
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      AndroidRecordingService.commands,
      (call) async =>
          call.method == 'current' ? {'id': '', 'state': 'idle'} : null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.xrecorder/capture/events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      AndroidEditProjectRepository.channel,
      (call) async => switch (call.method) {
        'list' => <Object?>[],
        'find' => jsonEncode(
          EditProject(
            id: 'draft',
            clips: [],
            updatedAt: DateTime(2026),
          ).toJson(),
        ),
        _ => null,
      },
    );
  });

  Future<GoRouter> start(
    WidgetTester tester, {
    TestCatalog? catalog,
    SettingsController? settings,
    Size size = const Size(411, 900),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      XRecorderApp(
        mediaRepository: catalog ?? TestCatalog(),
        settings: settings,
      ),
    );
    await tester.pumpAndSettle();
    return GoRouter.of(tester.element(find.text('Video Library')));
  }

  testWidgets(
    'returning from a newly created project reloads drafts without a Future setState callback',
    (tester) async {
      var lists = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidEditProjectRepository.channel, (
            call,
          ) async {
            if (call.method == 'list') {
              lists++;
              return <Object?>[];
            }
            if (call.method == 'find') {
              return jsonEncode(
                EditProject(
                  id: 'draft',
                  clips: [],
                  updatedAt: DateTime(2026),
                ).toJson(),
              );
            }
            return null;
          });
      await tester.pumpWidget(XRecorderApp(mediaRepository: TestCatalog()));
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.text('Video Library'))).go('/editor');
      await tester.pumpAndSettle();
      await tester.tap(find.text('New video project'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.textContaining('setState()'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(lists, 2);
    },
  );

  testWidgets('draft load retry and delete confirmation reload synchronously', (
    tester,
  ) async {
    var attempts = 0;
    var deleted = false;
    final project = EditProject(
      id: 'owned-draft',
      title: 'Owned draft',
      clips: [],
      updatedAt: DateTime(2026),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEditProjectRepository.channel, (
          call,
        ) async {
          if (call.method == 'list') {
            if (++attempts == 1) {
              throw PlatformException(
                code: 'io',
                message: 'InternalDatabaseException secret_table',
              );
            }
            return deleted ? <Object?>[] : [jsonEncode(project.toJson())];
          }
          if (call.method == 'delete') deleted = true;
          return null;
        });
    final router = await start(tester);
    router.go('/editor');
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load your drafts. Try again."), findsOneWidget);
    expect(find.textContaining('InternalDatabaseException'), findsNothing);
    await tester.tap(find.text('Retry drafts'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete draft'));
    await tester.pumpAndSettle();
    expect(deleted, isFalse);
    await tester.tap(find.text('Delete draft').last);
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
    expect(find.text('No drafts yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing during draft save does not update a disposed widget', (
    tester,
  ) async {
    final pending = Completer<Object?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEditProjectRepository.channel, (
          call,
        ) async {
          if (call.method == 'list') return <Object?>[];
          if (call.method == 'save') return pending.future;
          return null;
        });
    final router = await start(tester);
    router.go('/editor');
    await tester.pumpAndSettle();
    await tester.tap(find.text('New video project'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Screenshot invokes native screenshot once and never opens recording setup',
    (tester) async {
      var screenshots = 0, starts = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidRecordingService.commands, (
            call,
          ) async {
            if (call.method == 'screenshot') {
              screenshots++;
              return {
                'id': 'shot',
                'state': 'awaitingPermission',
                'screenshot': true,
              };
            }
            if (call.method == 'start') starts++;
            return {'id': '', 'state': 'idle'};
          });
      await start(tester);
      expect(AppIcons.screenshot, LucideIcons.camera);
      await tester.tap(find.text('Screenshot'));
      await tester.pumpAndSettle();
      expect(screenshots, 1);
      expect(starts, 0);
      expect(find.text('Recording settings'), findsNothing);
      final tile = tester.widget<QuickActionTile>(
        find.widgetWithText(QuickActionTile, 'Screenshot'),
      );
      expect(tile.onTap, isNull);
    },
  );

  testWidgets(
    'media events retain search, sort, position and thumbnail state',
    (tester) async {
      final catalog = RefreshCatalog();
      await start(tester, catalog: catalog);
      await tester.enterText(find.byType(TextField).first, 'Clip 1');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Newest'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -450));
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final offset = position.pixels;
      final thumb = tester.state(find.byType(MediaThumbnail).first);
      catalog.refresh();
      await tester.pumpAndSettle();
      expect(position.pixels, offset);
      expect(tester.state(find.byType(MediaThumbnail).first), same(thumb));
      await tester.tap(find.text('Video'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Clip 1',
      );
      expect(find.text('Oldest'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'folder events keep selection and a burst during loading has one follow-up',
    (tester) async {
      final catalog = RefreshCatalog()
        ..selection = Uri.parse('content://documents/tree/test');
      await start(tester, catalog: catalog);
      await tester.tap(find.text('Choose folder'));
      await tester.pumpAndSettle();
      expect(catalog.lastFolder, catalog.selection);
      expect(
        tester
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, 'Choose folder'),
            )
            .selected,
        isTrue,
      );
      final pending = Completer<List<MediaItem>>();
      catalog.held = pending;
      final before = catalog.calls;
      catalog.refresh();
      await tester.pump();
      catalog.refresh();
      catalog.refresh();
      await tester.pump();
      pending.complete(List.of(catalog.items));
      await tester.pumpAndSettle();
      expect(catalog.calls - before, 2);
      expect(catalog.lastFolder, catalog.selection);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 800), const Size(411, 900)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('sort controls fit ${size.width}dp at $scale', (
        tester,
      ) async {
        await start(tester, size: size, scale: scale);
        expect(find.text('Refresh'), findsNothing);
        final newest = find.widgetWithText(ActionChip, 'Newest');
        if (size.width == 411 && scale == 1) {
          final app = tester
              .getTopLeft(find.widgetWithText(ChoiceChip, 'App media'))
              .dy;
          expect(tester.getTopLeft(newest).dy, closeTo(app, .1));
          expect(
            tester
                .getTopLeft(find.widgetWithText(ChoiceChip, 'Choose folder'))
                .dy,
            closeTo(app, .1),
          );
        }
        await tester.ensureVisible(newest);
        await tester.pumpAndSettle();
        await tester.tap(newest);
        await tester.pumpAndSettle();
        expect(find.text('Oldest'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final tab in [
    ('Video', '/videos'),
    ('Photo', '/photos'),
    ('Edit', '/editor'),
    ('Settings', '/settings'),
  ]) {
    testWidgets('${tab.$1} reselect scrolls to top without a route change', (
      tester,
    ) async {
      final router = await start(tester, size: const Size(320, 600));
      router.go(tab.$2);
      await tester.pumpAndSettle();
      // Empty Edit/Photo need large text to provide enough content to scroll.
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final route = router.routeInformationProvider.value.uri;
      await tester.tap(find.byTooltip(tab.$1));
      await tester.pumpAndSettle();
      expect(position.pixels, position.minScrollExtent);
      expect(router.routeInformationProvider.value.uri, route);
      expect(tester.takeException(), isNull);
    });
  }

  for (final mode in ThemeMode.values) {
    testWidgets('Editor follows ${mode.name} on opening and while open', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final settings = SettingsController()..setThemeMode(mode);
      final router = await start(tester, settings: settings);
      router.push('/editor/project/draft');
      await tester.pumpAndSettle();
      final editor = tester.state(find.byType(EditorScreen));
      expect(
        Theme.of(tester.element(find.text('Add your first clip'))).brightness,
        mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
      );
      expect(AppIcons.back, LucideIcons.chevronLeft);
      expect(find.byIcon(AppIcons.back), findsOneWidget);
      settings.setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Add your first clip'))).brightness,
        Brightness.dark,
      );
      settings.setThemeMode(ThemeMode.system);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Add your first clip'))).brightness,
        Brightness.light,
      );
      expect(tester.state(find.byType(EditorScreen)), same(editor));
      expect(tester.takeException(), isNull);
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('FAQ has readable hierarchy and keeps search at $scale', (
      tester,
    ) async {
      final router = await start(
        tester,
        size: const Size(320, 700),
        scale: scale,
      );
      router.go('/help');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'How do I record');
      await tester.pumpAndSettle();
      final question = helpTopics.first;
      await tester.tap(find.text(question.question));
      await tester.pumpAndSettle();
      final title = tester.widget<Text>(find.text(question.question));
      final answer = tester.widget<Text>(find.text(question.answer));
      expect(title.style!.fontWeight, FontWeight.w700);
      expect(answer.style!.fontWeight ?? FontWeight.w400, FontWeight.w400);
      expect(title.style!.color, isNot(answer.style!.color));
      expect(answer.style!.height, 1.6);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'How do I record',
      );
      expect(tester.takeException(), isNull);
    });
  }

  test('untrusted errors never expose technical details', () {
    for (final error in [
      PlatformException(
        code: 'io',
        message: 'InternalDatabaseException secret_table',
      ),
      const FormatException('secret_method'),
      StateError('secret stack trace'),
      'java.io.IOException at com.internal.save',
    ]) {
      final notice = UserMessages.failure(
        error,
        operation: UserOperation.savePhoto,
      );
      expect(
        notice.text,
        "Couldn't save the photo. Check storage and try again.",
      );
      expect(notice.text, isNot(contains('Exception')));
    }
    expect(
      UserMessages.failure(
        PlatformException(code: 'denied'),
        operation: UserOperation.screenshot,
      ).text,
      "Screenshot permission wasn't granted.",
    );
    expect(
      UserMessages.failure(
        'Recording interrupted',
        operation: UserOperation.recording,
      ).helpTopic,
      'recording-stopped',
    );
    expect(
      UserMessages.failure(
        'disk full',
        operation: UserOperation.export,
      ).helpTopic,
      isNull,
    );
  });

  testWidgets(
    'native events coalesce and resume only publishes actual changes',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var checks = 0;
      messenger.setMockMethodCallHandler(
        MethodChannel(AndroidMediaRepository.events.name),
        (_) async => null,
      );
      void nativeEvent() => tester.binding.channelBuffers.push(
        AndroidMediaRepository.events.name,
        const StandardMethodCodec().encodeSuccessEnvelope(null),
        (_) {},
      );
      messenger.setMockMethodCallHandler(AndroidMediaRepository.channel, (
        call,
      ) async {
        if (call.method == 'checkForChanges') checks++;
        return null;
      });
      final repository = AndroidMediaRepository();
      var notifications = 0;
      final subscription = repository.changes.listen((_) {
        notifications++;
      });
      await tester.pump();
      repository.refresh();
      nativeEvent();
      nativeEvent();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(notifications, 1);
      repository.didChangeAppLifecycleState(AppLifecycleState.paused);
      repository.refresh();
      await tester.pump(const Duration(seconds: 1));
      expect(notifications, 1);
      repository.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 300));
      expect(notifications, 2);
      repository.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 300));
      expect(notifications, 2);
      expect(checks, 2);
      await tester.runAsync(() async {
        await subscription.cancel();
        repository.dispose();
        await Future<void>.delayed(Duration.zero);
      });
    },
  );

  testWidgets(
    'notice kinds share style, replace queued notices and stay above navigation',
    (tester) async {
      late BuildContext target;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: const SizedBox(
              height: 80,
              child: Text('Navigation'),
            ),
            body: Builder(
              builder: (context) {
                target = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      for (final kind in NoticeKind.values) {
        showNotice(target, kind.name, kind: kind);
        await tester.pumpAndSettle();
        expect(find.text(kind.name), findsOneWidget);
        expect(
          tester.getBottomLeft(find.byType(SnackBar)).dy,
          lessThanOrEqualTo(tester.getTopLeft(find.text('Navigation')).dy),
        );
      }
      showNotice(target, 'first');
      showNotice(target, 'second');
      showNotice(target, 'latest');
      await tester.pumpAndSettle();
      expect(find.text('first'), findsNothing);
      expect(find.text('second'), findsNothing);
      expect(find.text('latest'), findsOneWidget);
    },
  );

  testWidgets(
    'empty copy follows app media, folder, search, and photo context',
    (tester) async {
      final catalog = TestCatalog()..items.clear();
      catalog.selection = Uri.parse('content://test/tree/empty');
      final router = await start(tester, catalog: catalog);
      expect(find.text('No recordings yet'), findsOneWidget);
      expect(find.text('Your videos will appear here.'), findsOneWidget);
      await tester.tap(find.text('Choose folder'));
      await tester.pumpAndSettle();
      expect(find.text('No videos in this folder'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'absent');
      await tester.pumpAndSettle();
      expect(find.text('No matching media'), findsOneWidget);
      router.go('/photos');
      await tester.pumpAndSettle();
      expect(find.text('No screenshots yet'), findsOneWidget);
      await tester.tap(find.text('Choose folder'));
      await tester.pumpAndSettle();
      expect(find.text('No photos in this folder'), findsOneWidget);
    },
  );

  testWidgets(
    'app thumbnail cache clears on memory pressure and media change',
    (tester) async {
      final catalog = TestCatalog()..items.clear();
      await start(tester, catalog: catalog);
      final cache = tester
          .widget<MediaScope>(find.byType(MediaScope))
          .thumbnails!;
      var pending = cache.load('pressure', () async => Uint8List(4));
      await tester.pump();
      await pending;
      expect(cache.retainedBytes, 4);
      tester.binding.handleMemoryPressure();
      expect(cache.retainedBytes, 0);
      pending = cache.load('changed', () async => Uint8List(4));
      await tester.pump();
      await pending;
      catalog.refresh();
      await tester.pump();
      expect(cache.retainedBytes, 0);
    },
  );

  testWidgets('capture Help opens the related expanded guide', (tester) async {
    final router = await start(tester);
    showFailure(
      tester.element(find.text('Video Library')),
      'Recording interrupted unexpectedly',
      operation: UserOperation.recording,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Help'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<HelpScreen>(find.byType(HelpScreen)).initialTopic,
      'recording-stopped',
    );
    expect(router.canPop(), isTrue);
    expect(find.text(helpTopics[4].answer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('friendly notices do not swallow programming errors', (
    tester,
  ) async {
    await start(tester);
    final previous = FlutterError.onError;
    FlutterErrorDetails? reported;
    try {
      FlutterError.onError = (details) {
        reported = details;
      };
      showFailure(
        tester.element(find.text('Video Library')),
        FlutterError('setState regression marker'),
        operation: UserOperation.createDraft,
      );
    } finally {
      FlutterError.onError = previous;
    }
    await tester.pumpAndSettle();
    expect(reported?.exception, isA<FlutterError>());
    expect(find.textContaining('regression marker'), findsNothing);
    expect(
      find.text("Couldn't create a project. Check storage and try again."),
      findsOneWidget,
    );
  });

  testWidgets(
    'music picker failure stays friendly and visible inside its dialog',
    (tester) async {
      await start(tester);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidMediaRepository.channel, (_) async {
            throw PlatformException(
              code: 'io',
              message: 'InternalMusicClass marker',
            );
          });
      unawaited(
        editProjectEffects(tester.element(find.text('Video Library')), {}),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Add background music'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Add background music'));
      await tester.pumpAndSettle();
      expect(find.textContaining('InternalMusicClass'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(
            "Couldn't open this file. Check access and try again.",
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
