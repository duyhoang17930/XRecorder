import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/media/media_actions.dart';

import '../test/fixtures/visual_catalog.dart';

import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/editor/editor_preview.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'P2 native saved image, auto catalog, rename, missing URI and source preservation',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('P2/P3 synthetic media verification')),
        ),
      );
      final catalog = AndroidMediaRepository();
      final actions = AndroidMediaActions();
      addTearDown(catalog.dispose);
      const channel = AndroidMediaRepository.channel;
      final changed = Completer<void>();
      final subscription = catalog.changes.listen((_) {
        if (!changed.isCompleted) changed.complete();
      });
      addTearDown(subscription.cancel);
      // Register the app collection fingerprint before writing; no capture permissions needed.
      await catalog.list(kind: MediaKind.image);
      final bytes = await fixtureImage();
      final uri = await channel.invokeMethod<String>('saveImage', {
        'bytes': bytes,
      });
      expect(uri, isNotNull);
      await changed.future.timeout(const Duration(seconds: 10));
      final source = (await catalog.find(uri!))!;
      expect(source.owned, isTrue);
      expect(source.width, 320);
      expect(source.height, 180);
      expect(source.sizeBytes, bytes.length);
      expect(
        (await catalog.list(kind: MediaKind.image)).any((e) => e.id == uri),
        isTrue,
      );
      final name = 'P2_fixture_${DateTime.now().microsecondsSinceEpoch}';
      final renamed = await actions.rename(source.uri, name);
      expect((await catalog.find(renamed))!.displayName, '$name.png');
      final read = await channel.invokeMethod<Uint8List>('imageBytes', {
        'uri': renamed,
      });
      expect(read, orderedEquals(bytes));
      await expectLater(
        actions.rename(source.uri, '../invalid'),
        throwsA(isA<DomainFailure>()),
      );
      final missing = await catalog.find(
        'content://media/external/images/media/999999999',
      );
      expect(missing, isNull);
      expect((await catalog.storage())['free'], greaterThan(0));
      expect((await catalog.find(renamed))!.sizeBytes, source.sizeBytes);
      final draft = EditProject(
        id: 'native_photo_${DateTime.now().microsecondsSinceEpoch}',
        title: 'P3 still-photo fixture',
        effects: const bool.fromEnvironment('P2_P3_SUBTITLES')
            ? {
                'subtitles': [
                  {'startMs': 100, 'endMs': 500, 'text': 'Xin chào'},
                  {'startMs': 1100, 'endMs': 1800, 'text': 'Tiếng Việt'},
                ],
              }
            : const {},
        updatedAt: DateTime.now(),
        clips: [
          TimelineClip(
            mediaId: renamed,
            isImage: true,
            inPoint: Duration.zero,
            outPoint: const Duration(seconds: 1),
            sourceDuration: const Duration(seconds: 1),
            rotation: 90,
            flipH: true,
          ),
          TimelineClip(
            mediaId: renamed,
            isImage: true,
            inPoint: Duration.zero,
            outPoint: const Duration(seconds: 1),
            sourceDuration: const Duration(seconds: 1),
            rotation: 90,
          ),
        ],
      );
      final drafts = AndroidEditProjectRepository();
      await drafts.save(draft);
      expect(
        (await AndroidEditProjectRepository().find(draft.id))!.toJson(),
        draft.toJson(),
      );
      final preview = GlobalKey<EditorPreviewState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorPreview(
              key: preview,
              project: draft,
              onPosition: (_) {},
            ),
          ),
        ),
      );
      for (var i = 0; i < 30 && preview.currentState?.channel == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      }
      expect(preview.currentState?.channel, isNotNull);
      await preview.currentState!.load();
      await preview.currentState!.command('play');
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
      }
      expect(preview.currentState!.error, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      final videoUri = await AndroidEditProjectRepository.channel
          .invokeMethod<String>('engineProbe', draft.toJson())
          .timeout(const Duration(minutes: 2));
      final video = (await catalog.find(videoUri!))!;
      expect(video.duration!.inMilliseconds, inInclusiveRange(1800, 2300));
      expect(video.width, 180);
      expect(video.height, 320);
      expect((await catalog.thumbnail(video.uri)).length, greaterThan(0));
      var subtitleDifference = 0;
      if (const bool.fromEnvironment('P2_P3_SUBTITLES')) {
        Future<Uint8List> pixels(int timeMs) async {
          final data = (await channel.invokeMethod<Uint8List>('thumbnailAt', {
            'uri': videoUri,
            'timeMs': timeMs,
          }))!;
          final codec = await ui.instantiateImageCodec(data);
          final frame = await codec.getNextFrame();
          final value = (await frame.image.toByteData())!.buffer.asUint8List();
          frame.image.dispose();
          codec.dispose();
          return value;
        }

        final visible = await pixels(300), hidden = await pixels(800);
        expect(visible.length, hidden.length);
        for (var i = 0; i < visible.length; i += 4) {
          if ((visible[i] - hidden[i]).abs() > 40 ||
              (visible[i + 1] - hidden[i + 1]).abs() > 40 ||
              (visible[i + 2] - hidden[i + 2]).abs() > 40) {
            subtitleDifference++;
          }
        }
        expect(
          subtitleDifference,
          greaterThan(50),
          reason: 'Timed text must change decoded frame pixels inside the same still clip.',
        );
      }
      expect(
        await channel.invokeMethod<Uint8List>('imageBytes', {'uri': renamed}),
        orderedEquals(bytes),
      );
      final exportResults = <Map<String, dynamic>>[];
      if (const bool.fromEnvironment('P2_P3_ADVANCED')) {
        final engine = AndroidEditProjectRepository.channel;
        Future<Map<String, dynamic>> job(String id) async =>
            (jsonDecode((await engine.invokeMethod<String>('exportList'))!)
                    as List)
                .cast<Map<String, dynamic>>()
                .firstWhere((j) => j['id'] == id);
        for (final format in ['mp4', 'gif']) {
          final id = (await engine.invokeMethod<String>(
            'exportStart',
            draft
                .copyWith(
                  effects: {
                    'format': format,
                    'bitrate': 1000000,
                    'gifFps': 5,
                    'gifEdge': 160,
                    'gifRepeats': 2,
                    'filter': 'grayscale',
                    'text': 'Tiếng Việt',
                  },
                )
                .toJson(),
          ))!;
          Map<String, dynamic> result = {};
          for (var i = 0; i < 120; i++) {
            result = await job(id);
            if ([
              'completed',
              'failed',
              'cancelled',
            ].contains(result['state'])) {
              break;
            }
            await Future<void>.delayed(const Duration(milliseconds: 500));
          }
          expect(result['state'], 'completed', reason: result.toString());
          final output = (await catalog.find(result['uri'] as String))!;
          expect(output.sizeBytes, greaterThan(0));
          if (format == 'gif') {
            final data = await channel.invokeMethod<Uint8List>('imageBytes', {
              'uri': output.id,
            });
            final codec = await ui.instantiateImageCodec(data!);
            expect(codec.frameCount, greaterThan(1));
            final frame = await codec.getNextFrame();
            expect(frame.image.width, 90);
            expect(frame.image.height, 160);
            frame.image.dispose();
            codec.dispose();
          } else {
            expect(
              (await catalog.thumbnail(output.uri)).length,
              greaterThan(0),
            );
          }
          exportResults.add({
            'id': id,
            'format': format,
            'uri': output.id,
            'bytes': output.sizeBytes,
            'elapsedMs':
                (result['finishedAt'] as num) - (result['startedAt'] as num),
          });
        }
        final cancelled = (await engine.invokeMethod<String>(
          'exportStart',
          draft.toJson(),
        ))!;
        await engine.invokeMethod<void>('exportCancel', cancelled);
        expect((await job(cancelled))['state'], 'cancelled');
        await engine.invokeMethod<void>('exportRetry', cancelled);
        await engine.invokeMethod<void>('exportCancel', cancelled);
        expect((await job(cancelled))['state'], 'cancelled');
        expect(
          await channel.invokeMethod<Uint8List>('imageBytes', {'uri': renamed}),
          orderedEquals(bytes),
        );
      }
      binding.reportData = {
        'milestone': const bool.fromEnvironment('P2_P3_SUBTITLES')
            ? 'M5'
            : const bool.fromEnvironment('P2_P3_ADVANCED')
            ? 'M4'
            : 'M3',
        'imageUri': renamed,
        'bytes': bytes.length,
        'dimensions': [320, 180],
        'sourcePreserved': true,
        'outputsRetained': true,
        'photoProject': draft.id,
        'videoUri': videoUri,
        'videoDurationMs': video.duration!.inMilliseconds,
        'videoDimensions': [video.width, video.height],
        'exports': exportResults,
        'subtitleDifferencePixels': subtitleDifference,
      };
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
