import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/media/media_library_screen.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/media/media_sort.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';
import 'package:xrecorder/l10n/app_languages.dart';

String _identity(MediaItem item) =>
    '${item.id}:${item.sizeBytes}:${item.revision}';

class _Catalog extends AndroidMediaRepository {
  _Catalog(this.allowed);
  final Set<String> allowed;
  int nativeItems = 0, queries = 0, thumbnailReads = 0, thumbnailFailures = 0;

  @override
  Future<List<MediaItem>> list({required MediaKind kind, Uri? folder}) async {
    queries++;
    final rows = await super.list(kind: kind, folder: folder);
    if (kind != MediaKind.image || folder != null) return rows;
    nativeItems = rows.length;
    return rows.where((row) => allowed.contains(_identity(row))).toList();
  }

  @override
  Future<Uint8List> thumbnail(Uri uri) async {
    thumbnailReads++;
    try {
      return await super.thumbnail(uri);
    } catch (_) {
      thumbnailFailures++;
      rethrow;
    }
  }
}

// Local VM introspection only. Never emit its authenticated URI into reports.
Future<Map<String, dynamic>> _cpu(
  String method,
  Map<String, String> params,
) async {
  final uri = (await developer.Service.getInfo()).serverUri;
  if (uri == null) return {'unavailable': 'VM service disabled'};
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      uri.resolve(method).replace(queryParameters: params),
    );
    final response = await request.close();
    final data = jsonDecode(
      await utf8.decoder.bind(response).join(),
    ) as Map<String, dynamic>;
    if (data['error'] != null) {
      return {
        'unavailable': method,
        'errorCode': (data['error'] as Map)['code'],
      };
    }
    return Map<String, dynamic>.from(data['result'] as Map);
  } catch (error) {
    return {'unavailable': method, 'errorType': error.runtimeType.toString()};
  } finally {
    client.close(force: true);
  }
}

// The VM returns every compiled function, including tens of thousands never
// sampled. Keep the exact sampled stacks with a remapped, referenced table.
Map<String, dynamic> _compactCpu(Map<String, dynamic> profile) {
  if (profile['samples'] is! List || profile['functions'] is! List) {
    return profile;
  }
  final samples = profile['samples'] as List;
  final functions = profile['functions'] as List;
  final used = <int>{};
  for (final sample in samples.cast<Map>()) {
    used.addAll((sample['stack'] as List).cast<int>());
  }
  final indices = used.toList()..sort();
  final remap = {for (var i = 0; i < indices.length; i++) indices[i]: i};
  return {
    ...profile,
    'originalFunctionCount': functions.length,
    'functions': [for (final index in indices) functions[index]],
    'samples': [
      for (final sample in samples.cast<Map>())
        {
          ...sample,
          'stack': [for (final index in sample['stack'] as List) remap[index]!],
        },
    ],
  };
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('TASK08 same-corpus library warmup and five measured trials', (
    tester,
  ) async {
    expect(
      kProfileMode,
      isTrue,
      reason: 'Debug timings are not performance evidence.',
    );
    const manifest = String.fromEnvironment('TASK08_CORPUS');
    expect(RegExp(r'^task08_profile_[0-9]+\.json$').hasMatch(manifest), isTrue);
    final allowed = (jsonDecode(
      await File('/data/user/0/com.xrecorder.xrecorder/files/$manifest')
          .readAsString(),
    ) as List).cast<String>().toSet();
    expect(allowed.length, 1013);
    final repository = _Catalog(allowed);
    final settings = SettingsController();
    settings.setThemeMode(
      const String.fromEnvironment('QA_THEME') == 'light'
          ? ThemeMode.light
          : ThemeMode.dark,
    );
    settings.setAppLocale(
      AppLanguages.resolveSaved(
        const String.fromEnvironment('QA_LOCALE', defaultValue: 'en'),
      ),
    );
    addTearDown(repository.dispose);
    addTearDown(settings.dispose);
    final query = Stopwatch()..start();
    final rows = await repository.list(kind: MediaKind.image);
    query.stop();
    expect(
      rows.map(_identity).toSet(),
      allowed,
      reason: 'No deleted or changed original row may be omitted.',
    );
    final sorted = List<MediaItem>.of(rows)..sort(MediaSort.newest.compare);
    final metadata = [
      for (final row in sorted)
        {
          'id': row.id,
          'uri': row.uri.toString(),
          'bytes': row.sizeBytes,
          'revision': row.revision,
          'createdMs': row.createdAt.millisecondsSinceEpoch,
          'modifiedMs': row.modifiedAt.millisecondsSinceEpoch,
          'width': row.width,
          'height': row.height,
          'mime': row.mimeType,
        },
    ];
    final content = Stopwatch()..start();
    await tester.pumpWidget(
      XRecorderApp(settings: settings, mediaRepository: repository),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(MediaLibraryScreen).first))
        .go('/photos');
    await tester.pumpAndSettle();
    content.stop();
    final scope = tester.widget<MediaScope>(find.byType(MediaScope));
    final trials = <Map<String, Object?>>[];
    final isolate = developer.Service.getIsolateId(Isolate.current);
    binding.reportData = {
      'partial': true,
      'profile': kProfileMode,
      'corpus': metadata,
      'nativeItems': repository.nativeItems,
      'queryUs': query.elapsedMicroseconds,
      'testMountToContentUs': content.elapsedMicroseconds,
      'coldAndroidLaunch': false,
      'warmups': 3,
      'measurementTrials': 5,
      'viewport': {
        'widthPx': tester.view.physicalSize.width,
        'heightPx': tester.view.physicalSize.height,
        'dpr': tester.view.devicePixelRatio,
      },
      'theme': settings.themeMode.name,
      'locale': settings.appLocale?.toLanguageTag(),
    };
    if (const bool.fromEnvironment('TASK08_LIBRARY_SOAK')) {
      final cycles = <Map<String, Object?>>[];
      final allocations = <Map<String, dynamic>>[];
      for (var cycle = 0; cycle < 10; cycle++) {
        final router = GoRouter.of(
          tester.element(find.byType(MediaLibraryScreen).first),
        );
        router.go('/videos');
        await tester.pumpAndSettle();
        router.go('/photos');
        await tester.pumpAndSettle();
        tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
        await tester.pumpAndSettle();
        final queries = repository.queries;
        final cycleFrames = <FrameTiming>[];
        void collectCycle(List<FrameTiming> batch) => cycleFrames.addAll(batch);
        binding.addTimingsCallback(collectCycle);
        for (var swipe = 0; swipe < 30; swipe++) {
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
        binding.removeTimingsCallback(collectCycle);
        expect(cycleFrames, isNotEmpty);
        expect(repository.queries, queries);
        expect(scope.thumbnails!.length, lessThanOrEqualTo(64));
        expect(scope.thumbnails!.retainedBytes, lessThanOrEqualTo(8 * 1024 * 1024));
        cycles.add({
          'cycle': cycle + 1,
          'decodedEntries': PaintingBinding.instance.imageCache.currentSize,
          'decodedBytes': PaintingBinding.instance.imageCache.currentSizeBytes,
          'compressedEntries': scope.thumbnails!.length,
          'compressedBytes': scope.thumbnails!.retainedBytes,
          'buildUs': cycleFrames.map((f) => f.buildDuration.inMicroseconds).toList(),
          'rasterUs': cycleFrames.map((f) => f.rasterDuration.inMicroseconds).toList(),
        });
        if ([0, 4, 9].contains(cycle) && isolate != null) {
          allocations.add({
            'cycle': cycle + 1,
            'allocationProfileAfterGc': await _cpu('getAllocationProfile', {
              'isolateId': isolate,
              'gc': 'true',
            }),
          });
        }
        debugPrint('TASK08_LIBRARY_CYCLE=${cycle + 1}');
      }
      binding.reportData = {
        ...binding.reportData!,
        'partial': false,
        'kind': 'library_lifecycle_soak',
        'cycles': cycles,
        'allocations': allocations,
        'warmups': 0,
        'measurementTrials': 0,
        'frameBenchmark': false,
      };
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      return;
    }
    for (var iteration = 0; iteration < 8; iteration++) {
      final warmup = iteration < 3;
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(0);
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final queries = repository.queries;
      final thumbnails = repository.thumbnailReads;
      final frames = <FrameTiming>[];
      void collect(List<FrameTiming> batch) => frames.addAll(batch);
      if (!warmup && isolate != null) {
        await _cpu('clearCpuSamples', {'isolateId': isolate});
      }
      if (!warmup) binding.addTimingsCallback(collect);
      final origin = developer.Timeline.now;
      final watch = Stopwatch()..start();
      debugPrint('TASK08_PHASE=${warmup ? 'warmup' : 'trial'}_$iteration');
      Future<void> scroll() async {
        for (var swipe = 0; swipe < 30; swipe++) {
          await tester.timedDrag(
            find.byType(Scrollable).first,
            const Offset(0, -600),
            const Duration(milliseconds: 400),
            frequency: 60,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }

      if (warmup) {
        await scroll();
      } else {
        await binding.traceAction(
          scroll,
          streams: ['Dart', 'Embedder', 'GC'],
          reportKey: 'trial_${iteration - 3}',
        );
        // Keep one representative raw trace. Retaining five full timelines
        // makes the framework's final JSON serialization exceed the app heap.
        if (iteration > 3) binding.reportData!.remove('trial_${iteration - 3}');
      }
      watch.stop();
      final extent = developer.Timeline.now - origin;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!warmup) {
        binding.removeTimingsCallback(collect);
        final cpu = isolate == null || iteration != 3
            ? {'notSampled': 'Representative CPU profile is trial0 only'}
            : await _cpu('getCpuSamples', {
                'isolateId': isolate,
                'timeOriginMicros': '$origin',
                'timeExtentMicros': '$extent',
              });
        expect(frames, isNotEmpty);
        expect(
          repository.queries,
          queries,
          reason: 'Scrolling must not rescan MediaStore.',
        );
        expect(
          scope.thumbnails!.retainedBytes,
          lessThanOrEqualTo(8 * 1024 * 1024),
        );
        expect(scope.thumbnails!.length, lessThanOrEqualTo(64));
        trials.add({
          'index': iteration - 3,
          'elapsedUs': watch.elapsedMicroseconds,
          'buildUs': frames.map((f) => f.buildDuration.inMicroseconds).toList(),
          'rasterUs': frames
              .map((f) => f.rasterDuration.inMicroseconds)
              .toList(),
          'totalSpanUs': frames.map((f) => f.totalSpan.inMicroseconds).toList(),
          'cpu': _compactCpu(cpu),
          'scrollOffsetEnd': position.pixels,
          'thumbnailReads': repository.thumbnailReads - thumbnails,
          'cacheBytes': scope.thumbnails!.retainedBytes,
          'decodedCacheBytes':
              PaintingBinding.instance.imageCache.currentSizeBytes,
          'decodedCacheEntries':
              PaintingBinding.instance.imageCache.currentSize,
        });
        binding.reportData = {...binding.reportData!, 'trials': trials};
      }
    }
    binding.reportData = {
      ...binding.reportData!,
      'partial': false,
      'queries': repository.queries,
      'thumbnailFailures': repository.thumbnailFailures,
    };
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }, timeout: const Timeout(Duration(minutes: 20)));
}
