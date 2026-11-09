import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

import 'fixtures/recorder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('completed PNG replay preserves identity and size without new Saved feedback', () async {
    final snapshot = <String, Object?>{
      'id': 'persisted-shot',
      'state': 'completed',
      'screenshot': true,
      'outputUri': 'content://media/external/images/media/42',
      'width': 1440,
      'height': 2960,
      'config': {'width': 1280, 'height': 720},
    };
    final restored = AndroidRecordingService.decode(
      jsonDecode(jsonEncode(snapshot)) as Map<String, dynamic>,
    );
    final service = TestRecorder()..current = restored;
    var catalogRefreshes = 0;
    final controller = CaptureController(
      service,
      onSaved: () => catalogRefreshes++,
    );
    try {
      await controller.refresh();
      expect(controller.session!.id, snapshot['id']);
      expect(controller.session!.outputUri.toString(), snapshot['outputUri']);
      expect(
        (restored.configSnapshot.width, restored.configSnapshot.height),
        (1440, 2960),
      );
      // Existing contract: bootstrap invalidates the catalog once, with no new
      // Saved notice. Repeated replay must not invalidate or announce again.
      expect(catalogRefreshes, 1);
      for (var i = 0; i < 3; i++) {
        service.events.add(restored);
        await controller.refresh();
        await Future<void>.delayed(Duration.zero);
        expect(controller.feedback, isNull);
        expect(catalogRefreshes, 1);
      }
    } finally {
      controller.dispose();
      await service.events.close();
    }
  });
}
