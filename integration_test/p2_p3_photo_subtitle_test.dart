import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/editor/subtitles.dart';
import 'package:xrecorder/features/editor/transcription_service.dart';
import 'package:xrecorder/features/media/media_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'EXIF 1-8, P3 to sRGB, JPEG resize, mixed timeline and ASR burn-in',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Photo and subtitle output verification')),
        ),
      );
      const media = AndroidMediaRepository.channel;
      const engine = AndroidEditProjectRepository.channel;
      const root = 'content://com.xrecorder.xrecorder.files/media/';
      final catalog = AndroidMediaRepository();
      addTearDown(catalog.dispose);
      Future<ui.Image> image(Uint8List bytes) async {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        codec.dispose();
        return frame.image;
      }

      final errors = <String, double>{};
      for (final name in [for (var i = 1; i <= 8; i++) 'exif_$i', 'wide']) {
        final actual = await image(
          (await media.invokeMethod<Uint8List>('decodePhoto', {
            'uri': '${root}p2_p3_$name.${name == 'wide' ? 'png' : 'jpg'}',
          }))!,
        );
        final expected = await image(
          (await media.invokeMethod<Uint8List>('imageBytes', {
            'uri': '${root}p2_p3_${name}_expected.png',
          }))!,
        );
        expect(
          (actual.width, actual.height),
          (expected.width, expected.height),
        );
        final a = (await actual.toByteData())!.buffer.asUint8List(),
            b = (await expected.toByteData())!.buffer.asUint8List();
        var error = 0;
        for (var i = 0; i < a.length; i++) {
          error += (a[i] - b[i]).abs();
        }
        errors[name] = error / a.length;
        expect(
          errors[name],
          lessThan(3),
          reason: 'Orientation or ICC mismatch for $name',
        );
        actual.dispose();
        expected.dispose();
      }
      final normalized = (await media.invokeMethod<Uint8List>('decodePhoto', {
        'uri': '${root}p2_p3_large.png',
      }))!;
      final large = await image(normalized);
      expect((large.width, large.height), (2048, 1024));
      large.dispose();
      final jpeg = (await media.invokeMethod<String>('saveImage', {
        'bytes': normalized,
        'format': 'jpeg',
        'maxEdge': 480,
        'quality': 95,
      }))!;
      final item = (await catalog.find(jpeg))!;
      expect(item.mimeType, 'image/jpeg');
      expect((item.width, item.height), (480, 240));
      final jpegImage = await image(
        (await media.invokeMethod<Uint8List>('imageBytes', {'uri': jpeg}))!,
      );
      final rgba = (await jpegImage.toByteData())!.buffer.asUint8List();
      expect(rgba.take(3), everyElement(greaterThanOrEqualTo(250)));
      jpegImage.dispose();
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      EditProject video(String name, Map<String, Object> effects) =>
          EditProject(
            id: 'final_${timestamp}_$name',
            title: name,
            updatedAt: DateTime.now(),
            effects: effects,
            clips: [
              TimelineClip(
                mediaId: '${root}p2_p3_audio_video.mp4',
                inPoint: Duration.zero,
                outPoint: const Duration(seconds: 4),
                sourceDuration: const Duration(seconds: 4),
              ),
            ],
          );
      final outputs = <String, String>{};
      for (final name in ['fastBase', 'fastSubtitles']) {
        final project = video(name, {
          'speed': 2.0,
          if (name == 'fastSubtitles') ...{
            'subtitles': [
              {
                'startMs': 250,
                'endMs': 750,
                'text': 'Xin chào Việt Nam. Văn bản dài được tự động xuống dòng để nằm trong vùng an toàn của khung hình.',
              },
            ],
            'subtitleColor': 'yellow',
            'subtitleSize': 'large',
            'subtitlePosition': 'top',
          },
        });
        outputs[name] = (await engine
            .invokeMethod<String>('engineProbe', project.toJson())
            .timeout(const Duration(minutes: 2)))!;
      }
      final mixed = EditProject(
        id: 'mixed_$timestamp',
        title: 'Mixed video/photo',
        updatedAt: DateTime.now(),
        clips: [
          TimelineClip(
            mediaId: '${root}p2_p3_audio_video.mp4',
            inPoint: const Duration(seconds: 1),
            outPoint: const Duration(seconds: 3),
            sourceDuration: const Duration(seconds: 4),
          ),
          TimelineClip(
            mediaId: '${root}p2_p3_exif_6.jpg',
            isImage: true,
            inPoint: Duration.zero,
            outPoint: const Duration(seconds: 1),
            sourceDuration: const Duration(seconds: 1),
          ),
        ],
      );
      outputs['mixed'] = (await engine
          .invokeMethod<String>('engineProbe', mixed.toJson())
          .timeout(const Duration(minutes: 2)))!;
      final speech = EditProject(
        id: 'speech_composition_$timestamp',
        title: 'Edited speech',
        updatedAt: DateTime.now(),
        clips: [
          TimelineClip(
            mediaId: jpeg,
            isImage: true,
            inPoint: Duration.zero,
            outPoint: const Duration(seconds: 11),
            sourceDuration: const Duration(seconds: 11),
          ),
        ],
        effects: {
          'audioTracks': [
            {
              'uri': '${root}p2_p3_jfk.wav',
              'sourceDurationMs': 11000,
              'inMs': 0,
              'outMs': 11000,
              'offsetMs': 0,
              'volume': 1.0,
            },
          ],
        },
      );
      const service = AndroidTranscriptionService();
      final id = await service.start(
        TranscriptionRequest(
          audioUri: Uri.parse(jpeg),
          durationMs: 11000,
          language: 'en',
          operationId: 'edited_asr_$timestamp',

          model: 'tiny',
          project: speech,
        ),
      );
      TranscriptionJob? completed;
      for (var i = 0; i < 300; i++) {
        final current = await service.poll(id, 11000);
        if ([
          TranscriptionState.completed,
          TranscriptionState.failed,
          TranscriptionState.cancelled,
        ].contains(current.state)) {
          completed = current;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      expect(
        completed?.state,
        TranscriptionState.completed,
        reason: completed?.error,
      );
      final track = SubtitleTrack(completed!.cues, durationMs: 11000);
      expect(track.toSrt().toLowerCase(), contains('country'));
      final subtitled = speech.copyWith(
        effects: {...speech.effects, 'subtitles': track.toJson()},
      );
      await AndroidEditProjectRepository().save(subtitled);
      outputs['asrBurnIn'] = (await engine
          .invokeMethod<String>('engineProbe', subtitled.toJson())
          .timeout(const Duration(minutes: 3)))!;
      binding.reportData = {
        'photoMeanAbsolutePixelError': errors,
        'jpegUri': jpeg,
        'jpegDimensions': [480, 240],
        'outputs': outputs,
        'recognizedSrt': track.toSrt(),
        'asrComposition': true,
        'fixturesRetained': true,
      };
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
