import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/persistence/settings_store.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';
import 'package:xrecorder/features/media/media_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android preferences commit and reload through native adapter', (
    tester,
  ) async {
    const store = AndroidSettingsStore();
    final original = await store.read();
    try {
      final first = SettingsController(store: store);
      await first.restore();
      first.update(() {
        first.fps = '30';
        first.audio = 'Internal Audio';
      });
      await first.flushed;
      expect(first.persistenceError, isNull);
      first.dispose();
      final restored = SettingsController(store: store);
      await restored.restore();
      expect(restored.fps, '30');
      expect(restored.audio, 'Internal Audio');
      restored.dispose();
    } finally {
      await store.write(original ?? '{"version":1,"values":{}}');
    }
  });
  testWidgets(
    'Android app-owned catalog and storage resolve without broad permissions',
    (tester) async {
      final repository = AndroidMediaRepository();
      try {
        final videos = await repository.list(kind: MediaKind.video);
        final images = await repository.list(kind: MediaKind.image);
        final storage = await repository.storage();
        expect(
          storage['videos'],
          videos.fold<int>(0, (sum, item) => sum + item.sizeBytes),
        );
        expect(
          storage['images'],
          images.fold<int>(0, (sum, item) => sum + item.sizeBytes),
        );
        expect(storage['free'], greaterThan(0));
        expect(await repository.find('invalid-id'), isNull);
      } finally {
        repository.dispose();
      }
    },
  );
}
