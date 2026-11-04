import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/widgets/studio_widgets.dart';
import '../media/mock_media_repository.dart';

class RecordingCompletedScreen extends StatelessWidget {
  const RecordingCompletedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    const media = MockMediaRepository.completed;
    return Scaffold(
      appBar: AppBar(title: const Text('Recording Completed · Sample')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                const StudioCard(
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: AppColors.cyan),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recording Finalized · Demo',
                              style: AppTypography.bodyStrong,
                            ),
                            Text(
                              'Sample result · No recording was created',
                              style: AppTypography.mutedBodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                MediaPreview(
                  asset: media.asset,
                  duration: media.duration,
                  badge: '1080p · 60 FPS · HIGH BITRATE',
                  onTap: () => context.push('/media/apex'),
                ),
                const SizedBox(height: AppSpacing.md),
                StudioCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        media.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          Text(media.time),
                          Text(media.size),
                          const Text('AAC 48kHz Stereo'),
                          const Text('DCIM/ScreenFlow · Sample path'),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StudioBadge('● Gameplay', color: AppColors.primary),
                          StudioBadge('● Pro Preset'),
                          StudioBadge('High FPS', color: AppColors.muted),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  'Edit Clip · Open Studio',
                  icon: Icons.content_cut,
                  onPressed: () => context.go('/editor'),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.push('/media/apex'),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Preview'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => unsupported(context, 'Share'),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => unsupported(context, 'Delete sample'),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  ],
                ),
                const SectionTitle(
                  'Quick Workflows',
                  trailing: StudioBadge('PREVIEW'),
                ),
                StudioCard(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Column(
                    children: [
                      SettingsRow(
                        'Trim & Polish',
                        icon: Icons.tune,
                        subtitle: 'Cut intro and outro deadzones in 1-tap',
                        onTap: () => unsupported(context, 'Trim & Polish'),
                      ),
                      SettingsRow(
                        'Extract Audio',
                        icon: Icons.music_note,
                        subtitle: 'Save clean soundtrack & voiceover as MP3',
                        onTap: () => unsupported(context, 'Extract audio'),
                      ),
                      SettingsRow(
                        'Discord/WhatsApp Compress',
                        icon: Icons.compress,
                        subtitle: 'Downsample for smaller sharing payloads',
                        onTap: () => unsupported(context, 'Compression'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextButton.icon(
                  onPressed: () => context.go('/videos'),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Return to ScreenFlow Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
