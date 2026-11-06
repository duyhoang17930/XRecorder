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
        await tester.tap(find.text('Pause'));
        await tester.pumpAndSettle();
        expect(service.pauseCalls, 1);
        expect(find.text('Paused'), findsOneWidget);
        expect(find.byIcon(AppIcons.play), findsOneWidget);
        await tester.tap(find.text('Resume'));
        await tester.pumpAndSettle();
        expect(service.resumeCalls, 1);
        expect(find.text('Recording'), findsOneWidget);
        await tester.tap(find.text('Stop'));
        await tester.pumpAndSettle();
        expect(service.stopCalls, 1);
        expect(find.text('Processing'), findsOneWidget);
        service.events.add(
          service.make(
            RecordingState.completed,
            output: Uri.parse('content://test/only'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Video saved'), findsOneWidget);
        expect(find.text('View'), findsOneWidget);
        expect(find.text('Pause'), findsNothing);
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
    'failed Stop stays actionable and exposes error rather than claiming Saved',
    (tester) async {
      final service = TestRecorder()..stopFails = true;
      service.current = service.make(RecordingState.recording);
      final controller = CaptureController(service, onSaved: () {});
      try {
        await start(tester, controller);
        await tester.tap(find.text('Stop'));
        await tester.pumpAndSettle();
        expect(find.text('Error'), findsOneWidget);
        expect(
          find.text("Couldn't stop recording. Try again."),
          findsOneWidget,
        );
        expect(find.byIcon(AppIcons.error), findsOneWidget);
        expect(find.text('Saved'), findsNothing);
        expect(controller.session!.state, RecordingState.recording);
        expect(find.text('Stop'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        await service.events.close();
      }
    },
  );
}
