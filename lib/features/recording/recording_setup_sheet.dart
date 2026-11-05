import 'package:flutter/material.dart';

import '../../core/widgets/studio_widgets.dart';
import '../settings/settings_controller.dart';
import '../settings/recording_settings_form.dart';
import 'recording_service.dart';

Future<void> openRecordingSetup(BuildContext context) =>
    showStudioBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const RecordingSetupSheet(),
    );

class RecordingSetupSheet extends StatelessWidget {
  const RecordingSetupSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final capture = CaptureScope.of(context);
    return FractionallySizedBox(
      heightFactor: .92,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudioSheetHeader(
                title: 'Recording Parameters',
                description: 'Android will ask permission to share your screen. Sensitive content visible on screen may be recorded.',
                icon: AppIcons.settings,
                actions: [
                  IconButton(
                    tooltip: 'Reset defaults',
                    onPressed: settings.reset,
                    icon: const Icon(AppIcons.reset),
                  ),
                  IconButton(
                    tooltip: 'Close setup',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(AppIcons.close),
                  ),
                ],
              ),
              const RecordingSettingsForm(),
              TextButton.icon(
                icon: const Icon(AppIcons.screenshot),
                label: const Text('Take screenshot (3-second delay)'),
                onPressed: capture.busy
                    ? null
                    : () async {
                        try {
                          await capture.screenshot();
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            showFailure(
                              context,
                              e,
                              operation: UserOperation.screenshot,
                            );
                          }
                        }
                      },
              ),
              PrimaryButton(
                capture.busy ? 'Session already active' : 'Start Recording',
                icon: AppIcons.record,
                onPressed: () async {
                  if (capture.busy) {
                    showNotice(
                      context,
                      'Stop the active session before starting another.',
                    );
                    return;
                  }
                  try {
                    await capture.start(settings.recordingSnapshot);
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) {
                      showFailure(
                        context,
                        e,
                        operation: UserOperation.recording,
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
