import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/media/media_actions.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/recording/recording_service.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';

import 'recording_configuration_test.dart' show state;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Consent, two one-shot PNGs, cleanup, feedback, and video/audio regression',
    (tester) async {
      final catalog = AndroidMediaRepository();
      final service = AndroidRecordingService();
      final actions = AndroidMediaActions();
      final before = (await catalog.list(kind: MediaKind.image))
          .map((e) => e.uri)
          .toSet();
      final created = <Uri>{};
      final timeline = <Map<String, Object?>>[];
      final clock = Stopwatch()..start();
      final subscription = service.sessions.listen((s) {
        timeline.add({
          'id': s.id,
          'screenshot': s.screenshot,
          'state': s.state.name,
          'countdown': s.countdownRemaining.inSeconds,
          'atMs': clock.elapsedMilliseconds,
        });
      });
      Future<void> waitFor(bool Function() predicate) async {
        for (var i = 0; i < 400; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (predicate()) return;
        }
        fail('Timed out waiting for host resume or visible catalog update.');
      }

      try {
        await tester.pumpWidget(
          XRecorderApp(
            mediaRepository: catalog,
            settings: SettingsController()..setThemeMode(ThemeMode.light),
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.text('Video Library'));
        final router = GoRouter.of(context);
        final capture = CaptureScope.of(context);
        for (final marker in ['TASK022_DENY', 'TASK022_BACK']) {
          debugPrint(marker);
          await tester.tap(find.text('Screenshot'));
          await tester.pump();
          await state(service, RecordingState.idle);
          await tester.pumpAndSettle();
          expect(
            (await catalog.list(kind: MediaKind.image))
                .map((e) => e.uri)
                .toSet(),
            before,
          );
          expect(capture.busy, isFalse);
          expect(find.text('Screenshot saved'), findsNothing);
          expect(find.text('Stop'), findsNothing);
        }
        final outputs = <Map<String, Object?>>[];
        for (var shot = 1; shot <= 2; shot++) {
          debugPrint('TASK022_CAPTURE_$shot');
          await tester.tap(find.text('Screenshot'));
          await tester.pump();
          await capture.screenshot(); // A repeated request while consent is pending must be ignored.
          final saved = await state(service, RecordingState.completed);
          expect(saved.screenshot, isTrue);
          created.add(saved.outputUri!);
          expect(before.contains(saved.outputUri), isFalse);
          final rows = await catalog.list(kind: MediaKind.image);
          expect(
            rows.map((e) => e.uri).where((uri) => !before.contains(uri)).length,
            shot,
          );
          final item = rows.singleWhere((e) => e.uri == saved.outputUri);
          final png = (await AndroidMediaRepository.channel
              .invokeMethod<Uint8List>('imageBytes', {
                'uri': item.uri.toString(),
              }))!;
          expect(png.take(8), orderedEquals([137, 80, 78, 71, 13, 10, 26, 10]));
          final codec = await ui.instantiateImageCodec(png);
          final image = (await codec.getNextFrame()).image;
          expect((image.width, image.height), (1080, 2400));
          final bytes = (await image.toByteData())!.buffer.asUint8List();
          final colors = <int>{};
          for (var i = 0; i + 3 < bytes.length; i += 4000) {
            colors.add((bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2]);
          }
          expect(colors.length, greaterThan(10));
          image.dispose();
          codec.dispose();
          outputs.add({
            'uri': item.uri.toString(),
            'mime': item.mimeType,
            'bytes': png.length,
            'width': 1080,
            'height': 2400,
          });
          final events = timeline.where((e) => e['id'] == saved.id).toList();
          expect(
            events
                .where((e) => e['state'] == 'countdown')
                .map((e) => e['countdown'])
                .toSet(),
            containsAll([3, 2, 1]),
          );
          expect(events.where((e) => e['state'] == 'recording'), isEmpty);
          final first =
              events.firstWhere((e) => e['state'] == 'countdown')['atMs']
                  as int;
          final capturing =
              events.firstWhere((e) => e['state'] == 'starting')['atMs'] as int;
          expect(capturing - first, greaterThanOrEqualTo(2800));
          if (shot == 1) {
            binding.reportData ??= {};
            binding.reportData!['nativeCapturePng'] = base64Encode(png);
          }
          debugPrint('TASK022_RETURN_$shot');
          await waitFor(
            () =>
                WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed,
          );
          router.go('/photos');
          await tester.pumpAndSettle();
          await waitFor(
            () => find.text(item.displayName).evaluate().isNotEmpty,
          );
          expect(find.text('Stop'), findsNothing);
          expect(find.text('Processing'), findsNothing);
          expect(find.text('Screenshot saved'), findsOneWidget);
          if (shot == 1) {
            await binding.convertFlutterSurfaceToImage();
            await tester.pumpAndSettle();
            await binding.takeScreenshot('01_real_saved_feedback');
            await tester.tap(find.text('View'));
            await tester.pumpAndSettle();
            expect(find.text('Photo preview'), findsOneWidget);
            expect(find.byType(InteractiveViewer), findsOneWidget);
            await binding.takeScreenshot('02_real_image_preview');
            router.pop();
          } else {
            await tester.pump(const Duration(seconds: 5));
            await tester.pumpAndSettle();
            expect(find.text('Screenshot saved'), findsNothing);
            await binding.takeScreenshot('03_feedback_expired');
          }
          router.go('/videos');
          await tester.pumpAndSettle();
        }
        debugPrint('TASK022_VIDEO');
        final request = await service.start(
          const RecordingSettings(
            width: 1280,
            height: 720,
            fps: 30,
            bitrate: 8000000,
            countdown: Duration.zero,
            audioSource: AudioSource.microphone,
          ),
        );
        await state(service, RecordingState.recording);
        await Future<void>.delayed(const Duration(seconds: 2));
        await service.pause(request.id);
        await state(service, RecordingState.paused);
        await Future<void>.delayed(const Duration(seconds: 1));
        await service.resume(request.id);
        await state(service, RecordingState.recording);
        await Future<void>.delayed(const Duration(seconds: 2));
        await service.stop(request.id);
        final video = await state(service, RecordingState.completed);
        created.add(video.outputUri!);
        final row = (await catalog.find(video.outputUri.toString()))!;
        expect(row.mimeType, 'video/mp4');
        expect(row.hasAudio, isTrue);
        expect(row.duration!.inMilliseconds, greaterThan(3000));
        await tester.pumpAndSettle();
        await waitFor(() => find.text(row.displayName).evaluate().isNotEmpty);
        debugPrint('TASK022_FINISHED');
        binding.reportData ??= {};
        binding.reportData!['screenshotVerification'] = {
          'outputs': outputs,
          'cancelAndBackWithoutFiles': true,
          'repeatedTapNoExtraOutput': true,
          'nativeCountdown321': true,
          'autoPhotoLibrary': true,
          'viewActualImage': true,
          'feedbackExpires': true,
          'videoPauseResumeAudioSaved': true,
          'videoDurationMs': row.duration!.inMilliseconds,
          'timeline': timeline,
        };
      } finally {
        final current = await service.currentSession();
        if (current != null &&
            ![
              RecordingState.idle,
              RecordingState.completed,
              RecordingState.failed,
            ].contains(current.state)) {
          await service.cancel(current.id);
        }
        await subscription.cancel();
        await tester.pumpWidget(const SizedBox.shrink());
        for (final uri
            in const bool.fromEnvironment('PRESERVE_TEST_OUTPUTS')
                ? <Uri>{}
                : created) {
          final raw = await actions.call<Map<Object?, Object?>>('find', {
            'id': uri.toString(),
          });
          if (raw != null) {
            final item = AndroidMediaRepository.decode(raw);
            expect(item.owned, isTrue);
            final trash = await actions.trash(item);
            await actions.permanentlyDelete(trash.id);
          }
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 7)),
  );
}
