import 'package:flutter/widgets.dart';

import '../../core/constants/app_icons.dart';
import '../../core/domain/models.dart';

/// Presentation only. Native states, commands and session ownership stay intact.
class CaptureStatusPresentation {
  const CaptureStatusPresentation(this.label, this.icon);
  final String label;
  final IconData icon;

  factory CaptureStatusPresentation.from(
    RecordingSession? session, {
    String? error,
  }) {
    if (error != null || session?.state == RecordingState.failed) {
      return const CaptureStatusPresentation('Error', AppIcons.error);
    }
    if (session?.screenshot == true) {
      return switch (session!.state) {
        RecordingState.idle => const CaptureStatusPresentation(
          'Ready',
          AppIcons.ready,
        ),
        RecordingState.awaitingPermission => const CaptureStatusPresentation(
          'Allow screenshot',
          AppIcons.screenshot,
        ),
        RecordingState.countdown => CaptureStatusPresentation(
          'Screenshot in ${session.countdownRemaining.inSeconds}s',
          AppIcons.countdown,
        ),
        RecordingState.finalizing => const CaptureStatusPresentation(
          'Saving screenshot',
          AppIcons.screenshot,
        ),
        RecordingState.completed => const CaptureStatusPresentation(
          'Screenshot saved',
          AppIcons.ready,
        ),
        _ => const CaptureStatusPresentation(
          'Capturing screenshot',
          AppIcons.screenshot,
        ),
      };
    }
    return switch (session?.state ?? RecordingState.idle) {
      RecordingState.idle => const CaptureStatusPresentation(
        'Ready',
        AppIcons.ready,
      ),
      RecordingState.preparing => const CaptureStatusPresentation(
        'Preparing',
        AppIcons.processing,
      ),
      RecordingState.awaitingPermission => const CaptureStatusPresentation(
        'Allow screen capture',
        AppIcons.video,
      ),
      RecordingState.countdown => CaptureStatusPresentation(
        'Starting in ${session!.countdownRemaining.inSeconds}s',
        AppIcons.countdown,
      ),
      RecordingState.starting => const CaptureStatusPresentation(
        'Starting',
        AppIcons.processing,
      ),
      RecordingState.recording => const CaptureStatusPresentation(
        'Recording',
        AppIcons.record,
      ),
      RecordingState.paused => const CaptureStatusPresentation(
        'Paused',
        AppIcons.pause,
      ),
      RecordingState.stopping => const CaptureStatusPresentation(
        'Stopping',
        AppIcons.stop,
      ),
      RecordingState.finalizing => const CaptureStatusPresentation(
        'Processing',
        AppIcons.processing,
      ),
      RecordingState.completed => CaptureStatusPresentation(
        session!.screenshot ? 'Screenshot saved' : 'Saved',
        AppIcons.ready,
      ),
      RecordingState.failed => const CaptureStatusPresentation(
        'Error',
        AppIcons.error,
      ),
    };
  }
}
