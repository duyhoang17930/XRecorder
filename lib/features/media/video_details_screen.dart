import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/widgets/studio_widgets.dart';
import 'mock_media_repository.dart';

class VideoDetailsScreen extends StatefulWidget {
  const VideoDetailsScreen({super.key, required this.id});
  final String id;
  @override
  State<VideoDetailsScreen> createState() => _VideoDetailsScreenState();
}

class _VideoDetailsScreenState extends State<VideoDetailsScreen> {
  final notes = TextEditingController(
    text: 'Drift segment test in Sector 4 with high FPS HUD',
  );
  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MockMediaRepository.find(widget.id);
    if (media == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Media unavailable')),
        body: Center(
          child: TextButton(
            onPressed: () => context.go('/videos'),
            child: const Text('Return to library'),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Item Detail'),
        actions: [
          IconButton(
            tooltip: 'Share video',
            onPressed: () => unsupported(context, 'Share video'),
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(media.name, style: AppTypography.mutedBodySmall),
                const MockBanner(),
                MediaPreview(
                  asset: media.id == 'apex'
                      ? 'assets/media/detail_0.jpg'
                      : media.asset,
                  duration: media.duration,
                  badge: '${media.fps} FPS · SAMPLE PREVIEW',
                  onTap: () => unsupported(context, 'Video playback'),
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  'Edit in Studio',
                  icon: Icons.content_cut,
                  onPressed: () => context.go('/editor'),
                ),
                const SizedBox(height: AppSpacing.xs),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final action in [
                        (Icons.share_outlined, 'Share Video'),
                        (Icons.music_note, 'Extract Audio (MP3)'),
                        (Icons.content_cut, 'Quick Trim'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: OutlinedButton.icon(
                            onPressed: () => unsupported(context, action.$2),
                            icon: Icon(action.$1, size: AppIconSize.small),
                            label: Text(
                              action.$2,
                              style: AppTypography.caption,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StudioBadge(
                      'SOURCE · ${media.category}',
                      color: AppColors.muted,
                    ),
                    const StudioBadge('AUDIO · Internal Audio + Mic'),
                  ],
                ),
                const SectionTitle(
                  'Technical Telemetry',
                  trailing: StudioBadge('MP4 / MPEG-4', color: AppColors.muted),
                ),
                StudioCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) => Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final stat in [
                              (
                                'RESOLUTION',
                                media.resolution,
                                'Full High Definition',
                              ),
                              (
                                'FRAME RATE',
                                '${media.fps}.00 FPS',
                                'Constant Frame Rate',
                              ),
                              (
                                'TOTAL BITRATE',
                                '12.4 Mbps',
                                'Target Peak: 15.0 Mbps',
                              ),
                              (
                                'VIDEO CODEC',
                                'H.264 / AVC',
                                'Hardware Accel · Sample',
                              ),
                              (
                                'AUDIO FORMAT',
                                'Stereo 48 kHz',
                                'AAC-LC 192 kbps',
                              ),
                              (
                                'FILE WEIGHT',
                                media.size,
                                'Sample media metadata',
                              ),
                            ])
                              SizedBox(
                                width: (constraints.maxWidth - 8) / 2,
                                child: StudioCard(
                                  color: AppColors.surface,
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        stat.$1,
                                        style: AppTypography.metricLabel,
                                      ),
                                      const SizedBox(height: AppSpacing.xxs),
                                      Text(
                                        stat.$2,
                                        style: AppTypography.metric,
                                      ),
                                      const SizedBox(height: AppSpacing.xxs),
                                      Text(
                                        stat.$3,
                                        style: AppTypography.metricAccent,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'STORAGE DIRECTORY',
                        style: AppTypography.mutedMicro,
                      ),
                      const Text(
                        'Internal > DCIM > ScreenFlow · Sample path',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                StudioCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Audio Track Scrubber Peak',
                        style: AppTypography.bodyEmphasis,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        height: 40,
                        child: LayoutBuilder(
                          builder: (context, c) => Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(
                              40,
                              (i) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  child: Container(
                                    height: 8.0 + (i * 17 % 32),
                                    decoration: BoxDecoration(
                                      color: i % 9 == 0
                                          ? AppColors.primary
                                          : AppColors.cyan,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.waveform,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Sample waveform · No live audio signal',
                        style: AppTypography.mutedMicro,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                StudioCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Director Quick Notes',
                        style: AppTypography.title,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      StudioTextField(
                        controller: notes,
                        maxLines: 3,
                        hintText: 'Add a session note',
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Editable preview · Notes reset when this page closes',
                        style: AppTypography.mutedMicro,
                      ),
                    ],
                  ),
                ),
                const SectionTitle(
                  'Same Session Takes',
                  trailing: StudioBadge('SAMPLES', color: AppColors.primary),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 1; i <= 2; i++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i == 1 ? 8 : 0),
                          child: InkWell(
                            onTap: () =>
                                unsupported(context, 'Session take playback'),
                            child: StudioCard(
                              padding: const EdgeInsets.all(AppSpacing.xs),
                              child: Column(
                                children: [
                                  AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: Image.asset(
                                      'assets/media/detail_$i.jpg',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    i == 1
                                        ? 'Apex_Sector04_Take01.mp4'
                                        : 'Apex_Sector04_Replay.mp4',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption,
                                  ),
                                  const Text(
                                    '1080p 60fps · Sample',
                                    style: AppTypography.mutedMicro,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
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
