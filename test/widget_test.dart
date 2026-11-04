import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/core/widgets/studio_widgets.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';

void main() {
  Future<void> start(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const XRecorderApp());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Library, record sheet, honest sample result, details and editor navigation',
    (tester) async {
      await start(tester);
      expect(find.text('Recorded Clips'), findsOneWidget);
      await tester.tap(find.byTooltip('Record'));
      await tester.pumpAndSettle();
      expect(find.text('Recording Parameters'), findsOneWidget);
      await tester.ensureVisible(find.text('Start Recording'));
      await tester.tap(find.text('Start Recording'));
      await tester.pumpAndSettle();
      expect(find.text('Recording engine not connected'), findsOneWidget);
      await tester.tap(find.text('View sample result'));
      await tester.pumpAndSettle();
      expect(
        find.text('Sample result · No recording was created'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Preview sample'));
      await tester.pumpAndSettle();
      expect(find.text('Media Item Detail'), findsOneWidget);
      await tester.tap(find.byTooltip('Preview sample'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Video playback is not available'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Edit in Studio'));
      await tester.tap(find.text('Edit in Studio'));
      await tester.pumpAndSettle();
      expect(find.text('Editing Studio'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Photo navigation and favorite filter change sample content', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.text('Photo'));
    await tester.pumpAndSettle();
    expect(find.text('Photo Gallery'), findsOneWidget);
    await tester.tap(find.byTooltip('Favorite photo').first);
    await tester.ensureVisible(find.text('Favorites'));
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(find.text('CyberStrike_04.png'), findsOneWidget);
    expect(find.text('debug_stack_01.png'), findsNothing);
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    final offset = position.pixels;
    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Photo'));
    await tester.pumpAndSettle();
    expect(find.text('CyberStrike_04.png'), findsOneWidget);
    expect(find.text('debug_stack_01.png'), findsNothing);
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      offset,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Settings configuration is shared with recording setup and resets',
    (tester) async {
      await start(tester);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Resolution & Video Quality'));
      await tester.tap(find.text('Resolution & Video Quality'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('720p HD'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Record'));
      await tester.pumpAndSettle();
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, '720p HD'),
      );
      expect(chip.selected, isTrue);
      await tester.tap(find.byTooltip('Reset defaults'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '1080p FHD'))
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'All baseline routes scroll without overflow on compact viewport',
    (tester) async {
      await start(tester, size: const Size(320, 640));
      final context = tester.element(find.byType(MockBanner).first);
      final router = GoRouter.of(context);
      for (final route in [
        '/videos/empty',
        '/photos',
        '/editor',
        '/settings',
        '/settings/audio-video',
        '/recording/completed',
        '/media/apex',
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
        final scroll = find.byType(Scrollable).first;
        for (var i = 0; i < 6; i++) {
          await tester.drag(scroll, const Offset(0, -400));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$route scroll $i');
        }
      }
    },
  );

  testWidgets('Routes and missing media handle large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await start(tester, size: const Size(360, 800));
    final router = GoRouter.of(tester.element(find.byType(MockBanner).first));
    for (final route in [
      '/photos',
      '/editor',
      '/settings',
      '/settings/audio-video',
      '/media/missing',
    ]) {
      router.go(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
    }
    expect(find.text('Media unavailable'), findsOneWidget);
    expect(find.byTooltip('Record'), findsNothing);
    router.go('/unknown');
    await tester.pumpAndSettle();
    expect(find.text('Page unavailable'), findsOneWidget);
  });

  test('Session settings notify and restore defaults', () {
    final settings = SettingsController();
    var notifications = 0;
    settings.addListener(() => notifications++);
    settings.update(() {
      settings.fps = '30';
      settings.hardware = false;
    });
    expect(settings.fps, '30');
    expect(notifications, 1);
    settings.reset();
    expect(settings.fps, '60');
    expect(settings.hardware, isTrue);
    expect(notifications, 2);
    settings.dispose();
  });
}
