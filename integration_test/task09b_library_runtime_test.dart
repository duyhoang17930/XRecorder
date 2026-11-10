import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

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

String _key(MediaItem row) => '${row.id}:${row.sizeBytes}:${row.revision}';

class _MeasuredCatalog extends AndroidMediaRepository {
  _MeasuredCatalog(this.corpus);
  final Set<String> corpus;
  int queries = 0, reads = 0, failures = 0, nativeRows = 0;
  @override
  Future<List<MediaItem>> list({required MediaKind kind, Uri? folder}) async {
    queries++;
    final result = await super.list(kind: kind, folder: folder);
    if (kind != MediaKind.image || folder != null) return result;
    nativeRows = result.length;
    return result.where((row) => corpus.contains(row.id)).toList();
  }

  @override
  Future<Uint8List> thumbnail(Uri uri) async {
    reads++;
    try {
      return await super.thumbnail(uri);
    } catch (_) {
      failures++;
      rethrow;
    }
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    '1013 real distinct image rows same-corpus Flutter frame trials and sorts',
    (tester) async {
      expect(kProfileMode, isTrue);
      binding.testTextInput.register();
      final report = <String, Object?>{
        'status': 'IN_PROGRESS',
        'profileMode': kProfileMode,
        'renderer': 'AVD SwiftShader; no physical GPU/FPS claim',
        'coldAndroidStartup': false,
      };
      binding.reportData = report;
      final plans =
          await Directory('/data/user/0/com.xrecorder.xrecorder/files')
              .list()
              .where(
                (entry) =>
                    entry is File &&
                    entry.path
                        .split('/')
                        .last
                        .startsWith('task09b_library_plan_f64203_') &&
                    entry.path.endsWith('.json'),
              )
              .cast<File>()
              .toList();
      plans.sort((a, b) => a.path.compareTo(b.path));
      final plan = plans.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(await plans.last.readAsString()) as Map<String, dynamic>;
      final mode = plan['mode'] as String? ?? 'benchmark';
      expect(mode, anyOf('controls', 'benchmark'));
      final controlsOnly = mode == 'controls';
      report.addAll({
        'mode': mode,
        'plan': plan,
        'planFile': plans.isEmpty ? null : plans.last.path,
      });
      final manifest = File(
        '/data/user/0/com.xrecorder.xrecorder/files/task09b_library_corpus_f64203.json',
      );
      final seed = AndroidMediaRepository();
      expect((await seed.storage())['free'], greaterThan(512 * 1024 * 1024));
      List<Map<String, dynamic>> metadata;
      try {
        if (!await manifest.exists()) {
          metadata = [];
          for (var i = 0; i < 1013; i++) {
            final portrait = i % 3 == 0;
            final width = portrait ? 360 : 640, height = portrait ? 640 : 360;
            final recorder = ui.PictureRecorder();
            final canvas = Canvas(recorder);
            canvas.drawColor(
              Color(0xff000000 | ((i * 7919) & 0x00ffffff)),
              BlendMode.src,
            );
            for (var n = 0; n < 12; n++) {
              canvas.drawCircle(
                Offset(
                  ((i * 13 + n * 71) % width).toDouble(),
                  ((i * 17 + n * 43) % height).toDouble(),
                ),
                (20 + (i + n * 7) % 80).toDouble(),
                Paint()
                  ..color = Color(
                    0xff000000 | (((i + n) * 104729) & 0x00ffffff),
                  ),
              );
            }
            final picture = recorder.endRecording();
            final image = await picture.toImage(width, height);
            picture.dispose();
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!.buffer.asUint8List();
            image.dispose();
            final uri = (await AndroidMediaRepository.channel
                .invokeMethod<String>('saveImage', {'bytes': bytes}))!;
            final row = (await seed.find(uri))!;
            expect(row.owned, isTrue);
            metadata.add({
              'id': row.id,
              'uri': uri,
              'key': _key(row),
              'name': row.displayName,
              'bytes': row.sizeBytes,
              'revision': row.revision,
              'width': row.width,
              'height': row.height,
            });
            if (i % 100 == 0) {
              debugPrint('TASK09B_REAL_CORPUS_CREATED=${i + 1}');
            }
          }
          await manifest.create(exclusive: true);
          await manifest.writeAsString(jsonEncode(metadata), flush: true);
        } else {
          metadata = (jsonDecode(await manifest.readAsString()) as List)
              .cast<Map<String, dynamic>>();
        }
      } finally {
        seed.dispose();
      }
      expect(metadata.length, 1013);
      final allowedIds = metadata.map((v) => v['id'] as String).toSet();
      expect(allowedIds.length, 1013);
      final repository = _MeasuredCatalog(allowedIds);
      final query = Stopwatch()..start();
      final initialRows = await repository.list(kind: MediaKind.image);
      expect(initialRows.map((row) => row.id).toSet(), allowedIds);
      final originalById = {for (final row in metadata) row['id']: row};
      for (final row in initialRows) {
        expect(row.sizeBytes, originalById[row.id]!['bytes']);
        expect(row.displayName, originalById[row.id]!['name']);
      }
      // `find` returns optional revision=null; `list` supplies MediaStore's
      // generation. Select fixtures by stable URI and compare generations
      // from the same list API before/after instead of conflating both DTOs.
      final allowed = initialRows.map(_key).toSet();
      query.stop();
      final reusedSnapshot = plan['snapshotDirectory'] as String?;
      final sourceBackup = reusedSnapshot == null
          ? await Directory('/data/user/0/com.xrecorder.xrecorder/files')
                .createTemp('task09b_library_sources_')
          : Directory(reusedSnapshot);
      expect(
        sourceBackup.path,
        startsWith(
          '/data/user/0/com.xrecorder.xrecorder/files/task09b_library_sources_',
        ),
      );
      report['sourceSnapshotDirectory'] = sourceBackup.path;
      expect(
        RegExp(
          r'^/data/user/0/com\.xrecorder\.xrecorder/files/task09b_library_sources_[A-Za-z0-9]+$',
        ).hasMatch(sourceBackup.path),
        isTrue,
      );
      // Read through the app's legitimate ContentResolver bridge. run-as does
      // not have Gallery filesystem access; never grant/bypass that boundary.
      for (final row in initialRows) {
        final source = (await AndroidMediaRepository.channel
            .invokeMethod<Uint8List>('imageBytes', {
              'uri': row.uri.toString(),
            }))!;
        expect(source.length, row.sizeBytes);
        final file = File(
          '${sourceBackup.path}/${row.uri.pathSegments.last}.png',
        );
        if (reusedSnapshot == null) {
          await file.create(exclusive: true);
          await file.writeAsBytes(source, flush: true);
        } else {
          expect(source, orderedEquals(await file.readAsBytes()));
        }
      }
      final sourceManifest = File('${sourceBackup.path}/manifest.json');
      if (reusedSnapshot == null) {
        await sourceManifest.create(exclusive: true);
        await sourceManifest.writeAsString(jsonEncode(metadata), flush: true);
      } else {
        expect(jsonDecode(await sourceManifest.readAsString()), metadata);
      }
      final settings = SettingsController()
        ..setThemeMode(ThemeMode.dark)
        ..setAppLocale(const Locale('en'));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      final trials = <Map<String, Object?>>[];
      try {
        final mount = Stopwatch()..start();
        await tester.pumpWidget(
          XRecorderApp(settings: settings, mediaRepository: repository),
        );
        await tester.pumpAndSettle();
        final router = GoRouter.of(
          tester.element(find.byType(MediaLibraryScreen).first),
        );
        router.go('/photos');
        await tester.pumpAndSettle();
        mount.stop();
        final scope = tester.widget<MediaScope>(find.byType(MediaScope));
        final scrollable = find.byType(Scrollable).first;
        final scroll = tester.state<ScrollableState>(scrollable).position;
        report.addAll({
          'corpusFile': manifest.path,
          'corpus': metadata,
          'realNativeRows': repository.nativeRows,
          'queryUs': query.elapsedMicroseconds,
          'mountToPhotoContentUs': mount.elapsedMicroseconds,
          'physicalPixels': [
            tester.view.physicalSize.width,
            tester.view.physicalSize.height,
          ],
          'dpr': tester.view.devicePixelRatio,
          'viewport': [
            MediaQuery.sizeOf(tester.element(scrollable)).width,
            MediaQuery.sizeOf(tester.element(scrollable)).height,
          ],
          'textScale': 2,
          'warmupTrials': controlsOnly ? 0 : 2,
          'measuredTrials': controlsOnly ? 0 : 3,
        });
        final firstPhoto = (List<MediaItem>.of(
          initialRows,
        )..sort(MediaSort.newest.compare)).first;
        await tester.scrollUntilVisible(
          find.text(firstPhoto.displayName),
          180,
          maxScrolls: 50,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        final rowInk = find
            .ancestor(
              of: find.text(firstPhoto.displayName),
              matching: find.byType(InkWell),
            )
            .first;
        report['rowSplashFactory'] =
            (tester.widget<InkWell>(rowInk).splashFactory ??
                    Theme.of(tester.element(rowInk)).splashFactory)
                .runtimeType
                .toString();
        report['isolatedThumbnailPaint'] = find
            .byKey(ValueKey('library-thumbnail-${firstPhoto.id}'))
            .evaluate()
            .isNotEmpty;
        if (plan['expectedThumbnailBoundary'] is bool) {
          expect(
            report['isolatedThumbnailPaint'],
            plan['expectedThumbnailBoundary'],
          );
        }
        if (plan['expectedSplashFactory'] is String) {
          expect(
            report['rowSplashFactory'],
            contains(plan['expectedSplashFactory'] as String),
          );
        }
        for (var trial = 0; trial < (controlsOnly ? 0 : 5); trial++) {
          scroll.jumpTo(0);
          await tester.pumpAndSettle();
          await Future<void>.delayed(const Duration(milliseconds: 600));
          final frames = <ui.FrameTiming>[];
          void collect(List<ui.FrameTiming> batch) => frames.addAll(batch);
          final queries = repository.queries, reads = repository.reads;
          final failures = repository.failures;
          final measured = trial >= 2;
          if (measured) binding.addTimingsCallback(collect);
          for (var swipe = 0; swipe < 30; swipe++) {
            await tester.timedDrag(
              scrollable,
              const Offset(0, -500),
              const Duration(milliseconds: 350),
              frequency: 60,
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await Future<void>.delayed(const Duration(milliseconds: 600));
          if (measured) {
            binding.removeTimingsCallback(collect);
            expect(frames, isNotEmpty);
            expect(
              repository.queries,
              queries,
              reason: 'Scroll must not rescan MediaStore.',
            );
            expect(scope.thumbnails!.length, lessThanOrEqualTo(64));
            expect(
              repository.failures,
              failures,
              reason: 'Healthy image corpus must not add thumbnail failures.',
            );
            expect(
              scope.thumbnails!.retainedBytes,
              lessThanOrEqualTo(8 * 1024 * 1024),
            );
            trials.add({
              'index': trial - 2,
              'buildUs': frames
                  .map((v) => v.buildDuration.inMicroseconds)
                  .toList(),
              'rasterUs': frames
                  .map((v) => v.rasterDuration.inMicroseconds)
                  .toList(),
              'totalSpanUs': frames
                  .map((v) => v.totalSpan.inMicroseconds)
                  .toList(),
              'scrollEnd': scroll.pixels,
              'thumbnailReads': repository.reads - reads,
              'thumbnailFailuresDuringTrial': repository.failures - failures,
              'compressedCacheEntries': scope.thumbnails!.length,
              'compressedCacheBytes': scope.thumbnails!.retainedBytes,
              'decodedCacheBytes':
                  PaintingBinding.instance.imageCache.currentSizeBytes,
            });
            debugPrint(
              'TASK09B_FRAME_TRIAL=${trial - 2} frames=${frames.length}',
            );
          }
        }
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        var selected = MediaSort.newest;
        final sorts = <String>[];
        for (final sort in MediaSort.values.where(
          (value) => value != MediaSort.duration,
        )) {
          final chip = find.widgetWithText(ActionChip, selected.label);
          await tester.ensureVisible(chip);
          await tester.pumpAndSettle();
          await tester.tap(chip);
          await tester.pumpAndSettle();
          final option = find.text(sort.label).last;
          await tester.ensureVisible(option);
          await tester.pumpAndSettle();
          expect(option.hitTestable(), findsOneWidget);
          await tester.tap(option);
          await tester.pumpAndSettle();
          expect(find.widgetWithText(ActionChip, sort.label), findsOneWidget);
          final expectedOrder = await repository.list(kind: MediaKind.image);
          expectedOrder.sort(sort.compare);
          await tester.ensureVisible(
            find.text(expectedOrder.first.displayName).first,
          );
          expect(find.text(expectedOrder.first.displayName), findsWidgets);
          selected = sort;
          sorts.add(sort.label);
        }
        final search = find.byType(TextField);
        await tester.ensureVisible(search);
        await tester.enterText(search, 'TASK09B_NO_MATCH_1000');
        await tester.pumpAndSettle();
        expect(find.text('Search results'), findsOneWidget);
        expect(
          tester.widget<TextField>(search).controller!.text,
          'TASK09B_NO_MATCH_1000',
        );
        router.go('/settings');
        await tester.pumpAndSettle();
        router.go('/photos');
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(search).controller!.text,
          'TASK09B_NO_MATCH_1000',
        );
        await tester.enterText(search, '');
        await tester.pumpAndSettle();
        expect(
          (await repository.list(kind: MediaKind.image)).map(_key).toSet(),
          allowed,
        );
        router.go('/videos');
        await tester.pumpAndSettle();
        final videos = await repository.list(kind: MediaKind.video);
        expect(videos.length, greaterThan(1));
        selected = MediaSort.newest;
        final videoSorts = <String>[];
        for (final sort in MediaSort.values) {
          final chip = find.widgetWithText(ActionChip, selected.label);
          await tester.ensureVisible(chip);
          await tester.pumpAndSettle();
          await tester.tap(chip);
          await tester.pumpAndSettle();
          final option = find.text(sort.label).last;
          await tester.ensureVisible(option);
          await tester.pumpAndSettle();
          expect(option.hitTestable(), findsOneWidget);
          await tester.tap(option);
          await tester.pumpAndSettle();
          expect(find.widgetWithText(ActionChip, sort.label), findsOneWidget);
          selected = sort;
          videoSorts.add(sort.label);
          final expectedOrder = List<MediaItem>.of(videos)..sort(sort.compare);
          expect(find.text(expectedOrder.first.displayName), findsWidgets);
        }
        for (final row in initialRows) {
          final source = (await AndroidMediaRepository.channel
              .invokeMethod<Uint8List>('imageBytes', {
                'uri': row.uri.toString(),
              }))!;
          expect(
            source,
            orderedEquals(
              await File(
                '${sourceBackup.path}/${row.uri.pathSegments.last}.png',
              ).readAsBytes(),
            ),
          );
        }
        report.addAll({
          'status': 'PASS',
          'sortsInteracted': sorts,
          'videoSortsInteracted': videoSorts,
          'searchAndTabRetention': true,
          'thumbnailFailures': repository.failures,
          'sourceMetadataExactAfter': true,
          'sourceBytesExactAll1013': true,
        });
      } finally {
        binding.reportData = {
          ...report,
          'trials': trials,
          'fixturesRetained': true,
        };
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      }
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
