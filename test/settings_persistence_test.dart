import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/persistence/settings_store.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';

class MemoryStore implements SettingsStore {
  String? document;
  bool fail = false;
  @override
  Future<String?> read() async => document;
  @override
  Future<void> write(String document) async {
    if (fail) throw Exception('Disk unavailable');
    this.document = document;
  }
}

void main() {
  test('preferences survive new controller and reset is durable', () async {
    final store = MemoryStore();
    final first = SettingsController(store: store);
    await first.restore();
    first.update(() {
      first.fps = '30';
      first.audio = 'Internal Audio';
      first.gain = 120;
      first.hardware = false;
    });
    first.update(() => first.countdown = '10s');
    await first.flushed;
    first.dispose();
    final second = SettingsController(store: store);
    await second.restore();
    expect(second.fps, '30');
    expect(second.audio, 'Internal Audio');
    expect(second.gain, 120);
    expect(second.hardware, false);
    expect(second.countdown, '10s');
    final snapshot = second.recordingSnapshot;
    second.reset();
    await second.flushed;
    expect(snapshot.fps, 30);
    expect(snapshot.audioSource, AudioSource.internal);
    final third = SettingsController(store: store);
    await third.restore();
    expect(third.fps, '60');
    expect(third.hardware, true);
    second.dispose();
    third.dispose();
  });

  test('migrates unversioned data and validates malformed values', () async {
    final store = MemoryStore()
      ..document = jsonEncode({
        'fps': '30',
        'audio': 'invalid',
        'gain': 900,
        'hardware': 'false',
      });
    final settings = SettingsController(store: store);
    await settings.restore();
    expect(settings.fps, '30');
    expect(settings.audio, 'Mixed Stream');
    expect(settings.gain, 200);
    expect(settings.hardware, true);
    expect(jsonDecode(store.document!)['version'], 2);
    settings.dispose();
  });

  test(
    'corrupt and future documents survive edits until explicit reset',
    () async {
      for (final document in ['{broken', '{"version":3,"values":{}}']) {
        final store = MemoryStore()..document = document;
        final settings = SettingsController(store: store);
        await settings.restore();
        expect(settings.persistenceError, isNotNull);
        settings.update(() => settings.fps = '30');
        await settings.flushed;
        expect(store.document, document);
        settings.reset();
        await settings.flushed;
        expect(settings.persistenceError, isNull);
        expect(jsonDecode(store.document!)['version'], 2);
        settings.dispose();
      }
    },
  );

  test(
    'failed writes are visible and retry saves latest preferences',
    () async {
      final store = MemoryStore()..fail = true;
      final settings = SettingsController(store: store);
      settings.update(() => settings.fps = '24');
      await settings.flushed;
      expect(settings.persistenceError, isNotNull);
      store.fail = false;
      settings.retrySave();
      await settings.flushed;
      expect(settings.persistenceError, isNull);
      final restored = SettingsController(store: store);
      await restored.restore();
      expect(restored.fps, '24');
      settings.dispose();
      restored.dispose();
    },
  );
}
