import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/widgets/studio_widgets.dart';

import 'fixtures/catalog.dart';

import 'package:xrecorder/features/editor/project_repository.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          AndroidEditProjectRepository.channel,
          (call) async => call.method == 'list' ? <Object?>[] : null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEditProjectRepository.channel, null);
  });
  Future<TestCatalog> start(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    TestCatalog? catalog,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = catalog ?? TestCatalog();
    await tester.pumpWidget(XRecorderApp(mediaRepository: repository));
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('Library date headings group by calendar day, not minute', (
    tester,
  ) async {
    final catalog = TestCatalog();
    catalog.items.clear();
    for (final (index, date) in [
      DateTime(2026, 11, 8, 11, 45),
      DateTime(2026, 11, 8, 12, 30),
      DateTime(2026, 11, 9, 12, 30),
    ].indexed) {
      catalog.items.add(
        MediaItem(
          id: 'content://test/date_$index',
          uri: Uri.parse('content://test/date_$index'),
          kind: MediaKind.video,
          displayName: 'Day clip $index.mp4',
          mimeType: 'video/mp4',
          sizeBytes: 2048,
          createdAt: date,
          modifiedAt: date,
          source: MediaSource.recording,
        ),
      );
    }
    await start(tester, catalog: catalog, size: const Size(1000, 1600));
    expect(find.byType(StudioSectionLabel), findsNWidgets(2));
    expect(find.text('11/8/2026'), findsOneWidget);
    expect(find.text('11/9/2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Library search survives tab navigation and real IDs open details',
    (tester) async {
      await start(tester);
      expect(find.text('Video Library'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Clip 0');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Clip 0.mp4'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Clip 0.mp4'), findsOneWidget);
      expect(find.text('Clip 1.mp4'), findsNothing);
      await tester.tap(find.text('Photo'));
      await tester.pumpAndSettle();
      expect(find.text('No screenshots yet'), findsOneWidget);
      await tester.tap(find.text('Video'));
      await tester.pumpAndSettle();
      expect(find.text('Clip 0.mp4'), findsOneWidget);
      expect(find.text('Clip 1.mp4'), findsNothing);
      await tester.ensureVisible(find.text('Clip 0.mp4'));
      await tester.tap(find.text('Clip 0.mp4'));
      await tester.pumpAndSettle();
      expect(find.text('Media details'), findsOneWidget);
      expect(find.byTooltip('Create'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Scroll position retained between primary tabs', (tester) async {
    await start(tester);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -450));
    await tester.pumpAndSettle();
    final offset = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .pixels;
    expect(offset, greaterThan(0));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      offset,
    );
  });
  testWidgets('Revoked access offers retry and recovers', (tester) async {
    final catalog = TestCatalog()
      ..failure = const DomainFailure(
        FailureCode.revoked,
        'Folder access revoked',
      );
    await start(tester, catalog: catalog);
    await tester.scrollUntilVisible(
      find.text('Folder access changed. Choose the folder again.'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Folder access changed. Choose the folder again.'),
      findsOneWidget,
    );
    catalog.failure = null;
    await tester.ensureVisible(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Clip 0.mp4'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Clip 0.mp4'), findsOneWidget);
  });
  testWidgets(
    'Folder cancellation keeps current library and storage is separate',
    (tester) async {
      await start(tester, catalog: TestCatalog()..cancelled = true);
      await tester.tap(find.text('Choose folder'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Clip 0.mp4'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Clip 0.mp4'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Storage'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Storage'));
      await tester.pumpAndSettle();
      expect(find.text('30.0 KiB'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Device free space'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Device free space'), findsOneWidget);
    },
  );
  testWidgets('Settings shared with recording setup and reset', (tester) async {
    await start(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Video quality'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('720p HD'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Create'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Screen recording'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '720p HD'))
          .selected,
      isTrue,
    );
    await tester.tap(find.byTooltip('Reset defaults'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '1080p FHD'))
          .selected,
      isTrue,
    );
  });
  testWidgets('Compact routes, large text, missing media and unknown routes', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await start(tester, size: const Size(360, 800));
    final router = GoRouter.of(tester.element(find.text('Video Library')));
    for (final path in [
      '/photos',
      '/editor',
      '/settings',
      '/settings/audio-video',
      '/media/missing',
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: path);
    }
    expect(find.text('Media unavailable'), findsOneWidget);
    router.go('/unknown');
    await tester.pumpAndSettle();
    expect(find.text('Page unavailable'), findsOneWidget);
  });
}
