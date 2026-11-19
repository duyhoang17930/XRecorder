import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/app/theme/app_theme.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/widgets/studio_widgets.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

import 'fixtures/recorder.dart';

void main() {
  Future<void> start(WidgetTester tester, CaptureController controller) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CaptureScope(
          controller: controller,
          child: const Scaffold(body: CaptureStatusBar()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'native state events drive Pause, Resume, Processing and Saved at 200%',
    (tester) async {
      final service = TestRecorder();
      service.current = service.make(RecordingState.recording);
      final controller = CaptureController(service, onSaved: () {});
      final semantics = tester.ensureSemantics();
      try {
        await start(tester, controller);
        expect(find.text('Recording'), findsOneWidget);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await tester.tap(find.byTooltip('Pause'));
        await tester.pumpAndSettle();
        expect(service.pauseCalls, 1);
        expect(find.text('Paused'), findsOneWidget);
        expect(find.byIcon(AppIcons.play), findsOneWidget);
        await tester.tap(find.byTooltip('Resume'));
        await tester.pumpAndSettle();
        expect(service.resumeCalls, 1);
        expect(find.text('Recording'), findsOneWidget);
        await tester.tap(find.byTooltip('Stop'));
        // Saving shows an animated progress bar, so frames never settle here.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(service.stopCalls, 1);
        expect(find.text('Processing'), findsOneWidget);
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          isNull,
        );
        // Native snapshots and events both carry the latest save progress.
        service.current = RecordingSession(
          id: 'test',
          state: RecordingState.finalizing,
          configSnapshot: const RecordingSettings(),
          elapsedActive: Duration.zero,
          saveProgress: .42,
        );
        service.events.add(service.current!);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('42%'), findsOneWidget);
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          .42,
        );
        service.events.add(
          service.make(
            RecordingState.completed,
            output: Uri.parse('content://test/only'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Video saved'), findsOneWidget);
        expect(find.text('View'), findsOneWidget);
        expect(find.byTooltip('Pause'), findsNothing);
        await tester.tap(find.byTooltip('Dismiss capture notification'));
        await tester.pumpAndSettle();
        expect(find.text('Video saved'), findsNothing);
        service.events.add(
          RecordingSession(
            id: 'screenshot',
            state: RecordingState.completed,
            configSnapshot: const RecordingSettings(),
            elapsedActive: Duration.zero,
            screenshot: true,
            outputUri: Uri(
              scheme: 'content',
              host: 'test',
              path: '/screenshot',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Screenshot saved'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        await service.events.close();
      }
    },
  );

  testWidgets(
    'timer updates repaint status without changing footer reservation',
    (tester) async {
      final service = TestRecorder();
      service.current = service.make(RecordingState.recording);
      final controller = CaptureController(service, onSaved: () {});
      var footerChanges = 0;
      controller.footerVisible.addListener(() => footerChanges++);
      try {
        await start(tester, controller);
        expect(controller.footerVisible.value, isTrue);
        footerChanges = 0;
        service.events.add(
          RecordingSession(
            id: 'test',
            state: RecordingState.recording,
            configSnapshot: const RecordingSettings(),
            elapsedActive: const Duration(seconds: 12),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('00:12'), findsOneWidget);
        expect(footerChanges, 0);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        await service.events.close();
      }
    },
  );

  testWidgets(
    'failed Stop stays actionable and exposes error rather than claiming Saved',
    (tester) async {
      final service = TestRecorder()..stopFails = true;
      service.current = service.make(RecordingState.recording);
      final controller = CaptureController(service, onSaved: () {});
      try {
        await start(tester, controller);
        await tester.tap(find.byTooltip('Stop'));
        await tester.pumpAndSettle();
        expect(find.text('Error'), findsOneWidget);
        expect(
          find.text("Couldn't stop recording. Try again."),
          findsOneWidget,
        );
        expect(find.byIcon(AppIcons.error), findsOneWidget);
        expect(find.text('Saved'), findsNothing);
        expect(controller.session!.state, RecordingState.recording);
        expect(find.byTooltip('Stop'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        await service.events.close();
      }
    },
  );

  testWidgets('terminal errors use a compact status footer', (tester) async {
    final service = TestRecorder()
      ..current = RecordingSession(
        id: 'failed',
        state: RecordingState.failed,
        configSnapshot: const RecordingSettings(),
        elapsedActive: Duration.zero,
        error: const DomainFailure(
          FailureCode.io,
          'Android interrupted the previous recording.',
        ),
      );
    final controller = CaptureController(service, onSaved: () {});
    try {
      await start(tester, controller);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.textSpan?.toPlainText().startsWith('Error · ') == true,
        ),
        findsOneWidget,
      );
      expect(find.text('Help'), findsOneWidget);
      expect(find.byTooltip('Dismiss recording status'), findsOneWidget);
      expect(
        tester.getSize(find.byType(CaptureStatusBar)).height,
        lessThan(96),
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await service.events.close();
    }
  });
}
