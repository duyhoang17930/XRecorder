import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Drawing overlay contract tests', () {
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidRecordingService.commands, (
        call,
      ) async {
        methodCalls.add(call);
        switch (call.method) {
          case 'setDrawingEnabled':
            return (call.arguments as Map)['enabled'] == true;
          case 'clearDrawing':
            return true;
          case 'undoDrawing':
            return true;
          case 'setDrawingStyle':
            return true;
          case 'getDrawingState':
            return {
              'enabled': true,
              'strokeCount': 3,
              'canUndo': true,
              'color': 0xFFFF7847,
              'width': 8.0,
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

    test('setDrawingEnabled passes boolean flag to method channel', () async {
      final service = AndroidRecordingService();

      final enabledResult = await service.setDrawingEnabled(true);
      expect(enabledResult, isTrue);

      final disabledResult = await service.setDrawingEnabled(false);
      expect(disabledResult, isFalse);

      final calls =
          methodCalls.where((c) => c.method == 'setDrawingEnabled').toList();
      expect(calls.length, 2);
      expect(calls[0].arguments, {'enabled': true});
      expect(calls[1].arguments, {'enabled': false});
    });

    test('clearDrawing and undoDrawing invoke expected channel methods', () async {
      final service = AndroidRecordingService();

      final clearResult = await service.clearDrawing();
      expect(clearResult, isTrue);

      final undoResult = await service.undoDrawing();
      expect(undoResult, isTrue);

      expect(methodCalls.any((c) => c.method == 'clearDrawing'), isTrue);
      expect(methodCalls.any((c) => c.method == 'undoDrawing'), isTrue);
    });

    test('setDrawingStyle sends color and width payload', () async {
      final service = AndroidRecordingService();

      final result = await service.setDrawingStyle(
        color: 0xFFFF0000,
        width: 14.5,
      );
      expect(result, isTrue);

      final styleCall =
          methodCalls.firstWhere((c) => c.method == 'setDrawingStyle');
      final payload = styleCall.arguments as Map<Object?, Object?>;
      expect(payload['color'], 0xFFFF0000);
      expect(payload['width'], 14.5);
    });

    test('getDrawingState retrieves snapshot map from native', () async {
      final service = AndroidRecordingService();

      final state = await service.getDrawingState();
      expect(state['enabled'], isTrue);
      expect(state['strokeCount'], 3);
      expect(state['canUndo'], isTrue);
      expect(state['color'], 0xFFFF7847);
      expect(state['width'], 8.0);
    });
  });
}
