import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/widgets/studio_create_sheet.dart';
import 'package:xrecorder/core/widgets/studio_widgets.dart';
import 'package:xrecorder/features/editor/editor_screen.dart';
import 'package:xrecorder/features/editor/export_screen.dart';
import 'package:xrecorder/features/editor/media_picker.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/media/photo_preview_screen.dart';
import 'package:xrecorder/features/media/photo_tools_screen.dart';
import 'package:xrecorder/features/recording/recording_service.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';

import 'fixtures/visual_catalog.dart';

class _Catalog extends VisualCatalog {
  _Catalog(super.image);
  int folderRequests = 0, reads = 0;
  final folder = Completer<Uri?>();
  @override
  Future<Uri?> selectFolder() {
    folderRequests++;
    return folder.future;
  }

  @override
  Future<Uint8List> thumbnail(Uri uri) {
    reads++;
    return super.thumbnail(uri);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Uint8List image;
  late _Catalog catalog;
  late GoRouter router;
  late EditProject project;
  Future<void> start(
    WidgetTester tester, {
    double width = 411,
    double height = 900,
    double scale = 1,
    ThemeMode mode = ThemeMode.light,
  }) async {
    image = (await tester.runAsync(fixtureImage))!;
    catalog = _Catalog(image);
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      XRecorderApp(
        settings: SettingsController()..setThemeMode(mode),
        mediaRepository: catalog,
      ),
    );
    await tester.pumpAndSettle();
    router = GoRouter.of(tester.element(find.text('Video Library')));
  }

  Future<void> settleImage(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    project = EditProject(id: 'ux', clips: [], updatedAt: DateTime(2026));
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
      (call) async => switch (call.method) {
        'list' => <Object?>[],
        'find' => jsonEncode(project.toJson()),
        _ => null,
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.xrecorder/media'),
      (call) async => call.method == 'decodePhoto' ? image : null,
    );
  });
  testWidgets(
    'repeated Create opens one sheet and handoff to recording setup works',
    (tester) async {
      await start(tester);
      final host = tester.element(find.text('Video Library'));
      final first = openStudioCreate(host), second = openStudioCreate(host);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close create menu'), findsOneWidget);
      await tester.tap(find.text('Screen recording'));
      await tester.pumpAndSettle();
      expect(find.text('Recording settings'), findsOneWidget);
      await tester.tap(find.byTooltip('Close setup'));
      await tester.pumpAndSettle();
      await first;
      await second;
    },
  );
  for (final width in [320.0, 411.0]) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        'photo controls and discard guard fit $width ${mode.name} at 200 percent',
        (tester) async {
          await start(tester, width: width, scale: 2, mode: mode);
          router.push('/photo-tools/fixture');
          await tester.pump();
          await settleImage(tester);
          final cropTool = find.byKey(const ValueKey('photo-tool-crop'));
          await tester.ensureVisible(cropTool);
          await tester.tap(cropTool);
          await tester.pumpAndSettle();
          final range = find.byType(RangeSlider).first;
          await tester.ensureVisible(range);
          tester.widget<RangeSlider>(range).onChanged!(
            const RangeValues(.1, .9),
          );
          await tester.pump();
          final semantics = tester.ensureSemantics();
          await tester.pump();
          expect(find.bySemanticsLabel('Crop left and right'), findsOneWidget);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          semantics.dispose();
          final save = find
              .ancestor(
                of: find.text('Save copy'),
                matching: find.byWidgetPredicate((w) => w is FilledButton),
              )
              .first;
          expect(tester.getRect(save).bottom, lessThan(900));
          expect(tester.getSize(save).height, greaterThanOrEqualTo(48));
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
          expect(find.text('Discard photo edits?'), findsOneWidget);
          await tester.tap(find.text('Keep editing'));
          await tester.pumpAndSettle();
          expect(find.byType(PhotoToolsScreen), findsOneWidget);
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Discard edits'));
          await tester.pumpAndSettle();
          expect(find.byType(PhotoToolsScreen), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'picker is lazy and repeated folder requests coalesce; cancel stays reachable with keyboard',
    (tester) async {
      await start(tester, width: 320, height: 600, scale: 2);
      tester.view.viewInsets = const FakeViewPadding(bottom: 140);
      await tester.pump();
      final pending = pickEditorMedia(
        tester.element(find.text('Video Library')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Studio fixture 30.mp4'), findsNothing);
      final choose = tester.widget<ChoiceChip>(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.widgetWithText(ChoiceChip, 'Choose folder'),
        ),
      );
      choose.onSelected!(true);
      choose.onSelected!(true);
      await tester.pump();
      expect(catalog.folderRequests, 1);
      catalog.folder.complete(null);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await pending;
      tester.view.resetViewInsets();
    },
  );
  testWidgets('export finalizing is shown as Saving and has no unsafe cancel', (
    tester,
  ) async {
    var completed = false;
    var polls = 0;
    messenger.setMockMethodCallHandler(AndroidEditProjectRepository.channel, (
      call,
    ) async {
      expect(call.method, 'exportList');
      polls++;
      return jsonEncode([
        {
          'id': 'job',
          'state': completed ? 'completed' : 'finalizing',
          'progress': 100,
          'project': {'title': 'My video'},
          if (completed) ...{
            'uri': 'content://media/external/video/media/99',
            'outputBytes': 1024,
          },
        },
      ]);
    });
    await tester.pumpWidget(MaterialApp(home: const ExportScreen()));
    // Finalizing intentionally animates until native publication completes.
    // Advance bounded frames instead of waiting for that animation to stop.
    await tester.pump();
    expect(find.text('Saving… · 100%'), findsOneWidget);
    expect(find.text('Cancel export'), findsNothing);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      isNull,
    );
    for (var i = 0; i < 2; i++) {
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('Saving… · 100%'), findsOneWidget);
      expect(find.text('Cancel export'), findsNothing);
    }
    expect(polls, greaterThanOrEqualTo(3));
    completed = true;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Saved · 100%'), findsOneWidget);
    expect(find.text('Open saved media'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Cancel export'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('photo read failure offers retry and recovers', (tester) async {
    await start(tester);
    var requests = 0;
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.xrecorder/media'),
      (call) async {
        requests++;
        if (requests == 1) throw PlatformException(code: 'unavailable');
        return image;
      },
    );
    router.push('/photo-preview/fixture');
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await settleImage(tester);
    expect(find.byType(PhotoPreviewScreen), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(requests, 2);
  });
  testWidgets(
    'saving a photo blocks repeated save and exit; failure preserves edits',
    (tester) async {
      await start(tester);
      final pending = Completer<String>();
      var writes = 0;
      messenger.setMockMethodCallHandler(
        const MethodChannel('com.xrecorder/media'),
        (call) async {
          if (call.method == 'decodePhoto') return image;
          if (call.method == 'saveImage') {
            writes++;
            return pending.future;
          }
          return null;
        },
      );
      router.push('/photo-tools/fixture');
      await tester.pump();
      await settleImage(tester);
      final canvas = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PhotoPainter,
      );
      await tester.ensureVisible(canvas);
      await tester.drag(canvas, const Offset(70, 20));
      await tester.pump();
      expect(
        (tester.state(find.byType(PhotoToolsScreen)) as dynamic).marks,
        isNotEmpty,
      );
      final save = tester.widget<ButtonStyleButton>(
        find
            .ancestor(
              of: find.text('Save copy'),
              matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
            )
            .first,
      );
      save.onPressed!();
      save.onPressed!();
      await tester.pump();
      await settleImage(tester);
      expect(writes, 1);
      expect(find.text('Saving…'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoToolsScreen), findsOneWidget);
      pending.completeError(PlatformException(code: 'io'));
      await tester.pumpAndSettle();
      expect(find.text('Save copy'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Discard photo edits?'), findsOneWidget);
    },
  );
  testWidgets(
    'new project double tap creates one draft and opening is reversible',
    (tester) async {
      await start(tester);
      final pending = Completer<void>();
      var saves = 0;
      messenger.setMockMethodCallHandler(AndroidEditProjectRepository.channel, (
        call,
      ) async {
        if (call.method == 'save') {
          saves++;
          await pending.future;
          return null;
        }
        if (call.method == 'find') return jsonEncode(project.toJson());
        return <Object?>[];
      });
      router.go('/editor');
      await tester.pumpAndSettle();
      final card = tester.widget<BentoCard>(
        find.widgetWithText(BentoCard, 'New video project'),
      );
      card.onTap!();
      card.onTap!();
      await tester.pumpAndSettle();
      expect(saves, 0); // Opening/cancelling selection must not save a draft.
      expect(find.text('Choose media'), findsOneWidget);
      await tester.tap(find.text('Studio fixture 01.mp4'));
      await tester.pumpAndSettle();
      final add = tester.widget<FilledButton>(find.byType(FilledButton).last);
      add.onPressed!();
      add.onPressed!(); // A stale callback must not pop the editor branch.
      await tester.pump();
      expect(saves, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(EditorScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('New video project'), findsOneWidget);
    },
  );
  testWidgets(
    'project rename survives dialog exit and keyboard inset animation',
    (tester) async {
      await start(tester);
      router.push('/editor/project/ux');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Rename project'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'UI04 renamed project');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save name'));
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      expect(find.text('UI04 renamed project'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Rename project'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Cancelled title');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      expect(find.text('UI04 renamed project'), findsOneWidget);
      expect(find.text('Cancelled title'), findsNothing);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
    },
  );
  testWidgets('media rename survives Cancel/Save while the keyboard closes', (
    tester,
  ) async {
    await start(tester);
    final old = catalog.items.first;
    final item = MediaItem(
      id: old.id,
      uri: old.uri,
      kind: old.kind,
      displayName: old.displayName,
      mimeType: old.mimeType,
      sizeBytes: old.sizeBytes,
      createdAt: old.createdAt,
      modifiedAt: old.modifiedAt,
      source: old.source,
      owned: true,
    );
    catalog.items[0] = item;
    final renamed = <Object?>[];
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.xrecorder/media'),
      (call) async {
        if (call.method == 'rename') {
          renamed.add(call.arguments);
          return item.id;
        }
        return null;
      },
    );
    router.push('/media/${Uri.encodeComponent(item.id)}');
    await tester.pump();
    await settleImage(tester);
    for (final save in [false, true]) {
      final rename = find.widgetWithText(TextButton, 'Rename');
      await tester.ensureVisible(rename);
      await tester.tap(rename);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextField), 'UI05 media name.mp4');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(
        find.widgetWithText(TextButton, save ? 'Rename' : 'Cancel').last,
      );
      tester.view.resetViewInsets();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(renamed.length, save ? 1 : 0);
    }
    expect((renamed.single as Map)['name'], 'UI05 media name.mp4');
  });
  testWidgets(
    'editor waits for autosave and failed save keeps a recovery path before leaving',
    (tester) async {
      await start(tester);
      final pending = Completer<void>();
      messenger.setMockMethodCallHandler(AndroidEditProjectRepository.channel, (
        call,
      ) async {
        if (call.method == 'save') {
          await pending.future;
          throw PlatformException(code: 'io');
        }
        if (call.method == 'find') return jsonEncode(project.toJson());
        return <Object?>[];
      });
      router.push('/editor/project/ux');
      await tester.pumpAndSettle();
      final dynamic state = tester.state(find.byType(EditorScreen));
      state.controller.change(project.copyWith(title: 'Unsaved edits'));
      await tester.pump();
      await tester.tap(find.byTooltip('Back'));
      await tester.pump();
      expect(find.byType(EditorScreen), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Leave without saving?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Retry saving'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
