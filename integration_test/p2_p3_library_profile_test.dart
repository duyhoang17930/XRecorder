import 'dart:convert';
import 'dart:io';
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
import 'package:xrecorder/l10n/localization.dart';

String _corpusRow(MediaItem row) =>
    '${row.id}:${row.sizeBytes}:${row.revision}';

// Optional benchmark fixture only: delegate every operation to the real native
// repository, retaining exactly the original rows without deleting later media.
class _ProfileCatalog extends AndroidMediaRepository {
  _ProfileCatalog(this.corpus);
  final Set<String>? corpus;
  int nativeItems = 0;
  @override
  Future<List<MediaItem>> list({required MediaKind kind, Uri? folder}) async {
    final rows = await super.list(kind: kind, folder: folder);
    if (kind != MediaKind.image) return rows;
    nativeItems = rows.length;
    return corpus == null
        ? rows
        : rows.where((row) => corpus!.contains(_corpusRow(row))).toList();
  }
}

Future<void> _profileFormats(
  WidgetTester tester,
  IntegrationTestWidgetsFlutterBinding binding,
) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (value) {
          context = value;
          return const SizedBox();
        },
      ),
    ),
  );
  final date = DateTime(2026, 11, 8, 12, 30);
  String format(int i) =>
      '${context.displayValue(date)} '
      '${context.fileSize(1234567 + i)} ${context.displayValue(i)}';
  for (var i = 0; i < 100; i++) {
    format(i);
  }
  final samples = <int>[];
  var checksum = 0;
  for (var round = 0; round < 5; round++) {
    final timer = Stopwatch()..start();
    for (var i = 0; i < 5000; i++) {
      checksum += format(i).length;
    }
    samples.add(timer.elapsedMicroseconds);
  }
  expect(checksum, greaterThan(0));
  binding.reportData = {
    'profileMode': kProfileMode,
    'iterationsPerRound': 5000,
    'roundsUs': samples,
    'checksum': checksum,
  };
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('PROFILE_FORMAT_ONLY')) {
    testWidgets(
      'Profile repeated localized library formatting',
      (tester) => _profileFormats(tester, binding),
    );
    return;
  }
  testWidgets('Profile continuous catalog scroll and bounded thumbnail cache', (
    tester,
  ) async {
    const corpusFile = String.fromEnvironment('PROFILE_CORPUS_FILE');
    Set<String>? corpus;
    if (corpusFile.isNotEmpty) {
      expect(
        RegExp(r'^task07_profile_[0-9]+\.json$').hasMatch(corpusFile),
        isTrue,
      );
      corpus = (jsonDecode(
        await File('/data/user/0/com.xrecorder.xrecorder/files/$corpusFile')
            .readAsString(),
      ) as List).cast<String>().toSet();
    }
    final repository = _ProfileCatalog(corpus);
    addTearDown(repository.dispose);
    final query = Stopwatch()..start();
    final rows = await repository.list(kind: MediaKind.image);
    query.stop();
    expect(rows.length, greaterThanOrEqualTo(1000));
    if (corpus != null) {
      expect(
        rows.map(_corpusRow).toSet(),
        corpus,
        reason:
            'Every original URI, size and revision must still exist unchanged.',
      );
    }
    final thumbnailTimes = <int>[];
    final thumbnailFailures = <String>[];
    for (final item in rows.take(10)) {
      final watch = Stopwatch()..start();
      try {
        await repository.thumbnail(item.uri);
      } on DomainFailure {
        // Preserve unreadable catalog entries, as the real library does.
        // A thumbnail preflight failure must be reported separately from scroll.
        thumbnailFailures.add(item.id);
      }
      thumbnailTimes.add(watch.elapsedMicroseconds);
    }
    final settings = SettingsController();
    settings.setThemeMode(
      const String.fromEnvironment('QA_THEME') == 'light'
          ? ThemeMode.light
          : ThemeMode.dark,
    );
    await tester.pumpWidget(
      XRecorderApp(settings: settings, mediaRepository: repository),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('Video Library'))).go('/photos');
    await tester.pumpAndSettle();
    final frames = <FrameTiming>[];
    void collect(List<FrameTiming> batch) => frames.addAll(batch);
    binding.addTimingsCallback(collect);
    await binding.traceAction(
      () async {
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
      },
      streams: ['Dart', 'Embedder', 'GC'],
      reportKey: 'scrollTimeline',
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
    binding.removeTimingsCallback(collect);
    final scope = tester.widget<MediaScope>(find.byType(MediaScope));
    expect(scope.thumbnails!.retainedBytes, lessThanOrEqualTo(8 * 1024 * 1024));
    binding.reportData = {
      ...?binding.reportData,
      'profileMode': kProfileMode,
      'items': rows.length,
      'nativeItems': repository.nativeItems,
      'benchmarkSubset': corpus != null,
      'queryUs': query.elapsedMicroseconds,
      'nativeThumbnailUs': thumbnailTimes,
      'thumbnailFailures': thumbnailFailures,
      'frames': frames.length,
      'buildUs': frames.map((f) => f.buildDuration.inMicroseconds).toList(),
      'rasterUs': frames.map((f) => f.rasterDuration.inMicroseconds).toList(),
      'cacheBytes': scope.thumbnails!.retainedBytes,
      'decodedCacheBytes': PaintingBinding.instance.imageCache.currentSizeBytes,
      'decodedCacheEntries': PaintingBinding.instance.imageCache.currentSize,
      'viewport': tester.view.physicalSize.toString(),
      'devicePixelRatio': tester.view.devicePixelRatio,
      'theme': settings.themeMode.name,
      'corpus': rows.map(_corpusRow).toList(),
      'outputsRetained': true,
    };
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }, timeout: const Timeout(Duration(minutes: 6)));
}
