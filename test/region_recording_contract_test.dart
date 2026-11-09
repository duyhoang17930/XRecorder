import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Region recording contract tests', () {
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        AndroidRecordingService.commands,
        (call) async {
          calls.add(call);
          if (call.method == 'capabilities') {
            return {
              'audioSources': ['mute', 'microphone'],
              'presets': [
                {'width': 1280, 'height': 720, 'fps': 30, 'codec': 'avc'},
                {'width': 640, 'height': 480, 'fps': 30, 'codec': 'avc'},
              ],
              'noiseReduction': false,
              'hevc': false,
              'facecam': false,
            };
          }
          if (call.method == 'start') {
            final args = call.arguments as Map<Object?, Object?>?;
            return {
              'id': 'test-session',
              'state': 'awaitingPermission',
              'startedAt': 0,
              'elapsedMs': 0,
              'config': args,
            };
          }
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidRecordingService.commands, null);
    });

    test('start without crop passes default parameters', () async {
      final service = AndroidRecordingService();
      const settings = RecordingSettings(
        width: 1280,
        height: 720,
        fps: 30,
      );
      await service.start(settings);

      expect(calls.any((c) => c.method == 'start'), isTrue);
      final startCall = calls.firstWhere((c) => c.method == 'start');
      final args = startCall.arguments as Map<Object?, Object?>;
      expect(args['width'], 1280);
      expect(args['height'], 720);
      expect(args.containsKey('cropX'), isFalse);
      expect(args.containsKey('cropY'), isFalse);
    });

    test('start with region crop passes crop coordinates', () async {
      final service = AndroidRecordingService();
      const settings = RecordingSettings(
        width: 1280,
        height: 720,
        fps: 30,
      );
      final session = await service.start(
        settings,
        cropX: 100,
        cropY: 200,
        cropWidth: 640,
        cropHeight: 480,
      );

      expect(calls.any((c) => c.method == 'start'), isTrue);
      final startCall = calls.firstWhere((c) => c.method == 'start');
      final args = startCall.arguments as Map<Object?, Object?>;
      expect(args['cropX'], 100);
      expect(args['cropY'], 200);
      expect(args['cropWidth'], 640);
      expect(args['cropHeight'], 480);
      expect(session.id, 'test-session');
    });

    test('decode correctly extracts dimensions and configuration', () {
      final data = {
        'id': 'region-session',
        'state': 'recording',
        'startedAt': 1600000000000,
        'elapsedMs': 5000,
        'screenshot': false,
        'config': {
          'width': 640,
          'height': 480,
          'fps': 30,
          'bitrate': 4000000,
          'codec': 'avc',
          'audio': 'mute',
          'orientation': 'portrait',
          'mode': 'normal',
          'cropX': 100,
          'cropY': 200,
          'cropWidth': 640,
          'cropHeight': 480,
          'isRegion': true,
        },
      };

      final session = AndroidRecordingService.decode(data);
      expect(session.id, 'region-session');
      expect(session.state, RecordingState.recording);
      expect(session.configSnapshot.width, 640);
      expect(session.configSnapshot.height, 480);
      expect(session.configSnapshot.fps, 30);
    });
  });
}
