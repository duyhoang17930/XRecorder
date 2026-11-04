import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/widgets/studio_widgets.dart';
import '../settings/settings_controller.dart';

Future<void> openRecordingSetup(BuildContext context) =>
    showModalBottomSheet<void>(
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
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune, color: AppColors.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Recording Parameters',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
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
              const Text(
                'Configure hardware encoders & capture stream',
                style: TextStyle(color: AppColors.muted),
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
                          style: const TextStyle(
                            color: AppColors.cyan,
                            fontWeight: FontWeight.w800,
                          ),
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
              const SizedBox(height: 24),
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
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Recording engine not connected'),
                    content: const Text(
                      'This baseline configures the UI only. No screen recording or countdown will start. You can preview the completed screen with sample media.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Close'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          Navigator.pop(context);
                          context.push('/recording/completed');
                        },
                        child: const Text('View sample result'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'No screen or microphone access is requested.',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
