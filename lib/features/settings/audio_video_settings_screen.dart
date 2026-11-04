import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/widgets/studio_widgets.dart';
import 'settings_controller.dart';

class AudioVideoSettingsScreen extends StatelessWidget {
  const AudioVideoSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Audio & Video Settings')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                StudioCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.fiber_manual_record,
                        color: AppColors.primary,
                        size: AppIconSize.tiny,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'EST. BITSTREAM LOAD',
                              style: AppTypography.mutedMicro,
                            ),
                            Text(
                              '${s.resolution} · ${s.fps} FPS · ${s.bitrate}',
                              style: AppTypography.primaryBodyEmphasis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const MockBanner(),
                const SectionTitle(
                  'Video Parameters',
                  trailing: StudioBadge(
                    'MASTER BUS A',
                    color: AppColors.primary,
                  ),
                ),
                StudioCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ChoiceGroup(
                        label: 'Resolution',
                        options: const [
                          '720p HD',
                          '1080p FHD',
                          '2K QHD',
                          '4K UHD',
                        ],
                        value: s.resolution,
                        onChanged: (v) => s.update(() => s.resolution = v),
                      ),
                      ChoiceGroup(
                        label: 'Frame Rate (FPS)',
                        options: const ['24', '30', '60', '90', '120'],
                        value: s.fps,
                        onChanged: (v) => s.update(() => s.fps = v),
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
                        value: s.bitrate,
                        onChanged: (v) => s.update(() => s.bitrate = v),
                      ),
                      const Text(
                        'Video Codec',
                        style: AppTypography.bodyEmphasis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      for (final codec in ['H.264 / AVC', 'H.265 / HEVC'])
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              AppRadius.control,
                            ),
                            onTap: () => s.update(() => s.codec = codec),
                            child: StudioCard(
                              color: s.codec == codec
                                  ? AppColors.overlay
                                  : AppColors.elevated,
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Row(
                                children: [
                                  Icon(
                                    s.codec == codec
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: s.codec == codec
                                        ? AppColors.primary
                                        : AppColors.muted,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          codec,
                                          style: AppTypography.bodyEmphasis,
                                        ),
                                        Text(
                                          codec.startsWith('H.264')
                                              ? 'Recommended · Maximum player compatibility'
                                              : 'High efficiency · Modern playback processors',
                                          style: AppTypography.mutedCaption,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      ChoiceGroup(
                        label: 'Screen Orientation',
                        options: const ['Auto Sensor', 'Landscape', 'Portrait'],
                        value: s.orientation,
                        onChanged: (v) => s.update(() => s.orientation = v),
                      ),
                    ],
                  ),
                ),
                const SectionTitle(
                  'Audio Architecture',
                  trailing: StudioBadge('STEREO 48kHz'),
                ),
                StudioCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Audio Capture Matrix',
                        style: AppTypography.bodyEmphasis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      for (final source in [
                        'Mute',
                        'Microphone',
                        'Internal Audio',
                        'Mixed Stream',
                      ])
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            source == 'Mute'
                                ? Icons.mic_off_outlined
                                : Icons.graphic_eq,
                            color: s.audio == source
                                ? AppColors.primary
                                : AppColors.muted,
                          ),
                          title: Text(source, style: AppTypography.body),
                          trailing: Icon(
                            s.audio == source
                                ? Icons.check_circle
                                : Icons.radio_button_off,
                            color: s.audio == source
                                ? AppColors.primary
                                : AppColors.disabled,
                          ),
                          onTap: () => s.update(() => s.audio = source),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Microphone Gain Booster'),
                          ),
                          Text(
                            '${s.gain.round()}%',
                            style: AppTypography.primaryBodyEmphasis,
                          ),
                        ],
                      ),
                      Slider(
                        min: 80,
                        max: 200,
                        divisions: 120,
                        label: '${s.gain.round()}%',
                        value: s.gain,
                        onChanged: (v) => s.update(() => s.gain = v),
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('80%', style: AppTypography.mutedCaption),
                          Text('100% Unity', style: AppTypography.mutedCaption),
                          Text('200%', style: AppTypography.mutedCaption),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const StudioBadge(
                        'Sample meter · No microphone connected',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const LinearProgressIndicator(
                        value: .72,
                        minHeight: 6,
                        color: AppColors.cyan,
                        backgroundColor: AppColors.overlay,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const Row(
                        children: [
                          Expanded(
                            child: StudioCard(
                              color: AppColors.elevated,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SAMPLE RATE',
                                    style: AppTypography.mutedMicro,
                                  ),
                                  Text('48.0 kHz'),
                                  Text(
                                    'Studio Quality',
                                    style: AppTypography.cyanMicro,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: StudioCard(
                              color: AppColors.elevated,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CHANNEL ARRAY',
                                    style: AppTypography.mutedMicro,
                                  ),
                                  Text('Stereo'),
                                  Text(
                                    '2 Discrete Ch (L/R)',
                                    style: AppTypography.mutedMicro,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SectionTitle('Performance & Stability'),
                StudioCard(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Column(
                    children: [
                      SettingsRow(
                        'Constant Frame Rate (CFR)',
                        icon: Icons.speed,
                        subtitle: 'Avoid audio desynchronization',
                        value: s.cfr,
                        onChanged: (v) => s.update(() => s.cfr = v),
                      ),
                      const Divider(),
                      SettingsRow(
                        'Hardware Acceleration',
                        icon: Icons.memory,
                        subtitle: 'Dedicated encoder preference',
                        value: s.hardware,
                        onChanged: (v) => s.update(() => s.hardware = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: s.reset,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Restore Defaults'),
                ),
                const SizedBox(height: AppSpacing.xs),
                PrimaryButton(
                  'Apply Config',
                  icon: Icons.check,
                  onPressed: () => showNotice(
                    context,
                    'UI configuration applied for this session. Recording engine is not connected.',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
