import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/media/media_actions.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/recording/recording_service.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';

import '../test/fixtures/visual_catalog.dart' show fixtureImage;
import 'recording_configuration_test.dart' show state;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Real screenshot, publish, export, folder import, delete and restore update the library',
    (tester) async {
      final catalog = AndroidMediaRepository();
      final service = AndroidRecordingService();
      final actions = AndroidMediaActions();
      final before = {
        ...(await catalog.list(kind: MediaKind.video)).map((e) => e.uri),
        ...(await catalog.list(kind: MediaKind.image)).map((e) => e.uri),
      };
      final created = <Uri>{};
      final observations = <String, Object?>{};
      Future<void> waitFor(
        bool Function() predicate, {
        int attempts = 150,
      }) async {
        for (var i = 0; i < attempts; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (predicate()) return;
        }
        fail(
          'Expected library update did not arrive. No manual refresh was used.',
        );
      }

      Future<MediaItem> own(Uri uri) async {
        expect(before.contains(uri), isFalse);
        created.add(uri);
        return (await catalog.find(uri.toString()))!;
      }

      try {
        await tester.pumpWidget(
          XRecorderApp(
            mediaRepository: catalog,
            settings: SettingsController(),
          ),
        );
        await tester.pumpAndSettle();
        final router = GoRouter.of(tester.element(find.text('Video Library')));
        router.go('/photos');
        await tester.pumpAndSettle();
        router.go('/videos');
        await tester.pumpAndSettle();
        debugPrint('TASK021_SHOT_CONSENT');
        await tester.tap(find.text('Screenshot'));
        await tester.pump();
        final shot = await state(service, RecordingState.completed);
        expect(shot.screenshot, isTrue);
        final photo = await own(shot.outputUri!);
        expect(photo.mimeType, 'image/png');
        final png = await AndroidMediaRepository.channel
            .invokeMethod<Uint8List>('imageBytes', {
              'uri': photo.uri.toString(),
            });
        expect(png!.take(8), orderedEquals([137, 80, 78, 71, 13, 10, 26, 10]));
        final decoder = await ui.instantiateImageCodec(png);
        final image = (await decoder.getNextFrame()).image;
        final rgba = (await image.toByteData())!.buffer.asUint8List();
        final colors = <int>{};
        for (var i = 0; i + 3 < rgba.length; i += 4000) {
          colors.add((rgba[i] << 16) | (rgba[i + 1] << 8) | rgba[i + 2]);
        }
        expect(
          colors.length,
          greaterThan(10),
          reason: 'The real screenshot must contain screen content, not a blank bitmap.',
        );
        observations['screenshot'] = {
          'mime': photo.mimeType,
          'bytes': photo.sizeBytes,
          'width': image.width,
          'height': image.height,
          'pngDecoded': true,
          'noSetupNavigation':
              router.routeInformationProvider.value.uri.path == '/videos',
        };
        image.dispose();
        decoder.dispose();
        binding.reportData ??= {};
        binding.reportData!['nativeCapturePng'] = base64Encode(png);
        router.go('/photos');
        await tester.pumpAndSettle();
        await waitFor(() => find.text(photo.displayName).evaluate().isNotEmpty);
        final addedUri = Uri.parse(
          (await AndroidMediaRepository.channel.invokeMethod<String>(
            'saveImage',
            {'bytes': await fixtureImage()},
          ))!,
        );
        final added = await own(addedUri);
        await waitFor(() => find.text(added.displayName).evaluate().isNotEmpty);
        observations['imageObserverWithoutExplicitRefresh'] = true;

        router.go('/videos');
        await tester.pumpAndSettle();
        final count = (await catalog.list(kind: MediaKind.video)).length;
        debugPrint('TASK021_VIDEO_CONSENT');
        final request = await service.start(
          const RecordingSettings(
            width: 1280,
            height: 720,
            fps: 30,
            bitrate: 8000000,
            audioSource: AudioSource.mute,
            countdown: Duration.zero,
          ),
        );
        await state(service, RecordingState.recording);
        expect(
          (await catalog.list(kind: MediaKind.video)).length,
          count,
          reason: 'Pending output must stay hidden.',
        );
        await Future<void>.delayed(const Duration(seconds: 4));
        await service.stop(request.id);
        final saved = await state(service, RecordingState.completed);
        final video = await own(saved.outputUri!);
        await waitFor(() => find.text(video.displayName).evaluate().isNotEmpty);
        observations['recording'] = {
          'bytes': video.sizeBytes,
          'durationMs': video.duration!.inMilliseconds,
          'pendingHidden': true,
          'automaticLibraryUpdate': true,
        };

        final project = EditProject(
          id: 'task021-${DateTime.now().microsecondsSinceEpoch}',
          title: 'Task 02.1 export',
          clips: [
            TimelineClip(
              mediaId: video.uri.toString(),
              inPoint: Duration.zero,
              outPoint: const Duration(seconds: 2),
              sourceDuration: video.duration!,
            ),
          ],
          updatedAt: DateTime.now(),
        );
        final jobId = await AndroidEditProjectRepository.channel
            .invokeMethod<String>('exportStart', project.toJson());
        Uri? exportUri;
        for (var i = 0; i < 180; i++) {
          final jobs = (jsonDecode(
            (await AndroidEditProjectRepository.channel.invokeMethod<String>(
              'exportList',
            ))!,
          ) as List).cast<Map<String, dynamic>>();
          final job = jobs.firstWhere((row) => row['id'] == jobId);
          if (job['state'] == 'failed') {
            fail('Native export failed: ${job['error']}');
          }
          if (job['state'] == 'completed') {
            exportUri = Uri.parse(job['uri'] as String);
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        expect(exportUri, isNotNull);
        final exported = await own(exportUri!);
        await waitFor(
          () => find.text(exported.displayName).evaluate().isNotEmpty,
        );
        observations['exportUpdatesWhileQueueClosed'] = true;

        await tester.tap(find.text('Video'));
        await tester.pumpAndSettle();
        debugPrint('TASK021_FOLDER_CONSENT');
        await tester.tap(find.text('Choose folder'));
        await tester.pump();
        await waitFor(
          () => tester
              .widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, 'Choose folder'),
              )
              .selected,
          attempts: 900,
        );
        Uri? folder;
        for (var i = 0; i < 180; i++) {
          folder = await catalog.savedFolder();
          if (folder != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        expect(folder, isNotNull);
        expect(
          Uri.decodeComponent(folder.toString()),
          contains('Movies/XRecorder'),
        );
        final folderRows = await catalog.list(
          kind: MediaKind.video,
          folder: folder,
        );
        expect(
          folderRows.any((item) => item.displayName == video.displayName),
          isTrue,
        );
        await tester.scrollUntilVisible(
          find.text(video.displayName),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Video'));
        await tester.pumpAndSettle();
        debugPrint('TASK021_IMPORT_SOURCE=${video.displayName}');
        await waitFor(
          () => find.text('Task021_Imported.mp4').evaluate().isNotEmpty,
        );
        final imported = (await catalog.list(
          kind: MediaKind.video,
          folder: folder,
        )).firstWhere((item) => item.displayName == 'Task021_Imported.mp4');
        expect((await catalog.find(imported.id))!.owned, isFalse);
        observations['folderImportOnResumeReadOnly'] = true;
        await tester.tap(find.text('Video'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('App media'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(video.displayName),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Task021_Imported.mp4'), findsNothing);
        final entry = await actions.trash(video);
        created.remove(video.uri);
        await waitFor(() => find.text(video.displayName).evaluate().isEmpty);
        final restored = await actions.restore(entry.id);
        await own(restored.uri);
        await waitFor(
          () => find.text(restored.displayName).evaluate().isNotEmpty,
        );
        observations['deleteAndRestoreUpdateWithoutManualRefresh'] = true;
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('01_real_media_library');
        binding.reportData ??= {};
        binding.reportData!['nativeVerification'] = observations;
        expect(tester.takeException(), isNull);
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
        await tester.pumpWidget(const SizedBox.shrink());
        for (final uri in created) {
          final row = await actions.call<Map<Object?, Object?>>('find', {
            'id': uri.toString(),
          });
          if (row != null) {
            final item = AndroidMediaRepository.decode(row);
            final entry = await actions.trash(item);
            await actions.permanentlyDelete(entry.id);
          }
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 7)),
  );
}
