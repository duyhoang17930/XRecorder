import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';

import '../test/fixtures/visual_catalog.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    '1000 native image catalog entries scroll and refresh without losing sources',
    (tester) async {
      final catalog = AndroidMediaRepository();
      final free = (await catalog.storage())['free']!;
      expect(free, greaterThan(128 * 1024 * 1024));
      final bytes = await fixtureImage();
      final before = (await catalog.list(kind: MediaKind.image)).length;
      String? last;
      for (var i = before; i < 1000; i++) {
        last = await AndroidMediaRepository.channel.invokeMethod<String>(
          'saveImage',
          {'bytes': bytes},
        );
        if (i % 250 == 0) {
          debugPrint('P2_P3_STRESS_GENERATED=${i - before + 1}');
        }
      }
      expect(
        (await catalog.list(kind: MediaKind.image)).length,
        greaterThanOrEqualTo(1000),
      );
      final settings = SettingsController()..setThemeMode(ThemeMode.light);
      await tester.pumpWidget(
        XRecorderApp(settings: settings, mediaRepository: catalog),
      );
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.text('Video Library'))).go('/photos');
      await tester.pumpAndSettle();
      final timings = <int>[];
      final frames = <FrameTiming>[];
      void collect(List<FrameTiming> batch) => frames.addAll(batch);
      binding.addTimingsCallback(collect);
      for (var i = 0; i < 30; i++) {
        final watch = Stopwatch()..start();
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -450));
        await tester.pumpAndSettle();
        timings.add(watch.elapsedMilliseconds);
        expect(tester.takeException(), isNull);
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
      binding.removeTimingsCallback(collect);
      final scope = tester.widget<MediaScope>(find.byType(MediaScope));
      expect(
        scope.thumbnails!.retainedBytes,
        lessThanOrEqualTo(8 * 1024 * 1024),
      );
      await binding.convertFlutterSurfaceToImage();
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        settings.setThemeMode(mode);
        await tester.tap(find.text('Photo'));
        await tester.pumpAndSettle();
        for (var i = 0; i < 25 && find.byType(Image).evaluate().isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          await tester.pump();
        }
        expect(find.byType(Image), findsWidgets);
        await binding.takeScreenshot('library_${mode.name}');
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        await tester.pumpAndSettle();
        await binding.takeScreenshot('library_${mode.name}_text200');
        expect(tester.takeException(), isNull);
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      }
      if (last != null) {
        expect(
          await AndroidMediaRepository.channel.invokeMethod('imageBytes', {
            'uri': last,
          }),
          orderedEquals(bytes),
        );
      }
      binding.reportData = {
        ...binding.reportData ?? {},
        'items': (await catalog.list(kind: MediaKind.image)).length,
        'newFixtures': before < 1000 ? 1000 - before : 0,
        'swipes': 30,
        'debugSwipeAndSettleMs': timings,
        'profileMode': kProfileMode,
        'physicalSize': tester.view.physicalSize.toString(),
        'devicePixelRatio': tester.view.devicePixelRatio,
        'frameBuildUs': frames
            .map((f) => f.buildDuration.inMicroseconds)
            .toList(),
        'frameRasterUs': frames
            .map((f) => f.rasterDuration.inMicroseconds)
            .toList(),
        'compressedCacheBytes': scope.thumbnails!.retainedBytes,
        'outputsRetained': true,
      };
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
