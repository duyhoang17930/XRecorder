import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/app/theme/app_theme.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/presentation/thumbnail_cache.dart';
import 'package:xrecorder/core/presentation/thumbnail_image.dart';
import 'package:xrecorder/features/editor/editor_preview.dart';
import 'package:xrecorder/features/editor/export_screen.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/media/media_library_screen.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

import 'fixtures/catalog.dart';
import 'fixtures/recorder.dart';
import 'fixtures/visual_catalog.dart';

class _CaptureConsumer extends StatelessWidget {
  const _CaptureConsumer(this.onBuild);
  final VoidCallback onBuild;
  @override
  Widget build(BuildContext context) {
    final capture = CaptureScope.of(context);
    onBuild();
    return Text('${capture.session?.elapsedActive.inSeconds}');
  }
}

class _Preview extends EditorPreview {
  const _Preview({required super.project, required super.onPosition});
  @override
  EditorPreviewState createState() => _PreviewState();
}

class _PreviewState extends EditorPreviewState {
  int builds = 0;
  @override
  Widget build(BuildContext context) {
    builds++;
    return Text(playing ? 'Playing' : 'Paused');
  }
}

class _Thumbnails extends TestCatalog {
  _Thumbnails(this.bytes);
  final Uint8List bytes;
  int reads = 0;
  @override
  Future<Uint8List> thumbnail(Uri uri) async {
    reads++;
    return Uint8List.fromList(bytes);
  }
}

void main() {
  testWidgets('thumbnail decoded content keys preserve resized RGBA pixels', (tester) async {
    final bytes = (await tester.runAsync(fixtureImage))!;
    Future<(int, int, Uint8List)> decode(ImageProvider provider) async {
      final ready = Completer<ImageInfo>();
      final stream = provider.resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener(
        (image, synchronous) {
          if (!ready.isCompleted) {
            ready.complete(image);
          } else {
            image.dispose();
          }
        },
        onError: (Object error, StackTrace? stack) => ready.completeError(error, stack),
      );
      stream.addListener(listener);
      ImageInfo? frame;
      try {
        frame = await ready.future.timeout(const Duration(seconds: 5));
        final rgba = (await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        return (frame.image.width, frame.image.height, rgba.buffer.asUint8List());
      } finally {
        stream.removeListener(listener);
        frame?.dispose();
      }
    }

    final expected = (await tester.runAsync(() => decode(
      ResizeImage.resizeIfNeeded(100, null, MemoryImage(bytes)),
    )))!;
    final actual = (await tester.runAsync(() => decode(
      ResizeImage.resizeIfNeeded(100, null, ThumbnailImage(Uint8List.fromList(bytes))),
    )))!;
    expect((actual.$1, actual.$2), (expected.$1, expected.$2));
    expect(actual.$3, isNotEmpty);
    expect(actual.$3, orderedEquals(expected.$3));
  });
  test('thumbnail decoded key checks bytes and scale, not buffer identity', () {
    final a = ThumbnailImage(Uint8List.fromList([1, 2, 3]));
    final b = ThumbnailImage(Uint8List.fromList([1, 2, 3]));
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(ThumbnailImage(Uint8List.fromList([1, 2, 4]))));
    expect(a, isNot(ThumbnailImage(Uint8List.fromList([1, 2, 3]), scale: 2)));
    final ordinary = MemoryImage(a.bytes);
    expect(a == ordinary, isFalse);
    expect(ordinary == a, isFalse);
  });
  test(
    'thumbnail cache coalesces in-flight reads and failures can retry',
    () async {
      final cache = ThumbnailCache();
      var reads = 0;
      final pending = Completer<Uint8List>();
      Future<Uint8List> read() {
        reads++;
        return pending.future;
      }

      final a = cache.load('one', read), b = cache.load('one', read);
      expect(identical(a, b), isTrue);
      pending.complete(Uint8List(4));
      expect(await a, same(await b));
      expect(reads, 1);
      await expectLater(
        cache.load('failed', () async => throw StateError('read failed')),
        throwsStateError,
      );
      expect(
        await cache.load('failed', () async => Uint8List(3)),
        hasLength(3),
      );
    },
  );
  test('thumbnail cache bounds bytes, evicts least recently used, and clear rejects late repopulation', () async {
    final cache = ThumbnailCache(maxEntries: 2, maxBytes: 8);
    var reads = 0;
    Future<Uint8List> read() async {
      reads++;
      return Uint8List(4);
    }

    await cache.load('a', read);
    await cache.load('b', read);
    await cache.load('a', read);
    await cache.load('c', read);
    expect(cache.length, 2);
    expect(cache.retainedBytes, 8);
    await cache.load('b', read);
    expect(reads, 4);
    final pending = Completer<Uint8List>();
    final late = cache.load('late', () => pending.future);
    cache.clear();
    pending.complete(Uint8List(8));
    await late;
    expect(cache.length, 0);
    expect(cache.retainedBytes, 0);
    await cache.load('oversized', () async => Uint8List(9));
    expect(cache.retainedBytes, lessThanOrEqualTo(8));
  });
  testWidgets(
    'capture consumers repaint on visible seconds; raw listeners retain precise snapshots',
    (tester) async {
      final service = TestRecorder()..current = null;
      final capture = CaptureController(service, onSaved: () {});
      var builds = 0, raw = 0;
      capture.addListener(() => raw++);
      try {
        await tester.pumpWidget(
          CaptureScope(
            controller: capture,
            child: MaterialApp(home: _CaptureConsumer(() => builds++)),
          ),
        );
        await tester.pump();
        RecordingSession value(RecordingState state, int ms) =>
            RecordingSession(
              id: 'clock',
              state: state,
              configSnapshot: const RecordingSettings(),
              elapsedActive: Duration(milliseconds: ms),
            );
        service.events.add(value(RecordingState.recording, 0));
        await tester.pump();
        await tester.pump();
        final start = builds;
        for (var i = 1; i <= 8; i++) {
          service.current = value(RecordingState.recording, i * 250);
          service.events.add(service.current!);
          await tester.pump();
          await tester.pump();
          expect(capture.session!.elapsedActive.inMilliseconds, i * 250);
        }
        expect(raw, greaterThanOrEqualTo(9));
        expect(builds - start, 2);
        expect(find.text('2'), findsOneWidget);
        service.events.add(value(RecordingState.paused, 2000));
        await tester.pump();
        await tester.pump();
        final paused = builds;
        for (var i = 0; i < 8; i++) {
          service.events.add(value(RecordingState.paused, 2000));
          await tester.pump();
        }
        expect(builds, paused);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        capture.dispose();
        await service.events.close();
      }
    },
  );
  testWidgets(
    'thumbnail re-entry reuses bytes; revision and repository change invalidate the image',
    (tester) async {
      final image = (await tester.runAsync(fixtureImage))!;
      final a = _Thumbnails(image), b = _Thumbnails(image);
      final cache = ThumbnailCache();
      final old = a.items.first;
      Future<void> show(_Thumbnails repository, MediaItem item) async {
        await tester.pumpWidget(
          MediaScope(
            repository: repository,
            thumbnails: cache,
            child: MaterialApp(
              theme: AppTheme.dark,
              home: Scaffold(body: MediaThumbnail(item: item)),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      try {
        await show(a, old);
        expect(a.reads, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        await show(a, old);
        expect(a.reads, 1);
        final revised = MediaItem(
          id: old.id,
          uri: old.uri,
          kind: old.kind,
          displayName: old.displayName,
          mimeType: old.mimeType,
          sizeBytes: old.sizeBytes,
          createdAt: old.createdAt,
          modifiedAt: old.modifiedAt,
          source: old.source,
          revision: 2,
        );
        await show(a, revised);
        expect(a.reads, 2);
        cache.clear(); // The app owner clears on repository changes/pressure.
        await show(b, revised);
        expect(b.reads, 1);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        a.dispose();
        b.dispose();
      }
    },
  );
  testWidgets(
    'decoded thumbnails reuse identical content after compressed cache eviction',
    (tester) async {
      final bytes = (await tester.runAsync(fixtureImage))!;
      final repository = _Thumbnails(bytes);
      final cache = ThumbnailCache();
      final decoded = PaintingBinding.instance.imageCache;
      decoded.clear();
      decoded.clearLiveImages();
      Object? first;
      try {
        for (var i = 0; i < 10; i++) {
          await tester.pumpWidget(
            MediaScope(
              repository: repository,
              thumbnails: cache,
              child: MaterialApp(
                theme: AppTheme.dark,
                home: Scaffold(
                  body: SizedBox(
                    width: 100,
                    height: 60,
                    child: MediaThumbnail(item: repository.items.first),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final image = tester.widget<Image>(find.byType(Image));
          final key = await image.image.obtainKey(ImageConfiguration.empty);
          first ??= key;
          expect(key, first, reason: 'Same encoded pixels must share a decoded key.');
          await tester.runAsync(() async {
            final decodedFrame = Completer<void>();
            final stream = image.image.resolve(ImageConfiguration.empty);
            final listener = ImageStreamListener(
              (frame, synchronous) {
                frame.dispose();
                if (!decodedFrame.isCompleted) decodedFrame.complete();
              },
              onError: (Object error, StackTrace? stack) {
                if (!decodedFrame.isCompleted) decodedFrame.completeError(error, stack);
              },
            );
            stream.addListener(listener);
            try {
              await decodedFrame.future.timeout(const Duration(seconds: 5));
            } finally {
              stream.removeListener(listener);
            }
          });
          await tester.pumpWidget(const SizedBox.shrink());
          cache.clear(); // Simulate the real bounded compressed LRU evicting it.
        }
        expect(repository.reads, 10);
        expect(decoded.currentSize, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        decoded.clear();
        decoded.clearLiveImages();
        repository.dispose();
      }
    },
  );
  testWidgets(
    'exports stop polling terminal jobs and refresh on foreground and route return',
    (tester) async {
      var calls = 0;
      var response = '[]';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidEditProjectRepository.channel, (
            call,
          ) async {
            if (call.method == 'exportList') {
              calls++;
              return response;
            }
            return null;
          });
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.dark, home: const ExportScreen()),
      );
      await tester.pumpAndSettle();
      final initial = calls;
      await tester.pump(const Duration(seconds: 5));
      expect(calls, initial);
      final navigator = Navigator.of(tester.element(find.text('Exports')));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Other screen')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(calls, initial);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(calls, initial + 1);
      final state =
          tester.state(find.byType(ExportScreen)) as WidgetsBindingObserver;
      state.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 3));
      expect(calls, initial + 1);
      response = jsonEncode([
        {
          'id': 'job',
          'state': 'running',
          'progress': 0,
          'project': {'title': 'Test export'},
        },
      ]);
      state.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      final active = calls;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(calls, active + 1);
      response = jsonEncode([
        {
          'id': 'job',
          'state': 'completed',
          'progress': 100,
          'uri': 'content://test/export',
          'project': {'title': 'Test export'},
        },
      ]);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final complete = calls;
      await tester.pump(const Duration(seconds: 5));
      expect(calls, complete);
      expect(find.text('Saved · 100%'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'export list read failure retries while visible and disposal cancels timers',
    (tester) async {
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidEditProjectRepository.channel, (
            _,
          ) async {
            calls++;
            if (calls == 1) throw PlatformException(code: 'io');
            return '[]';
          });
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.dark, home: const ExportScreen()),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
      expect(calls, 2);
    },
  );
  testWidgets(
    'preview aspect follows crop/rotation and ignores stale metadata',
    (tester) async {
      const previewChannel = MethodChannel('preview-aspect');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final delayed = Completer<Map<String, Object>>();
      var reads = 0;
      messenger.setMockMethodCallHandler(previewChannel, (_) async => null);
      messenger.setMockMethodCallHandler(AndroidMediaRepository.channel, (
        _,
      ) async {
        reads++;
        return reads == 1 ? {'width': 1920, 'height': 1080} : delayed.future;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(previewChannel, null);
        messenger.setMockMethodCallHandler(
          AndroidMediaRepository.channel,
          null,
        );
      });
      final project = EditProject(
        id: 'aspect',
        updatedAt: DateTime(2026),
        clips: [
          TimelineClip(
            mediaId: 'content://test/portrait',
            inPoint: Duration.zero,
            outPoint: const Duration(seconds: 4),
            sourceDuration: const Duration(seconds: 4),
            cropRight: .5,
            rotation: 90,
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: _Preview(project: project, onPosition: (_) {}),
        ),
      );
      final state = tester.state<_PreviewState>(find.byType(_Preview))
        ..channel = previewChannel;
      await state.load();
      await tester.pump();
      expect(state.aspectRatio, closeTo(9 / 8, .0001));
      await state.load();
      await tester.pumpWidget(
        MaterialApp(
          home: _Preview(
            project: project.copyWith(effects: {'aspect': 1.0}),
            onPosition: (_) {},
          ),
        ),
      );
      await tester.pump();
      expect(state.aspectRatio, 1);
      delayed.complete({'width': 360, 'height': 640});
      await tester.pump();
      expect(state.aspectRatio, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'a delayed preview snapshot cannot replace the playhead after reload',
    (tester) async {
      const channel = MethodChannel('preview-delayed');
      final pending = Completer<Map<String, Object>>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => call.method == 'state' ? pending.future : null,
          );
      final positions = <Duration>[];
      final project = EditProject(
        id: 'delayed',
        updatedAt: DateTime(2026),
        clips: [
          TimelineClip(
            mediaId: 'content://test/video',
            inPoint: Duration.zero,
            outPoint: const Duration(seconds: 4),
            sourceDuration: const Duration(seconds: 4),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: _Preview(project: project, onPosition: positions.add),
        ),
      );
      final preview = tester.state<_PreviewState>(find.byType(_Preview))
        ..channel = channel;
      final oldPoll = preview.poll();
      await tester.pump();
      await preview.load(position: const Duration(seconds: 1));
      pending.complete({'positionMs': 3000, 'playing': true});
      await oldPoll;
      expect(positions, isEmpty);
      expect(preview.playing, false);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('an immediate effect edit preserves the latest requested seek', (
    tester,
  ) async {
    const channel = MethodChannel('preview-seek-then-edit');
    final seeks = <int>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'seek') seeks.add(call.arguments as int);
      // Media3 can still report its previous position immediately after seek.
      if (call.method == 'state') return {'positionMs': 2000, 'playing': false};
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final project = EditProject(
      id: 'seek-then-edit',
      updatedAt: DateTime(2026),
      clips: [
        TimelineClip(
          mediaId: 'content://test/video',
          inPoint: Duration.zero,
          outPoint: const Duration(seconds: 4),
          sourceDuration: const Duration(seconds: 4),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: _Preview(project: project, onPosition: (_) {}),
      ),
    );
    final preview = tester.state<_PreviewState>(find.byType(_Preview))
      ..channel = channel;
    await preview.load(position: const Duration(seconds: 2));
    await preview.command('seek', 1500);
    await tester.pumpWidget(
      MaterialApp(
        home: _Preview(
          project: project.copyWith(effects: {'voice': 'deep'}),
          onPosition: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(seeks.last, 1500);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'preview unchanged snapshots do not rebuild; seek/play/pause still update and background stops queries',
    (tester) async {
      const channel = MethodChannel('preview-test');
      var polls = 0, nativePosition = 0, nativePlaying = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'state') {
              polls++;
              return {'positionMs': nativePosition, 'playing': nativePlaying};
            }
            if (call.method == 'play') nativePlaying = true;
            if (call.method == 'pause') nativePlaying = false;
            if (call.method == 'seek') nativePosition = call.arguments as int;
            return null;
          });
      final positions = <Duration>[];
      final project = EditProject(
        id: 'preview',
        clips: [],
        updatedAt: DateTime(2026),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: _Preview(project: project, onPosition: positions.add),
        ),
      );
      final preview = tester.state<_PreviewState>(find.byType(_Preview))
        ..channel = channel;
      for (var i = 0; i < 10; i++) {
        await preview.poll();
        await tester.pump();
      }
      expect(positions, [Duration.zero]);
      expect(preview.builds, 1);
      await preview.command('play');
      await tester.pump();
      expect(find.text('Playing'), findsOneWidget);
      await preview.command('seek', 1234);
      await tester.pump();
      expect(positions.last.inMilliseconds, 1234);
      preview.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump();
      final paused = polls;
      for (var i = 0; i < 10; i++) {
        await preview.poll();
      }
      expect(polls, paused);
      preview.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(find.text('Paused'), findsOneWidget);
      expect(polls, paused + 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
