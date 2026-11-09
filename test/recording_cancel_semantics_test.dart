import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

import 'fixtures/recorder.dart';

void main() {
  testWidgets(
    'platform semantics client owns a separate handle and releases it on detach',
    (tester) async {
      final binding = tester.binding;
      final before = binding.debugOutstandingSemanticsHandles;
      try {
        binding.platformDispatcher.semanticsEnabledTestValue = true;
        expect(binding.debugOutstandingSemanticsHandles, before + 1);
      } finally {
        binding.platformDispatcher.clearSemanticsEnabledTestValue();
      }
      expect(binding.debugOutstandingSemanticsHandles, before);
    },
  );
  for (final state in [
    RecordingState.countdown,
    RecordingState.recording,
    RecordingState.paused,
    RecordingState.awaitingPermission,
  ]) {
    testWidgets(
      'cancel ${state.name} returns Idle without Saved or semantics leaks locally',
      (tester) async {
        final handles = tester.binding.debugOutstandingSemanticsHandles;
        final service = TestRecorder()..current = TestRecorder().make(state);
        var saved = 0;
        final controller = CaptureController(service, onSaved: () => saved++);
        try {
          await controller.refresh();
          await tester.pumpWidget(
            MaterialApp(
              home: AnimatedBuilder(
                animation: controller,
                builder: (_, _) => Text(controller.session!.state.name),
              ),
            ),
          );
          expect(controller.busy, isTrue);
          await service.cancel(controller.session!.id);
          await tester.pump();
          expect(controller.session!.state, RecordingState.idle);
          expect(controller.session!.outputUri, isNull);
          expect(controller.busy, isFalse);
          expect(saved, 0);
          expect(find.text('idle'), findsOneWidget);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
          await service.events.close();
        }
        expect(tester.binding.debugOutstandingSemanticsHandles, handles);
        // testWidgets also retains its normal end-of-test semantics validation.
      },
    );
  }
}
