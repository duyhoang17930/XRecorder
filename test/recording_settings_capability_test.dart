import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/persistence/settings_store.dart';
import 'package:xrecorder/features/recording/recording_service.dart';
import 'package:xrecorder/features/recording/recording_selection.dart';
import 'package:xrecorder/features/recording/recording_setup_sheet.dart';
import 'package:xrecorder/features/settings/audio_video_settings_screen.dart';
import 'package:xrecorder/features/settings/recording_settings_form.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';

import 'fixtures/recorder.dart';

class CapabilityStore implements SettingsStore {
  String? document;
  var writes = 0;
  @override
  Future<String?> read() async => document;
  @override
  Future<void> write(String document) async {
    writes++;
    this.document = document;
  }
}

class CapabilityRecorder extends TestRecorder {
  @override
  Future<RecordingCapabilities> capabilities() async => RecordingCapabilities(
    audioSources: {AudioSource.mute},
    configurations: const [
      VideoConfiguration(width: 1280, height: 720, fps: 30),
    ],
    noiseReduction: false,
    hevc: false,
  );
}

Widget capabilityApp(
  SettingsController settings,
  CaptureController capture,
  Widget child,
) => SettingsScope(
  controller: settings,
  child: CaptureScope(
    controller: capture,
    child: MaterialApp(home: child),
  ),
);

void main() {
  test('tuple matching is canonical but never enables absent codec/FPS/size or exceeds Performance policy', () {
    final caps = limitedCapabilities();
    for (final size in [(1280, 720), (720, 1280)]) {
      expect(
        supportsRecordingTuple(
          caps,
          width: size.$1,
          height: size.$2,
          fps: 30,
          codec: VideoCodec.avc,
        ),
        isTrue,
      );
      expect(
        supportsRecordingTuple(
          caps,
          width: size.$1,
          height: size.$2,
          fps: 60,
          codec: VideoCodec.avc,
        ),
        isFalse,
      );
      expect(
        supportsRecordingTuple(
          caps,
          width: size.$1,
          height: size.$2,
          fps: 30,
          codec: VideoCodec.hevc,
        ),
        isFalse,
      );
    }
    expect(
      supportsRecordingTuple(
        caps,
        width: 1920,
        height: 1080,
        fps: 30,
        codec: VideoCodec.avc,
      ),
      isFalse,
    );
    final highCaps = RecordingCapabilities(
      audioSources: {AudioSource.mute},
      noiseReduction: false,
      hevc: false,
      configurations: const [
        VideoConfiguration(width: 1920, height: 1080, fps: 60),
      ],
    );
    expect(
      supportsRecordingTuple(
        highCaps,
        width: 1920,
        height: 1080,
        fps: 60,
        codec: VideoCodec.avc,
      ),
      isTrue,
    );
    expect(
      supportsRecordingTuple(
        highCaps,
        width: 1920,
        height: 1080,
        fps: 60,
        codec: VideoCodec.avc,
        mode: RecordingMode.performance,
      ),
      isFalse,
    );
  });

  testWidgets(
    'only an explicit supported choice writes the new tuple and survives reopening',
    (tester) async {
      final store = CapabilityStore();
      final settings = SettingsController(store: store)
        ..resolution = '1080p FHD'
        ..fps = '60'
        ..orientation = 'Landscape'
        ..audio = 'Mute';
      settings.update(() {});
      await settings.flushed;
      store.writes = 0;
      final service = CapabilityRecorder();
      final capture = CaptureController(service, onSaved: () {});
      Widget form() => capabilityApp(
        settings,
        capture,
        const Scaffold(
          body: SingleChildScrollView(
            child: RecordingSettingsForm(advanced: false),
          ),
        ),
      );
      try {
        await tester.pumpWidget(form());
        await tester.pumpAndSettle();
        expect(store.writes, 0);
        await tester.tap(find.widgetWithText(ChoiceChip, '720p HD'));
        await tester.pumpAndSettle();
        await settings.flushed;
        expect(settings.resolution, '720p HD');
        expect(settings.fps, '30');
        expect(store.writes, 1);
        final saved = store.document;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(form());
        await tester.pumpAndSettle();
        await settings.flushed;
        expect(store.writes, 1);
        expect(store.document, saved);
        validateRecordingSelection(
          settings.recordingSnapshot,
          await service.capabilities(),
        );
        final restored = SettingsController(store: store);
        await restored.restore();
        expect(restored.resolution, '720p HD');
        expect(restored.fps, '30');
        restored.dispose();
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        capture.dispose();
        settings.dispose();
        await service.events.close();
      }
    },
  );

  for (final fullScreen in [false, true]) {
    for (final mode in ['Normal', 'Performance']) {
      testWidgets(
        'opening ${fullScreen ? 'full settings' : 'setup'} twice does not write stale $mode preferences',
        (tester) async {
          final store = CapabilityStore();
          final settings = SettingsController(store: store);
          settings.update(() {
            settings.resolution = '1080p FHD';
            settings.fps = '60';
            settings.orientation = 'Landscape';
            settings.mode = mode;
            settings.bitrate = '24 Mbps';
            settings.audio = 'Mute';
          });
          await settings.flushed;
          final before = store.document;
          store.writes = 0;
          final service = CapabilityRecorder();
          final capture = CaptureController(service, onSaved: () {});
          try {
            await tester.pumpWidget(
              capabilityApp(
                settings,
                capture,
                Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () {
                        if (fullScreen) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const AudioVideoSettingsScreen(),
                            ),
                          );
                        } else {
                          openRecordingSetup(context);
                        }
                      },
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            );
            for (var i = 0; i < 2; i++) {
              await tester.tap(find.text('Open'));
              await tester.pumpAndSettle();
              final stale = tester.widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, '1080p FHD'),
              );
              expect(stale.selected, isTrue);
              expect(stale.onSelected, isNull);
              await settings.flushed;
              expect(store.writes, 0);
              expect(store.document, before);
              expect(
                () => validateRecordingSelection(
                  settings.recordingSnapshot,
                  limitedCapabilities(),
                ),
                throwsA(isA<DomainFailure>()),
              );
              await tester.binding.handlePopRoute();
              await tester.pumpAndSettle();
            }
            final restored = SettingsController(store: store);
            await restored.restore();
            expect(restored.resolution, '1080p FHD');
            expect(restored.fps, '60');
            expect(restored.bitrate, '24 Mbps');
            expect(store.writes, 0);
            restored.dispose();
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            capture.dispose();
            settings.dispose();
            await service.events.close();
          }
        },
      );
    }
  }

  for (final orientation in ['Portrait', 'Landscape', 'Auto Sensor']) {
    testWidgets(
      '$orientation uses the same advertised tuple for chips and Start validation',
      (tester) async {
        final settings = SettingsController()
          ..resolution = '720p HD'
          ..fps = '30'
          ..orientation = orientation
          ..audio = 'Mute';
        final service = CapabilityRecorder();
        final capture = CaptureController(service, onSaved: () {});
        try {
          await tester.pumpWidget(
            capabilityApp(
              settings,
              capture,
              const Scaffold(
                body: SingleChildScrollView(
                  child: RecordingSettingsForm(advanced: false),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          validateRecordingSelection(
            settings.recordingSnapshot,
            await service.capabilities(),
          );
          expect(
            tester
                .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '720p HD'))
                .onSelected,
            isNotNull,
          );
          expect(
            tester
                .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '30'))
                .onSelected,
            isNotNull,
          );
          expect(
            tester
                .widget<ChoiceChip>(
                  find.widgetWithText(ChoiceChip, '1080p FHD'),
                )
                .onSelected,
            isNull,
          );
          expect(
            tester
                .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '60'))
                .onSelected,
            isNull,
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          capture.dispose();
          settings.dispose();
          await service.events.close();
        }
      },
    );
  }
}

RecordingCapabilities limitedCapabilities() => RecordingCapabilities(
  audioSources: {AudioSource.mute},
  configurations: const [VideoConfiguration(width: 1280, height: 720, fps: 30)],
  noiseReduction: false,
  hevc: false,
);
