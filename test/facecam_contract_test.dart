import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Facecam controls contract tests', () {
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidRecordingService.commands, (
        call,
      ) async {
        methodCalls.add(call);
        switch (call.method) {
          case 'switchFacecamCamera':
            return true;
          case 'setFacecamEffect':
            return (call.arguments as Map)['effect'] == 4;
          case 'setFacecamScale':
            return (call.arguments as Map)['scale'] == 1.25;
          case 'getFacecamState':
            return {
              'ready': true,
              'lensFacing': 0, // front
              'effect': 4, // sepia
              'scale': 1.25,
            };
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidRecordingService.commands, null);
    });

    test('switchFacecamCamera invokes native method', () async {
      final service = AndroidRecordingService();
      final result = await service.switchFacecamCamera();
      expect(result, isTrue);
      expect(
        methodCalls.any((c) => c.method == 'switchFacecamCamera'),
        isTrue,
      );
    });

    test('setFacecamEffect sends effect integer code', () async {
      final service = AndroidRecordingService();
      final result = await service.setFacecamEffect(4);
      expect(result, isTrue);

      final call =
          methodCalls.firstWhere((c) => c.method == 'setFacecamEffect');
      expect(call.arguments, {'effect': 4});
    });

    test('setFacecamScale sends scale factor', () async {
      final service = AndroidRecordingService();
      final result = await service.setFacecamScale(1.25);
      expect(result, isTrue);

      final call = methodCalls.firstWhere((c) => c.method == 'setFacecamScale');
      expect(call.arguments, {'scale': 1.25});
    });

    test('getFacecamState returns current facecam status map', () async {
      final service = AndroidRecordingService();
      final state = await service.getFacecamState();

      expect(state['ready'], isTrue);
      expect(state['lensFacing'], 0);
      expect(state['effect'], 4);
      expect(state['scale'], 1.25);
    });
  });
}
