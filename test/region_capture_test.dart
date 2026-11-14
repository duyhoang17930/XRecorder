import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/app/theme/app_theme.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/domain/repositories.dart';
import 'package:xrecorder/features/recording/recording_service.dart';
import 'package:xrecorder/features/recording/region_capture_page.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';

import 'fixtures/recorder.dart';

class RegionRecorder extends TestRecorder implements RegionRecordingService {
  ({int width, int height}) display = (width: 1080, height: 2400);
  final requests = <Rect>[];
  Completer<RecordingSession>? pending;

  @override
  Future<({int width, int height})> captureDisplay() async => display;
  @override
  Future<RecordingSession> startRegion(
    RecordingSettings settings, {
    required int cropX,
    required int cropY,
    required int cropWidth,
    required int cropHeight,
  }) {
    requests.add(
      Rect.fromLTWH(
        cropX.toDouble(),
        cropY.toDouble(),
        cropWidth.toDouble(),
        cropHeight.toDouble(),
      ),
    );
    return pending?.future ?? super.start(settings);
  }
}

void main() {
  test(
    'region shares the recording request lock while consent is pending',
    () async {
      final recorder = RegionRecorder()..pending = Completer();
      final capture = CaptureController(recorder, onSaved: () {});
      await Future<void>.delayed(Duration.zero);
      final first = capture.startRegion(
        const RecordingSettings(),
        const Rect.fromLTWH(2, 4, 200, 160),
      );
      await capture.startRegion(
        const RecordingSettings(),
        const Rect.fromLTWH(8, 10, 400, 300),
      );
      await capture.start(const RecordingSettings());
      expect(recorder.requests, [const Rect.fromLTWH(2, 4, 200, 160)]);
      recorder.pending!.complete(
        recorder.make(RecordingState.awaitingPermission),
      );
      await first;
      capture.dispose();
      await recorder.events.close();
    },
  );

  for (final width in [320.0, 411.0]) {
    testWidgets(
      'region maps physical pixels and remains usable at ${width}dp / 200%',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final recorder = RegionRecorder();
        final capture = CaptureController(recorder, onSaved: () {});
        final settings = SettingsController();
        await tester.pumpWidget(
          SettingsScope(
            controller: settings,
            child: CaptureScope(
              controller: capture,
              child: MaterialApp(
                theme: AppTheme.dark,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: const RegionCapturePage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(Slider), findsNWidgets(4));
        await tester.tap(find.text('Record screen'));
        await tester.pumpAndSettle();
        expect(recorder.requests, [const Rect.fromLTWH(108, 360, 864, 1200)]);
        await tester.pumpWidget(const SizedBox());
        capture.dispose();
        settings.dispose();
        await recorder.events.close();
      },
    );
  }

  testWidgets(
    'orientation changed before consent refreshes selection without recording',
    (tester) async {
      final recorder = RegionRecorder();
      final capture = CaptureController(recorder, onSaved: () {});
      final settings = SettingsController();
      await tester.pumpWidget(
        SettingsScope(
          controller: settings,
          child: CaptureScope(
            controller: capture,
            child: MaterialApp(
              theme: AppTheme.dark,
              home: const RegionCapturePage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      recorder.display = (width: 2400, height: 1080);
      await tester.tap(find.text('Record screen'));
      await tester.pumpAndSettle();
      expect(recorder.requests, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      capture.dispose();
      settings.dispose();
      await recorder.events.close();
    },
  );
}
