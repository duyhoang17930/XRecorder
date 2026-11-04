import 'package:flutter/material.dart';

import 'recording_service.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/widgets/studio_widgets.dart';
import '../settings/settings_controller.dart';

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
    return FractionallySizedBox(
      heightFactor: .92,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StudioSheetHeader(
                title: 'Recording Parameters',
                description: 'Screen capture requires Android consent. Audio and quality configuration are not enabled yet.',
                icon: Icons.tune,
                actions: [
                  IconButton(
                    tooltip: 'Reset defaults',
                    onPressed: settings.reset,
                    icon: const Icon(Icons.restart_alt),
                  ),
                  IconButton(
                    tooltip: 'Close setup',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const MockBanner(),
              ChoiceGroup(
                label: 'Audio Source',
                options: const [
                  'Mute',
                  'Microphone',
                  'Internal Audio',
                  'Mixed Stream',
                ],
                value: settings.audio,
                onChanged: (v) => settings.update(() => settings.audio = v),
              ),
              StudioCard(
                color: AppColors.background,
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('Input Gain Calibration')),
                        Text(
                          '${settings.gain.round()}%',
                          style: AppTypography.cyanBodyEmphasis,
                        ),
                      ],
                    ),
                    Slider(
                      min: 80,
                      max: 200,
                      value: settings.gain,
                      activeColor: AppColors.cyan,
                      onChanged: (v) =>
                          settings.update(() => settings.gain = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ChoiceGroup(
                label: 'Resolution Preset',
                options: const [
                  '480p',
                  '720p HD',
                  '1080p FHD',
                  '2K QHD',
                  '4K UHD',
                ],
                value: settings.resolution,
                onChanged: (v) =>
                    settings.update(() => settings.resolution = v),
              ),
              ChoiceGroup(
                label: 'Target Frame Rate',
                options: const ['24', '30', '60', '90', '120'],
                value: settings.fps,
                onChanged: (v) => settings.update(() => settings.fps = v),
              ),
              ChoiceGroup(
                label: 'Bitrate Encoding',
                options: const [
                  'Auto',
                  '8 Mbps',
                  '12 Mbps',
                  '16 Mbps',
                  '24 Mbps',
                ],
                value: settings.bitrate,
                onChanged: (v) => settings.update(() => settings.bitrate = v),
              ),
              ChoiceGroup(
                label: 'Canvas Orientation',
                options: const ['Auto Sensor', 'Landscape', 'Portrait'],
                value: settings.orientation,
                onChanged: (v) =>
                    settings.update(() => settings.orientation = v),
              ),
              ChoiceGroup(
                label: 'Countdown Delay',
                options: const ['Off', '3s', '5s', '10s'],
                value: settings.countdown,
                onChanged: (v) => settings.update(() => settings.countdown = v),
              ),
              PrimaryButton(
                'Start Recording',
                icon: Icons.fiber_manual_record,
                onPressed: () async {
                  final capture = CaptureScope.of(context);
                  try {
                    await capture.start(settings.recordingSnapshot);
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) showNotice(context, e.toString());
                  }
                },
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Recording MVP: silent H.264 video targeting up to 30 FPS, with an automatic screen-sized resolution up to 1280 pixels. Preferences above are not applied until recording configuration ships. Android will ask permission to capture your screen.',
                style: AppTypography.mutedCaption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
