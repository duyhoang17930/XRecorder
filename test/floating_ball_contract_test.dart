import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Floating ball customization contract tests', () {
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidRecordingService.commands, (
        call,
      ) async {
        methodCalls.add(call);
        if (call.method == 'capabilities') {
          return {
            'audioSources': ['mute'],
            'presets': [
              {'width': 1280, 'height': 720, 'fps': 30, 'codec': 'avc'},
            ],
            'noiseReduction': false,
            'hevc': false,
            'facecam': false,
          };
        }
        if (call.method == 'start') {
          return {
            'id': 'test-session-floating',
            'state': 'recording',
            'screenshot': false,
            'config': call.arguments as Map<Object?, Object?>,
          };
        }
        if (call.method == 'updateFloatingBall') {
          return true;
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidRecordingService.commands, null);
    });

    test('start passes floatingScale, floatingOpacity, and ratios in payload', () async {
      final service = AndroidRecordingService();
      const settings = RecordingSettings(
        width: 1280,
        height: 720,
        fps: 30,
      );

      await service.start(
        settings,
        floatingScale: 1.2,
        floatingOpacity: 0.85,
        floatingRatioX: 0.95,
        floatingRatioY: 0.4,
      );

      final startCall = methodCalls.firstWhere((c) => c.method == 'start');
      final payload = startCall.arguments as Map<Object?, Object?>;

      expect(payload['floatingScale'], 1.2);
      expect(payload['floatingOpacity'], 0.85);
      expect(payload['floatingRatioX'], 0.95);
      expect(payload['floatingRatioY'], 0.4);
    });

    test('updateFloatingBall sends scale and opacity via method channel', () async {
      final service = AndroidRecordingService();

      final result = await service.updateFloatingBall(
        scale: 1.1,
        opacity: 0.75,
      );

      expect(result, isTrue);
      final updateCall = methodCalls.firstWhere(
        (c) => c.method == 'updateFloatingBall',
      );
      final payload = updateCall.arguments as Map<Object?, Object?>;
      expect(payload['scale'], 1.1);
      expect(payload['opacity'], 0.75);
    });
  });
}
