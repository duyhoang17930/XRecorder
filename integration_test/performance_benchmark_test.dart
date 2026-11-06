import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kProfileMode;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/editor/editor_preview.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/recording/recording_service.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';

import '../test/fixtures/visual_catalog.dart';
import 'recording_configuration_test.dart' show state;

class _Catalog extends VisualCatalog {
  _Catalog(super.image);
  int thumbnails = 0, lists = 0;
  @override
  Future<Uint8List> thumbnail(Uri uri) async {
    thumbnails++;
    return Uint8List.fromList(image); // Real platform replies have fresh bytes.
  }

  @override
  Future<List<MediaItem>> list({required MediaKind kind, Uri? folder}) {
    lists++;
    return super.list(kind: kind, folder: folder);
  }
}

class _CaptureProbe extends StatelessWidget {
  const _CaptureProbe(this.onBuild);
  final VoidCallback onBuild;
  @override
  Widget build(BuildContext context) {
    CaptureScope.of(context);
    onBuild();
    return const SizedBox.shrink();
  }
}

class _Motion extends StatefulWidget {
  const _Motion();
  @override
  State<_Motion> createState() => _MotionState();
}

class _MotionState extends State<_Motion> with SingleTickerProviderStateMixin {
  late final animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();
  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Align(
      alignment: Alignment.topRight,
      child: SizedBox(
        width: 96,
        height: 96,
        child: AnimatedBuilder(
          animation: animation,
          builder: (_, _) =>
              CustomPaint(painter: _MotionPaint(animation.value)),
        ),
      ),
    ),
  );
}

class _MotionPaint extends CustomPainter {
  const _MotionPaint(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF223344),
    );
    canvas.drawCircle(
      Offset(8 + t * 80, 24 + t * 48),
      8,
      Paint()..color = const Color(0xFFFF7948),
    );
    canvas.drawLine(
      const Offset(8, 80),
      Offset(8 + t * 80, 80),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_MotionPaint oldDelegate) => oldDelegate.t != t;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('Controlled profile benchmark; preserve all generated media', (
    tester,
  ) async {
    const label = String.fromEnvironment('PERF_LABEL', defaultValue: 'before');
    expect(
      kProfileMode,
      isTrue,
      reason: 'Do not benchmark debug-mode rendering.',
    );
    final platform =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String, int>{};
    final nativeTimes = <String, List<int>>{};
    void traceChannel(String name) {
      final original = MethodChannel(
        name,
        const StandardMethodCodec(),
        platform.delegate,
      );
      platform.setMockMethodCallHandler(MethodChannel(name), (call) async {
        final key =
            '${name.startsWith('com.xrecorder/editor_preview/') ? 'editor_preview' : name}/${call.method}';
        calls.update(key, (v) => v + 1, ifAbsent: () => 1);
        final clock = Stopwatch()..start();
        try {
          return await original.invokeMethod<Object?>(
            call.method,
            call.arguments,
          );
        } finally {
          (nativeTimes[key] ??= []).add(clock.elapsedMicroseconds);
        }
      });
    }

    for (final name in [
      'com.xrecorder/capture',
      'com.xrecorder/editor',
      'com.xrecorder/media',
    ]) {
      traceChannel(name);
    }
    final service = AndroidRecordingService();
    final media = AndroidMediaRepository();
    final initial = await service.currentSession();
    expect(
      initial == null ||
          [
            RecordingState.idle,
            RecordingState.failed,
            RecordingState.completed,
          ].contains(initial.state),
      isTrue,
      reason: 'Never interrupt an existing capture.',
    );
    final free = (await media.storage())['free']!;
    expect(
      free,
      greaterThan(512 * 1024 * 1024),
      reason: 'Require free space; no low-storage fault injection.',
    );
    final catalog = _Catalog(await fixtureImage());
    final settings = SettingsController()..setThemeMode(ThemeMode.dark);
    final samples = <Map<String, Object?>>[];
    final transitions = <Map<String, Object?>>[];
    final timelineClock = Stopwatch()..start();
    final subscription = service.sessions.listen(
      (s) => transitions.add({
        'id': s.id,
        'state': s.state.name,
        'screenshot': s.screenshot,
        'countdown': s.countdownRemaining.inSeconds,
        'atMs': timelineClock.elapsedMilliseconds,
      }),
    );
    final mountClock = Stopwatch()..start();
    await tester.pumpWidget(
      XRecorderApp(settings: settings, mediaRepository: catalog),
    );
    await tester.pumpAndSettle();
    final appMountMs = mountClock.elapsedMicroseconds / 1000;
    final context = tester.element(find.text('Video Library'));
    final capture = CaptureScope.of(context);
    final router = GoRouter.of(context);
    var probeBuilds = 0, notifications = 0;
    void notified() {
      notifications++;
    }

    capture.addListener(notified);
    final probe = OverlayEntry(
      builder: (_) => _CaptureProbe(() => probeBuilds++),
    );
    Overlay.of(context).insert(probe);
    await tester.pumpAndSettle();

    Future<void> measure(
      String name,
      int iteration,
      Future<void> Function() workload,
    ) async {
      debugPrint('PERF03_PHASE=$name:$iteration');
      final timings = <ui.FrameTiming>[];
      void frames(List<ui.FrameTiming> batch) {
        timings.addAll(batch);
      }

      final oldCalls = Map<String, int>.of(calls);
      final oldProbes = probeBuilds, oldNotices = notifications;
      final oldThumbs = catalog.thumbnails, oldLists = catalog.lists;
      final watch = Stopwatch()..start();
      SchedulerBinding.instance.addTimingsCallback(frames);
      await workload();
      await Future<void>.delayed(
        const Duration(milliseconds: 250),
      ); // Deliver the batched timing callback.
      SchedulerBinding.instance.removeTimingsCallback(frames);
      final imageCache = PaintingBinding.instance.imageCache;
      samples.add({
        'name': name,
        'iteration': iteration,
        'elapsedMs': watch.elapsedMicroseconds / 1000,
        'frames': timings
            .map(
              (f) => {
                'buildUs': f.buildDuration.inMicroseconds,
                'rasterUs': f.rasterDuration.inMicroseconds,
                'totalUs': f.totalSpan.inMicroseconds,
                'vsyncUs': f.vsyncOverhead.inMicroseconds,
              },
            )
            .toList(),
        'captureConsumerBuilds': probeBuilds - oldProbes,
        'captureNotifications': notifications - oldNotices,
        'thumbnailRequests': catalog.thumbnails - oldThumbs,
        'catalogLists': catalog.lists - oldLists,
        'platformCalls': {
          for (final e in calls.entries)
            if (e.value != (oldCalls[e.key] ?? 0))
              e.key: e.value - (oldCalls[e.key] ?? 0),
        },
        'imageCacheBytes': imageCache.currentSizeBytes,
        'imageCacheEntries': imageCache.currentSize,
      });
    }

    Future<void> settle() => tester.pumpAndSettle();
    Future<void> root() async {
      router.go('/videos');
      await settle();
      await tester.tap(find.text('Video'));
      await settle();
    }

    final ownOutputs = <Map<String, Object?>>[];
    try {
      for (var trial = 0; trial < 3; trial++) {
        await root();
        await measure('idle', trial, () async {
          await tester.pump(const Duration(seconds: 4));
          await settle();
        });
        await measure('navigation', trial, () async {
          for (final path in ['/photos', '/editor', '/settings', '/videos']) {
            router.go(path);
            await settle();
          }
          await tester.tap(find.byTooltip('Create'));
          await settle();
          await tester.tap(find.byTooltip('Close create menu'));
          await settle();
        });
        await measure('scroll', trial, () async {
          for (final direction in [-350.0, 350.0]) {
            for (var i = 0; i < 6; i++) {
              await tester.timedDrag(
                find.byType(Scrollable).first,
                Offset(0, direction),
                const Duration(milliseconds: 350),
              );
              await settle();
            }
          }
        });
        await root();
        await measure('search_sort', trial, () async {
          for (final text in ['Studio', 'Studio fixture 1', '']) {
            await tester.enterText(find.byType(TextField), text);
            await settle();
          }
          await tester.tap(find.text('Newest'));
          await settle();
          await tester.tap(find.text('Oldest'));
          await settle();
        });
        router.push('/exports');
        await settle();
        await measure('export_queue_idle', trial, () async {
          await tester.pump(const Duration(seconds: 5));
          await settle();
        });
        router.pop();
        await settle();
        await measure('capabilities', trial, () async {
          for (var i = 0; i < 3; i++) {
            final capabilities = service.capabilities();
            final heartbeat = Stopwatch()..start();
            await service.currentSession();
            samples.add({
              'name': 'main_thread_heartbeat',
              'iteration': trial,
              'elapsedMs': heartbeat.elapsedMicroseconds / 1000,
            });
            await capabilities;
          }
        });

        debugPrint('PERF03_RECORD_$trial');
        final request = await service.start(
          const RecordingSettings(
            width: 1280,
            height: 720,
            fps: 30,
            bitrate: 8000000,
            countdown: Duration.zero,
            audioSource: AudioSource.mute,
          ),
        );
        final startWatch = Stopwatch()..start();
        await state(service, RecordingState.recording);
        samples.add({
          'name': 'start_after_request',
          'iteration': trial,
          'elapsedMs': startWatch.elapsedMicroseconds / 1000,
          'note': 'Consent response included; inspect transition timeline for granted-to-recording.',
        });
        await settle();
        await measure('recording_static', trial, () async {
          await tester.pump(const Duration(seconds: 8));
          await settle();
        });
        final motion = OverlayEntry(builder: (_) => const _Motion());
        Overlay.of(tester.element(find.text('Video Library'))).insert(motion);
        await tester.pump();
        await measure('recording_motion_scroll', trial, () async {
          for (var i = 0; i < 4; i++) {
            await tester.timedDrag(
              find.byType(Scrollable).first,
              Offset(0, i.isEven ? -250 : 250),
              const Duration(milliseconds: 600),
            );
            await tester.pump(const Duration(milliseconds: 500));
          }
        });
        motion.remove();
        motion.dispose();
        if (trial == 2) {
          await measure('recording_90s_diagnostic', trial, () async {
            await tester.pump(const Duration(seconds: 90));
            await settle();
          });
        }
        await measure('pause', trial, () async {
          await service.pause(request.id);
          await state(service, RecordingState.paused);
          await settle();
        });
        await measure('paused_idle', trial, () async {
          await tester.pump(const Duration(seconds: 3));
          await settle();
        });
        await measure('resume', trial, () async {
          await service.resume(request.id);
          await state(service, RecordingState.recording);
          await settle();
        });
        RecordingSession? saved;
        await measure('stop_save', trial, () async {
          await service.stop(request.id);
          saved = await state(service, RecordingState.completed);
          await settle();
        });
        expect(saved!.id, request.id);
        final item = (await media.find(saved!.outputUri.toString()))!;
        expect(item.owned, isTrue);
        ownOutputs.add({
          'kind': 'video',
          'uri': item.uri.toString(),
          'name': item.displayName,
          'bytes': item.sizeBytes,
          'width': item.width,
          'height': item.height,
          'durationMs': item.duration?.inMilliseconds,
          'audio': item.hasAudio,
        });
        debugPrint('PERF03_OUTPUT=${jsonEncode(ownOutputs.last)}');

        final project = EditProject(
          id: 'perf03_${label}_${trial}_${DateTime.now().microsecondsSinceEpoch}',
          title: 'Performance diagnostic $label $trial',
          clips: [
            TimelineClip(
              mediaId: item.uri.toString(),
              sourceDuration: item.duration!,
              inPoint: Duration.zero,
              outPoint: const Duration(seconds: 2),
            ),
          ],
          updatedAt: DateTime.now(),
        );
        await AndroidEditProjectRepository().save(project);
        await measure('editor_entry', trial, () async {
          router.push('/editor/project/${project.id}');
          await settle();
        });
        final preview = tester.state<EditorPreviewState>(
          find.byType(EditorPreview),
        );
        expect(preview.channel, isNotNull);
        traceChannel(preview.channel!.name);
        await measure('editor_paused', trial, () async {
          await tester.pump(const Duration(seconds: 5));
          await settle();
        });
        await preview.command('play');
        await measure('editor_play', trial, () async {
          await tester.pump(const Duration(seconds: 1));
          await tester.pump();
        });
        await preview.command('pause');
        router.pop();
        await settle();
        String? jobId;
        await measure('export_2s', trial, () async {
          jobId = await AndroidEditProjectRepository.channel
              .invokeMethod<String>('exportStart', project.toJson());
          for (var i = 0; i < 180; i++) {
            final jobs = (jsonDecode(
              (await AndroidEditProjectRepository.channel.invokeMethod<String>(
                'exportList',
              ))!,
            ) as List).cast<Map<String, dynamic>>();
            final job = jobs.firstWhere((e) => e['id'] == jobId);
            if (job['state'] == 'failed') {
              fail('Diagnostic export failed: ${job['error']}');
            }
            if (job['state'] == 'completed') {
              final result = (await media.find(job['uri'] as String))!;
              expect(result.owned, isTrue);
              ownOutputs.add({
                'kind': 'export',
                'uri': result.uri.toString(),
                'name': result.displayName,
                'bytes': result.sizeBytes,
                'durationMs': result.duration?.inMilliseconds,
              });
              debugPrint('PERF03_OUTPUT=${jsonEncode(ownOutputs.last)}');
              break;
            }
            await tester.pump(const Duration(milliseconds: 250));
          }
        });
        await root();
        debugPrint('PERF03_SCREENSHOT_$trial');
        await capture.screenshot();
        final shot = await state(service, RecordingState.completed);
        expect(shot.screenshot, isTrue);
        final photo = (await media.find(shot.outputUri.toString()))!;
        expect(photo.owned, isTrue);
        ownOutputs.add({
          'kind': 'screenshot',
          'uri': photo.uri.toString(),
          'name': photo.displayName,
          'bytes': photo.sizeBytes,
          'width': photo.width,
          'height': photo.height,
        });
        debugPrint('PERF03_OUTPUT=${jsonEncode(ownOutputs.last)}');
        debugPrint('PERF03_RETURN_SHOT_$trial');
        for (
          var i = 0;
          i < 300 &&
              WidgetsBinding.instance.lifecycleState !=
                  AppLifecycleState.resumed;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await settle();
        expect(
          WidgetsBinding.instance.lifecycleState,
          AppLifecycleState.resumed,
        );
      }
      binding.reportData ??= {};
      binding.reportData!['performance03'] = {
        'label': label,
        'mode': 'profile',
        'iterations': 3,
        'catalogRows': 30,
        'appMountMs': appMountMs,
        'samples': samples,
        'nativeTimesUs': nativeTimes,
        'transitions': transitions,
        'outputs': ownOutputs,
        'retainedTestMedia': true,
        'freeStorageBefore': free,
      };
      debugPrint('PERF03_FINISHED');
    } finally {
      final last = await service.currentSession();
      if (last != null &&
          ![
            RecordingState.idle,
            RecordingState.completed,
            RecordingState.failed,
          ].contains(last.state)) {
        await service.cancel(last.id);
      }
      probe.remove();
      probe.dispose();
      capture.removeListener(notified);
      await subscription.cancel();
      await tester.pumpWidget(const SizedBox.shrink());
      media.dispose();
      // Deliberately retain verified test outputs and drafts. No destructive cleanup.
    }
  }, timeout: const Timeout(Duration(minutes: 12)));
}
