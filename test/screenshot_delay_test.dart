import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/recording/recording_service.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';

import 'settings_persistence_test.dart' show MemoryStore;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () => messenger.setMockMethodCallHandler(
      AndroidRecordingService.commands,
      null,
    ),
  );

  test('configured screenshot delay crosses the native boundary; legacy call stays compatible', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(AndroidRecordingService.commands, (
      call,
    ) async {
      calls.add(call);
      return {'id': 'shot', 'state': 'awaitingPermission', 'screenshot': true};
    });
    final service = AndroidRecordingService();
    for (final seconds in [1, 3, 5, 10]) {
      await service.screenshotAfter(Duration(seconds: seconds));
      expect(calls.last.method, 'screenshot');
      expect(calls.last.arguments, {'countdown': seconds});
    }
    await service.screenshot();
    expect(calls.last.arguments, isNull);
  });

  test('invalid screenshot delays never start consent', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(AndroidRecordingService.commands, (
      _,
    ) async {
      calls++;
      return null;
    });
    final service = AndroidRecordingService();
    for (final milliseconds in [-1000, 0, 1500, 2000, 11000]) {
      expect(
        () => service.screenshotAfter(Duration(milliseconds: milliseconds)),
        throwsA(isA<DomainFailure>()),
      );
    }
    expect(calls, 0);
  });

  test('screenshot delay persists independently of recording countdown and retains old default', () async {
    final store = MemoryStore();
    final settings = SettingsController(store: store);
    expect(settings.screenshotDelayDuration, const Duration(seconds: 3));
    settings.update(() {
      settings.screenshotDelay = '5s';
      settings.countdown = '10s';
    });
    await settings.flushed;
    final restored = SettingsController(store: store);
    await restored.restore();
    expect(restored.screenshotDelayDuration, const Duration(seconds: 5));
    expect(restored.countdown, '10s');
    settings.dispose();
    restored.dispose();
  });
}
