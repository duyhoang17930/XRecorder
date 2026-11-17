import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/core/constants/app_icons.dart';
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
    await (FontLoader('packages/iconsax_flutter/FlutterIconsax')..addFont(
          rootBundle.load('packages/iconsax_flutter/fonts/FlutterIconsax.ttf'),
        ))
        .load();
  });
  setUp(() {
    messenger.setMockMethodCallHandler(
      AndroidRecordingService.commands,
      (call) async => switch (call.method) {
        'current' => {'id': '', 'state': 'idle'},
        'overlayPermissionStatus' => false,
        _ => {
          'presets': [],
          'audioSources': ['mute'],
        },
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
    GoRouter.of(tester.element(find.text('Video library')))
        .push('/media/${Uri.encodeComponent(catalog.items.single.id)}');
    await tester.pumpAndSettle();
    final button = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Rename'),
    );
    button.onTap!();
    button.onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Rename media'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.widgetWithText(ListTile, 'Rename'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Rename'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Rename media'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
  testWidgets(
    'Trash shows when an item was moved and describes manual actions',
    (tester) async {
      final deletedAt = DateTime(2026, 1, 2, 3, 4).millisecondsSinceEpoch;
      messenger.setMockMethodCallHandler(
        const MethodChannel('com.xrecorder/media'),
        (call) async => call.method == 'listTrash'
            ? <Object?>[
                {
                  'id': '00000000-0000-0000-0000-000000000009',
                  'originalMetadata': {
                    'id': 'content://media/external/images/media/999999',
                    'uri': 'content://media/external/images/media/999999',
                    'name': 'prompt05_expired_fixture.png',
                    'mime': 'image/png',
                    'size': 64,
                    'created': deletedAt,
                    'modified': deletedAt,
                    'source': 'recording',
                    'owned': true,
                  },
                  'deletedAt': deletedAt,
                  'expiresAt': deletedAt,
                },
              ]
            : null,
      );
      await tester.pumpWidget(XRecorderApp(mediaRepository: TestCatalog()));
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.text('Video library'))).push('/trash');
      await tester.pumpAndSettle();

      expect(find.text('prompt05_expired_fixture.png'), findsOneWidget);
      expect(find.textContaining('In Trash since'), findsOneWidget);
      expect(
        find.textContaining('Items stay in Trash until you restore them'),
        findsOneWidget,
      );
      expect(find.textContaining('Expires'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('sort sheet shows custom choices and applies selection', (
    tester,
  ) async {
    await tester.pumpWidget(XRecorderApp(mediaRepository: TestCatalog()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ActionChip, 'Newest'));
    await tester.pumpAndSettle();

    expect(find.text('Sort media'), findsOneWidget);
    for (final sort in ['newest', 'oldest', 'name', 'size', 'duration']) {
      expect(find.byKey(ValueKey('media-sort-$sort')), findsOneWidget);
    }
    expect(find.byIcon(AppIcons.sortNewest), findsOneWidget);
    expect(find.byIcon(AppIcons.sortOldest), findsOneWidget);
    expect(find.byIcon(AppIcons.sortName), findsOneWidget);
    expect(find.byIcon(AppIcons.sortSize), findsOneWidget);
    expect(find.byIcon(AppIcons.sortDuration), findsOneWidget);
    expect(
      tester
          .widget<Semantics>(find.byKey(const ValueKey('media-sort-newest')))
          .properties
          .selected,
      isTrue,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('media-sort-newest')),
        matching: find.byIcon(AppIcons.check),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('media-sort-oldest')),
        matching: find.byIcon(AppIcons.chevronRight),
      ),
      findsNothing,
    );
    for (final sort in ['newest', 'oldest', 'name', 'size', 'duration']) {
      expect(
        tester.getSize(find.byKey(ValueKey('media-sort-$sort'))).height,
        greaterThanOrEqualTo(48),
      );
    }

    final durationOption = find.byKey(const ValueKey('media-sort-duration'));
    await tester.ensureVisible(durationOption);
    await tester.pumpAndSettle();
    await tester.tap(durationOption);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, 'Longest'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('restores a persisted SAF folder when Library opens', (
    tester,
  ) async {
    final folder = Uri.parse(
      'content://com.android.externalstorage.documents/tree/qa_folder',
    );
    final catalog = TestCatalog()
      ..selection = folder
      ..items.clear();

    await tester.pumpWidget(XRecorderApp(mediaRepository: catalog));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextButton, 'Disconnect folder'),
      findsOneWidget,
    );
    expect(find.text('No videos in this folder'), findsOneWidget);
    expect(catalog.listedFolders, contains(folder));
    expect(tester.takeException(), isNull);
  });
  testWidgets('picker cancellation does not strand initial folder restore', (
    tester,
  ) async {
    final savedFolder = Completer<Uri?>();
    final catalog = TestCatalog()
      ..savedFolderRequest = savedFolder.future
      ..cancelled = true;

    await tester.pumpWidget(XRecorderApp(mediaRepository: catalog));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Choose folder'));
    await tester.pump();
    savedFolder.complete(Uri.parse('content://provider/tree/qa'));
    await tester.pumpAndSettle();

    expect(catalog.listedFolders, contains(null));
    expect(find.widgetWithText(TextButton, 'Disconnect folder'), findsNothing);
    expect(find.text('15 items'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 411.0]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('sort sheet fits $width dp in ${theme.name} at 200%', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        await tester.pumpWidget(
          XRecorderApp(
            settings: SettingsController()..setThemeMode(theme),
            mediaRepository: TestCatalog(),
          ),
        );
        await tester.pumpAndSettle();
        final sortChip = find.widgetWithText(ActionChip, 'Newest');
        await tester.ensureVisible(sortChip);
        await tester.pumpAndSettle();
        await tester.tap(sortChip);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('media-sort-newest')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('media-sort-duration')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
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
            tester.element(find.text('Video library')),
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
