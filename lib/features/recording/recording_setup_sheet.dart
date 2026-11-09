import 'package:flutter/material.dart';

import '../../core/domain/models.dart';
import '../../core/widgets/studio_widgets.dart';
import '../settings/settings_controller.dart';
import '../settings/recording_settings_form.dart';
import 'recording_service.dart';

void validateRecordingSelection(
  RecordingSettings settings,
  RecordingCapabilities caps,
) {
  final longEdge = settings.width > settings.height
      ? settings.width
      : settings.height;
  final shortEdge = settings.width < settings.height
      ? settings.width
      : settings.height;
  final supported = caps.configurations.any(
    (c) =>
        c.width == longEdge &&
        c.height == shortEdge &&
        c.fps == settings.fps &&
        c.codec == settings.codec,
  );
  final exceedsPerformance =
      settings.mode == RecordingMode.performance &&
      (longEdge > 1280 ||
          shortEdge > 720 ||
          settings.fps > 30 ||
          (settings.bitrate ?? 0) > 8000000);
  if (!supported ||
      exceedsPerformance ||
      !caps.audioSources.contains(settings.audioSource)) {
    throw const DomainFailure(
      FailureCode.invalid,
      'The selected settings are unavailable. Choose a supported resolution, FPS, codec and audio source; Performance uses up to 720p, 30 FPS and 8 Mbps.',
    );
  }
}

Future<void> openRecordingSetup(BuildContext context) =>
    showStudioBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const RecordingSetupSheet(),
    );

class RecordingSetupSheet extends StatefulWidget {
  const RecordingSetupSheet({super.key});

  @override
  State<RecordingSetupSheet> createState() => _RecordingSetupSheetState();
}

class _RecordingSetupSheetState extends State<RecordingSetupSheet> {
  bool _advanced = false;
  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final capture = CaptureScope.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: .92,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StudioSheetHeader(
                  title: 'Recording settings',
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
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      for (final advanced in [false, true])
                        ChoiceChip(
                          label: Text(advanced ? 'Advanced' : 'Basic'),
                          selected: _advanced == advanced,
                          labelStyle: AppTypography.bodySmall.copyWith(
                            color: _advanced == advanced
                                ? context.studioColors.primary
                                : context.studioColors.text,
                          ),
                          onSelected: (_) =>
                              setState(() => _advanced = advanced),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    key: ValueKey(_advanced),
                    child: RecordingSettingsForm(advanced: _advanced),
                  ),
                ),
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
                      final caps = await capture.service.capabilities();
                      if (!context.mounted) return;
                      final selection = settings.recordingSnapshot;
                      validateRecordingSelection(selection, caps);
                      await capture.start(selection);
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
      ),
    );
  }
}
