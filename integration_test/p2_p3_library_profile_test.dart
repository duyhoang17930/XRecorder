import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Profile continuous catalog scroll and bounded thumbnail cache', (
    tester,
  ) async {
    final repository = AndroidMediaRepository();
    final query = Stopwatch()..start();
    final rows = await repository.list(kind: MediaKind.image);
    query.stop();
    expect(rows.length, greaterThanOrEqualTo(1000));
    final thumbnailTimes = <int>[];
    for (final item in rows.take(10)) {
      final watch = Stopwatch()..start();
      await repository.thumbnail(item.uri);
      thumbnailTimes.add(watch.elapsedMicroseconds);
    }
    final settings = SettingsController();
    await tester.pumpWidget(
      XRecorderApp(settings: settings, mediaRepository: repository),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('Video Library'))).go('/photos');
    await tester.pumpAndSettle();
    final frames = <FrameTiming>[];
    void collect(List<FrameTiming> batch) => frames.addAll(batch);
    binding.addTimingsCallback(collect);
    for (var i = 0; i < 30; i++) {
      await tester.timedDrag(
        find.byType(Scrollable).first,
        const Offset(0, -600),
        const Duration(milliseconds: 400),
        frequency: 60,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    binding.removeTimingsCallback(collect);
    final scope = tester.widget<MediaScope>(find.byType(MediaScope));
    expect(scope.thumbnails!.retainedBytes, lessThanOrEqualTo(8 * 1024 * 1024));
    binding.reportData = {
      'profileMode': kProfileMode,
      'items': rows.length,
      'queryUs': query.elapsedMicroseconds,
      'nativeThumbnailUs': thumbnailTimes,
      'frames': frames.length,
      'buildUs': frames.map((f) => f.buildDuration.inMicroseconds).toList(),
      'rasterUs': frames.map((f) => f.rasterDuration.inMicroseconds).toList(),
      'cacheBytes': scope.thumbnails!.retainedBytes,
      'outputsRetained': true,
    };
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }, timeout: const Timeout(Duration(minutes: 6)));
}
