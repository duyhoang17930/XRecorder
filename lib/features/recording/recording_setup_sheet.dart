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
                title: 'Recording settings',
                description: 'Your device may ask for screen access before recording. Visible content may be captured.',
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
                label: const Text('Screenshot · 3s delay'),
                onPressed: capture.busy
                    ? null
                    : () async {
                        final target = Navigator.of(context).context;
                        Navigator.pop(context);
                        try {
                          await capture.screenshot();
                        } catch (e) {
                          if (target.mounted) {
                            showFailure(
                              target,
                              e,
                              operation: UserOperation.screenshot,
                            );
                          }
                        }
                      },
              ),
              Text(
                'Screenshot minimizes the app after approval.',
                style: AppTypography.caption.copyWith(
                  color: context.studioColors.muted,
                ),
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
