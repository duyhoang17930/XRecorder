import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/persistence/settings_store.dart';
import 'package:xrecorder/features/recording/recording_selection.dart';
import 'package:xrecorder/features/recording/recording_service.dart';
import 'package:xrecorder/features/settings/recording_settings_form.dart';
import 'package:xrecorder/features/settings/audio_video_settings_screen.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';
import 'package:xrecorder/l10n/localization.dart';
import 'package:xrecorder/app/theme/app_theme.dart';
import 'package:xrecorder/core/widgets/studio_create_sheet.dart';
import 'package:xrecorder/core/ui/components/buttons/studio_buttons.dart';

import 'fixtures/recorder.dart';

class _Store implements SettingsStore {
  String? document;
  int writes = 0;
  @override
  Future<String?> read() async => document;
  @override
  Future<void> write(String value) async {
    writes++;
    document = value;
  }
}

class _Recorder extends TestRecorder {
  @override
  Future<RecordingCapabilities> capabilities() async => RecordingCapabilities(
    audioSources: {AudioSource.mute},
    configurations: [
      const VideoConfiguration(width: 1280, height: 720, fps: 30),
    ],
    noiseReduction: false,
    hevc: false,
  );
}

void main() {
  for (final locale in ['vi', 'ar']) {
    testWidgets('recording page title and gain semantics use $locale', (
      tester,
    ) async {
      final store = _Store();
      final settings = SettingsController(store: store);
      final service = _Recorder();
      final capture = CaptureController(service, onSaved: () {});
      await tester.pumpWidget(
        SettingsScope(
          controller: settings,
          child: CaptureScope(
            controller: capture,
            child: MaterialApp(
              theme: AppTheme.dark,
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const AudioVideoSettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(AudioVideoSettingsScreen));
      final strings = context.l10n;
      expect(
        find.widgetWithText(AppBar, strings.recordingSettings),
        findsOneWidget,
      );
      expect(find.text('Audio & Video Settings'), findsNothing);
      final gains = tester.widgetList<Slider>(find.byType(Slider)).toList();
      expect(gains, hasLength(2));
      final spoken = gains
          .map((gain) => gain.semanticFormatterCallback!)
          .toList();
      for (final gain in gains) {
        expect(
          gain.label,
          strings.percentValue(context.displayValue(gain.value.round())),
        );
        expect(
          gain.semanticFormatterCallback!(125),
          strings.accessibilityValue40(context.displayValue(125)),
        );
      }
      final expectedAfterDetach = strings.accessibilityValue40(
        context.displayValue(125),
      );
      expect(find.text(strings.captureProtectedAudioNotice), findsOneWidget);
      expect(find.text(strings.captureUnsupportedDevice), findsOneWidget);
      await tester.ensureVisible(find.text(strings.captureTouchGuidance));
      await tester.tap(find.text(strings.captureTouchGuidance));
      await tester.pumpAndSettle();
      expect(find.text(strings.captureTouchGuidanceBody), findsOneWidget);
      expect(find.text('Show touches'), findsNothing);
      expect(find.text(strings.captureTouchGuidance), findsNWidgets(2));
      await tester.tap(find.text(strings.close));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(strings.captureAutoStop));
      expect(find.text(strings.captureNoLimit), findsOneWidget);
      await tester.tap(find.text(strings.captureAutoStop));
      await tester.pumpAndSettle();
      expect(find.text(strings.captureDurationHint), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '86401');
      await tester.tap(find.text(strings.save));
      await tester.pumpAndSettle();
      expect(find.text(strings.captureDurationInvalid), findsOneWidget);
      expect(settings.durationSeconds, 0);
      await tester.tap(find.widgetWithText(TextButton, strings.cancel));
      await tester.pumpAndSettle();
      expect(store.writes, 0);
      await tester.pumpWidget(const SizedBox());
      // Accessibility may query the previous slider during route teardown.
      for (final format in spoken) {
        expect(format(125), expectedAfterDetach);
      }
      expect(tester.takeException(), isNull);
      capture.dispose();
      settings.dispose();
      await service.events.close();
    });

    testWidgets(
      'root recorder and dynamic countdowns are localized without preference writes $locale',
      (tester) async {
        final store = _Store();
        final settings = SettingsController(store: store);
        await settings.restore();
        final service = _Recorder();
        final capture = CaptureController(service, onSaved: () {});
        await tester.pumpWidget(
          SettingsScope(
            controller: settings,
            child: CaptureScope(
              controller: capture,
              child: MaterialApp(
                theme: AppTheme.dark,
                locale: Locale(locale),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const Scaffold(
                  body: SingleChildScrollView(child: StudioRecordHero()),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(StudioRecordHero));
        expect(find.text(context.l10n.captureReady), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.data == context.l10n.captureRecorderTitle &&
                widget.style == Theme.of(context).textTheme.displayLarge,
          ),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(RecordActionButton, context.l10n.recordScreen),
          findsOneWidget,
        );
        expect(find.text('Record screen'), findsNothing);
        expect(
          context.message('Starting in 10s'),
          context.l10n.captureStartsIn(10),
        );
        expect(
          context.message('Screenshot in 3s'),
          context.l10n.captureScreenshotIn(3),
        );
        expect(context.message('Starting in my title'), 'Starting in my title');
        expect(settings.audio, 'Mixed Stream');
        expect(store.writes, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        capture.dispose();
        settings.dispose();
        await service.events.close();
      },
    );
  }

  for (final locale in ['vi', 'ar']) {
    testWidgets(
      '$locale recording controls retain canonical persisted values',
      (tester) async {
        final store = _Store();
        final settings = SettingsController(store: store);
        final service = _Recorder();
        final capture = CaptureController(service, onSaved: () {});
        await tester.pumpWidget(
          SettingsScope(
            controller: settings,
            child: CaptureScope(
              controller: capture,
              child: MaterialApp(
                locale: Locale(locale),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const Scaffold(
                  body: SingleChildScrollView(child: RecordingSettingsForm()),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final texts = tester.element(find.byType(RecordingSettingsForm)).l10n;
        expect(find.text(texts.captureAudioSource), findsOneWidget);
        expect(
          tester
              .widget<ChoiceChip>(
                find.widgetWithText(ChoiceChip, texts.microphone),
              )
              .onSelected,
          isNull,
        );
        await tester.ensureVisible(find.text(texts.mute));
        await tester.tap(find.text(texts.mute));
        await tester.pumpAndSettle();
        await settings.flushed;
        expect(settings.audio, 'Mute');
        expect(store.document, contains('"audio":"Mute"'));
        await tester.pumpWidget(const SizedBox());
        capture.dispose();
        settings.dispose();
        await service.events.close();
      },
    );
  }
  test(
    'presets agree across portrait/landscape and reject different FPS/codec',
    () {
      for (final advertised in [(1280, 720), (720, 1280)]) {
        final caps = RecordingCapabilities(
          audioSources: {AudioSource.mute},
          configurations: [
            VideoConfiguration(
              width: advertised.$1,
              height: advertised.$2,
              fps: 30,
            ),
          ],
          noiseReduction: false,
          hevc: false,
        );
        for (final requested in [(1280, 720), (720, 1280)]) {
          validateRecordingSelection(
            RecordingSettings(
              width: requested.$1,
              height: requested.$2,
              fps: 30,
              audioSource: AudioSource.mute,
            ),
            caps,
          );
          for (final invalid in [
            RecordingSettings(
              width: requested.$1,
              height: requested.$2,
              fps: 60,
            ),
            RecordingSettings(
              width: requested.$1,
              height: requested.$2,
              fps: 30,
              codec: VideoCodec.hevc,
            ),
          ]) {
            expect(
              () => validateRecordingSelection(invalid, caps),
              throwsA(isA<DomainFailure>()),
            );
          }
        }
      }
    },
  );

  testWidgets(
    'opening and closing stale settings preserves persisted document',
    (tester) async {
      final store = _Store();
      final settings = SettingsController(store: store);
      settings.update(() {
        settings.resolution = '4K UHD';
        settings.fps = '120';
        settings.codec = 'H.265 / HEVC';
        settings.countdown = '5s';
      });
      await settings.flushed;
      final original = store.document;
      final originalWrites = store.writes;
      final service = _Recorder();
      final capture = CaptureController(service, onSaved: () {});
      await tester.pumpWidget(
        SettingsScope(
          controller: settings,
          child: CaptureScope(
            controller: capture,
            child: const MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(child: RecordingSettingsForm()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await settings.flushed;
      expect(store.document, original);
      expect(store.writes, originalWrites);
      expect(settings.resolution, '4K UHD');
      expect(settings.fps, '120');
      expect(settings.codec, 'H.265 / HEVC');
      capture.dispose();
      settings.dispose();
      await service.events.close();
    },
  );
}
