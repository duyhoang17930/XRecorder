import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/app/theme/app_theme.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/widgets/studio_widgets.dart';
import 'package:xrecorder/features/recording/recording_service.dart';
import 'package:xrecorder/features/recording/recording_setup_sheet.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';

import 'fixtures/recorder.dart';

class SetupRecorder extends TestRecorder {
  final starts = <RecordingSettings>[];
  List<VideoConfiguration>? advertised;
  Set<AudioSource> sources = AudioSource.values.toSet();
  bool noiseSupported = true;
  @override
  Future<RecordingCapabilities> capabilities() async => RecordingCapabilities(
    audioSources: sources,
    configurations:
        advertised ??
        [
          for (final size in [
            (1280, 720),
            (1920, 1080),
            (2560, 1440),
            (3840, 2160),
          ])
            for (final fps in [24, 30, 60, 90, 120])
              VideoConfiguration(width: size.$1, height: size.$2, fps: fps),
        ],
    noiseReduction: noiseSupported,
    hevc: true,
    facecam: true,
  );

  @override
  Future<RecordingSession> start(RecordingSettings settings) {
    starts.add(settings);
    return super.start(settings);
  }
}

void main() {
  final limitedCaps = RecordingCapabilities(
    audioSources: {AudioSource.mute},
    hevc: false,
    noiseReduction: false,
    configurations: [VideoConfiguration(width: 1280, height: 720, fps: 30)],
  );
  test(
    'stale unsupported selections and silent Performance clamps are rejected',
    () {
      for (final selection in [
        const RecordingSettings(width: 1920, height: 1080, fps: 60),
        const RecordingSettings(
          width: 1280,
          height: 720,
          fps: 30,
          codec: VideoCodec.hevc,
        ),
        const RecordingSettings(
          width: 1280,
          height: 720,
          fps: 30,
          audioSource: AudioSource.mixed,
        ),
        const RecordingSettings(
          width: 1280,
          height: 720,
          fps: 30,
          mode: RecordingMode.performance,
          bitrate: 24000000,
        ),
      ]) {
        expect(
          () => validateRecordingSelection(selection, limitedCaps),
          throwsA(isA<DomainFailure>()),
        );
      }
      for (final mode in RecordingMode.values) {
        validateRecordingSelection(
          RecordingSettings(
            width: 720,
            height: 1280,
            fps: 30,
            bitrate: 8000000,
            mode: mode,
            audioSource: AudioSource.mute,
          ),
          limitedCaps,
        );
      }
    },
  );
  testWidgets(
    'a stale selection is rejected until the user selects a supported tuple',
    (tester) async {
      final service = SetupRecorder()
        ..advertised = limitedCaps.configurations
        ..sources = limitedCaps.audioSources;
      final capture = CaptureController(service, onSaved: () {});
      final settings = SettingsController();
      try {
        await tester.pumpWidget(
          SettingsScope(
            controller: settings,
            child: CaptureScope(
              controller: capture,
              child: MaterialApp(
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => openRecordingSetup(context),
                      child: const Text('Open setup'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open setup'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start Recording'));
        await tester.pumpAndSettle();
        expect(service.starts, isEmpty);
        expect(settings.resolution, '1080p FHD'); // No silent normalization.
        final resolution = find.widgetWithText(ChoiceChip, '720p HD');
        expect(tester.widget<ChoiceChip>(resolution).onSelected, isNotNull);
        await tester.ensureVisible(resolution);
        await tester.tap(resolution);
        await tester.pumpAndSettle();
        expect(settings.resolution, '720p HD');
        expect(settings.fps, '30');
        await tester.ensureVisible(find.text('Mute'));
        await tester.tap(find.text('Mute'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start Recording'));
        await tester.pumpAndSettle();
        expect(service.starts, hasLength(1));
        expect(service.starts.single.width, 1280);
        expect(service.starts.single.fps, 30);
        expect(service.starts.single.audioSource, AudioSource.mute);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        capture.dispose();
        settings.dispose();
        await service.events.close();
      }
    },
  );
  for (final width in [320.0, 360.0, 411.0]) {
    testWidgets('Setup pins actions and preserves controls at ${width}dp', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 640);
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.reset);
      final service = SetupRecorder();
      final capture = CaptureController(service, onSaved: () {});
      final settings = SettingsController()..durationSeconds = 12;
      try {
        await tester.pumpWidget(
          SettingsScope(
            controller: settings,
            child: CaptureScope(
              controller: capture,
              child: MaterialApp(
                theme: AppTheme.dark,
                home: Scaffold(
                  bottomNavigationBar: const SizedBox(height: 56),
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => openRecordingSetup(context),
                      child: const Text('Open setup'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        Future<void> open() async {
          await tester.tap(find.text('Open setup'));
          await tester.pumpAndSettle();
        }

        Future<void> tapSetting(String text) async {
          final target = find.text(text);
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          await tester.tap(target);
          await tester.pumpAndSettle();
        }

        await open();
        final action = find.widgetWithText(PrimaryButton, 'Start Recording');
        final header = find.byType(StudioSheetHeader);
        final buttonRect = tester.getRect(action);
        final headerRect = tester.getRect(header);
        final selectorRect = tester.getRect(find.text('Basic'));
        final handle = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints?.maxWidth ==
                  AppTheme.dark.bottomSheetTheme.dragHandleSize!.width &&
              widget.constraints?.maxHeight ==
                  AppTheme.dark.bottomSheetTheme.dragHandleSize!.height,
        );
        // Assert the 48dp handle target independently of decorative bar size.
        expect(headerRect.top - tester.getRect(handle).center.dy, 24);
        expect(find.text('Recording mode'), findsNothing);
        expect(find.text('Bitrate'), findsNothing);
        expect(buttonRect.bottom, lessThanOrEqualTo(640 - 24));
        expect(
          find.ancestor(of: action, matching: find.byType(Scrollable)),
          findsNothing,
        );
        for (final dy in [-120.0, -2500.0, 2500.0]) {
          await tester.drag(find.byType(SingleChildScrollView), Offset(0, dy));
          await tester.pumpAndSettle();
          expect(tester.getRect(action), buttonRect);
          expect(tester.getRect(header), headerRect);
          expect(tester.getRect(find.text('Basic')), selectorRect);
          expect(tester.takeException(), isNull);
        }
        expect(
          find.text('Screenshot · 3s delay').hitTestable(),
          findsOneWidget,
        );
        await tapSetting('720p HD');
        await tapSetting('30');
        await tapSetting('Facecam');
        await tapSetting('5s');
        for (final audio in [
          'Mute',
          'Microphone',
          'Internal Audio',
          'Mixed Stream',
        ]) {
          await tapSetting('Basic');
          await tapSetting(audio);
          await tapSetting('Advanced');
          final mic = audio == 'Microphone' || audio == 'Mixed Stream';
          final internal = audio == 'Internal Audio' || audio == 'Mixed Stream';
          expect(
            find.byType(Slider),
            findsNWidgets((mic ? 1 : 0) + (internal ? 1 : 0)),
          );
          expect(
            find.text('Microphone noise reduction'),
            mic ? findsOneWidget : findsNothing,
          );
          expect(
            find.text('Microphone volume: 100%'),
            mic ? findsOneWidget : findsNothing,
          );
          expect(
            find.text('Internal audio volume: 100%'),
            internal ? findsOneWidget : findsNothing,
          );
          expect(settings.audio, audio);
          expect(settings.facecam, isTrue);
          expect(settings.countdown, '5s');
          expect(find.text('Resolution'), findsNothing);
          expect(find.text('Video codec'), findsOneWidget);
          expect(find.text('Orientation'), findsOneWidget);
          for (final dy in [-120.0, -2500.0, 2500.0]) {
            await tester.drag(
              find.byType(SingleChildScrollView),
              Offset(0, dy),
            );
            await tester.pumpAndSettle();
            expect(tester.getRect(action), buttonRect);
            expect(tester.getRect(header), headerRect);
            expect(tester.getRect(find.text('Basic')), selectorRect);
          }
        }
        await tapSetting('Basic');
        await tapSetting('Microphone');
        await tapSetting('Advanced');
        await tapSetting('8 Mbps');
        await tapSetting('Microphone noise reduction');
        expect(find.text('Touch-indicator guidance'), findsNothing);
        expect(find.text('12s'), findsOneWidget);
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '12s'))
              .selected,
          isTrue,
        );
        await tapSetting('Auto-stop');
        expect(settings.durationSeconds, 0);
        expect(settings.recordingSnapshot.durationLimit, isNull);
        for (final label in ['5m', '10m', '30m', '60m', '12s']) {
          expect(find.text(label), findsNothing);
        }
        await tapSetting('Auto-stop');
        expect(settings.durationSeconds, 300);
        for (final preset in {
          '5m': 300,
          '10m': 600,
          '30m': 1800,
          '60m': 3600,
        }.entries) {
          await tapSetting(preset.key);
          expect(settings.durationSeconds, preset.value);
          expect(
            settings.recordingSnapshot.durationLimit,
            Duration(seconds: preset.value),
          );
          expect(
            tester
                .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, preset.key))
                .selected,
            isTrue,
          );
          expect(tester.getRect(action), buttonRect);
          expect(tester.takeException(), isNull);
        }
        await tapSetting('10m');
        await tapSetting('Basic');
        await tapSetting('Advanced');
        expect(settings.durationSeconds, 600);
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '10m'))
              .selected,
          isTrue,
        );
        expect(settings.noise, isTrue);
        expect(settings.facecam, isTrue);
        expect(settings.countdown, '5s');

        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        tester.view.padding = FakeViewPadding.zero;
        await tester.pumpAndSettle();
        expect(tester.getRect(action).bottom, lessThanOrEqualTo(400));
        expect(tester.getRect(action).top, greaterThan(0));
        expect(tester.takeException(), isNull);
        tester.view.viewInsets = FakeViewPadding.zero;
        tester.view.padding = const FakeViewPadding(bottom: 24);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close setup'));
        await tester.pumpAndSettle();
        await open();
        await tapSetting('Advanced');
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '10m'))
              .selected,
          isTrue,
        );
        expect(settings.durationSeconds, 600);
        expect(settings.facecam, isTrue);
        await tester.tap(find.text('Start Recording'));
        await tester.pumpAndSettle();
        final started = service.starts.single;
        expect((started.width, started.height, started.fps), (1280, 720, 30));
        expect(started.bitrate, 8000000);
        expect(started.audioSource, AudioSource.microphone);
        expect(started.noiseReduction, isTrue);
        expect(started.facecam, isTrue);
        expect(started.countdown, const Duration(seconds: 5));
        expect(started.durationLimit, const Duration(minutes: 10));
        expect(find.byType(RecordingSetupSheet), findsNothing);

        await open();
        expect(find.text('Session already active'), findsOneWidget);
        await tester.tap(find.text('Session already active'));
        await tester.pumpAndSettle();
        expect(service.starts, hasLength(1));
        await tester.tap(find.byTooltip('Reset defaults'));
        await tester.pumpAndSettle();
        expect(settings.durationSeconds, 0);
        expect(settings.facecam, isFalse);
        expect(settings.countdown, '3s');
        service.sources = {AudioSource.mute, AudioSource.microphone};
        service.noiseSupported = false;
        await tapSetting('Advanced');
        await tapSetting('Basic');
        expect(
          tester
              .widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, 'Internal Audio'),
              )
              .onSelected,
          isNull,
        );
        expect(
          tester
              .widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, 'Mixed Stream'),
              )
              .onSelected,
          isNull,
        );
        await tapSetting('Microphone');
        await tapSetting('Advanced');
        expect(
          tester
              .widget<SwitchListTile>(
                find.widgetWithText(
                  SwitchListTile,
                  'Microphone noise reduction',
                ),
              )
              .onChanged,
          isNull,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        capture.dispose();
        settings.dispose();
        await service.events.close();
      }
    });
  }
}
