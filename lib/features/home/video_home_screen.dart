import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/widgets/studio_widgets.dart';
import '../media/mock_media_repository.dart';
import '../recording/recording_setup_sheet.dart';

class VideoHomeScreen extends StatefulWidget {
  const VideoHomeScreen({super.key, this.empty = false});
  final bool empty;
  @override
  State<VideoHomeScreen> createState() => _VideoHomeScreenState();
}

class _VideoHomeScreenState extends State<VideoHomeScreen> {
  String filter = 'All';
  String searchQuery = '';
  bool latest = true;
  @override
  Widget build(BuildContext context) {
    var videos = MockMediaRepository.videos
        .where(
          (v) =>
              filter == 'All' ||
              (filter == 'Today' && v.time.startsWith('Today')) ||
              (filter == '1080p 60fps' && v.fps == '60') ||
              filter == v.category,
        )
        .where(
          (v) =>
              searchQuery.isEmpty ||
              v.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
              v.category.toLowerCase().contains(searchQuery.toLowerCase()),
        )
        .toList();
    if (!latest) videos = videos.reversed.toList();
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          titleSpacing: 16,
          title: const Row(
            children: [
              Icon(Icons.movie_creation_outlined, color: AppColors.primary),
              SizedBox(width: AppSpacing.xs),
              Text('ScreenFlow', style: AppTypography.title),
              SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '/  Video Studio',
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.primaryTitle,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Audio & video settings',
              onPressed: () => context.push('/settings/audio-video'),
              icon: const Icon(Icons.tune),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.md),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  const StudioBadge('PRO DESIGN', color: AppColors.primary),
                  const SizedBox(width: AppSpacing.xs),
                  const StudioBadge('● READY'),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: 'Demo library options',
                    onSelected: (value) => context.go(value),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: '/videos/empty',
                        child: Text('Preview empty library'),
                      ),
                      const PopupMenuItem(
                        value: '/videos',
                        child: Text('Show sample videos'),
                      ),
                      const PopupMenuItem(
                        value: '/recording/completed',
                        child: Text('Preview completed recording'),
                      ),
                    ],
                  ),
                ],
              ),
              const MockBanner(),
              StudioSearchField(
                hintText: 'Search recordings',
                onChanged: (value) => setState(() => searchQuery = value),
              ),
              const SizedBox(height: AppSpacing.sm),
              StudioCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.storage, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.sm),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Internal Storage',
                                style: AppTypography.bodyEmphasis,
                              ),
                              Text(
                                '48.2 GB free / 128 GB total',
                                style: AppTypography.mutedCaption,
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => unsupported(context, 'Clear cache'),
                          child: const Text(
                            'Clear Cache',
                            style: AppTypography.caption,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      child: LinearProgressIndicator(
                        value: .623,
                        minHeight: 8,
                        backgroundColor: AppColors.background,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            '● Video Captures (79.8 GB)',
                            style: AppTypography.mutedMicro,
                          ),
                        ),
                        Text('62% used', style: AppTypography.bodyEmphasis),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  for (final tool in [
                    (Icons.draw_outlined, 'Brush', 'Draw Live'),
                    (Icons.camera_front, 'Facecam', 'PIP Mode'),
                    (Icons.screenshot_monitor, 'Snap', 'Instant PNG'),
                    (Icons.bubble_chart_outlined, 'HUD Ball', 'Preview'),
                  ])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          onTap: () => unsupported(context, tool.$2),
                          child: StudioCard(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 2,
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  tool.$1,
                                  color: tool.$2 == 'Snap'
                                      ? AppColors.cyan
                                      : AppColors.primary,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(tool.$2, style: AppTypography.caption),
                                Text(
                                  tool.$3,
                                  style: AppTypography.micro.copyWith(
                                    fontSize: 9,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SectionTitle(
                'Recorded Clips',
                trailing: SizedBox(
                  width: 148,
                  child: StudioDropdown<bool>(
                    value: latest,
                    items: const [
                      DropdownMenuItem(
                        value: true,
                        child: Text('Latest first'),
                      ),
                      DropdownMenuItem(
                        value: false,
                        child: Text('Oldest first'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => latest = value);
                    },
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Today', '1080p 60fps', 'Gameplay', 'Work']
                      .map(
                        (label) => Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: ChoiceChip(
                            label: Text(
                              label == 'All'
                                  ? 'All (${widget.empty ? 0 : 3})'
                                  : label,
                            ),
                            selected: filter == label,
                            onSelected: (_) => setState(() => filter = label),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (widget.empty)
                _empty(context)
              else
                StudioAnimatedSwitcher(
                  child: Column(
                    key: ValueKey('$filter:$searchQuery:$latest'),
                    children: [
                      ...videos.map(
                        (video) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: StudioCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MediaPreview(
                                  asset: video.asset,
                                  duration: video.duration,
                                  badge: '${video.fps} FPS',
                                  onTap: () =>
                                      context.push('/media/${video.id}'),
                                ),
                                ListTile(
                                  onTap: () =>
                                      context.push('/media/${video.id}'),
                                  title: Text(
                                    video.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodyEmphasis.copyWith(
                                      fontSize: 15,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${video.category}  •  ${video.time}  •  ${video.size}',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'Share sample',
                                    onPressed: () =>
                                        unsupported(context, 'Share'),
                                    icon: const Icon(
                                      Icons.share_outlined,
                                      size: AppIconSize.medium,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!widget.empty && videos.isEmpty)
                        const StudioEmptyState(
                          icon: Icons.search_off,
                          title: 'No recordings found',
                          description: 'Try changing your search or filter.',
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) => Column(
    children: [
      StudioCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.md),
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.elevated,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: .4),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.movie_filter_outlined,
                size: AppIconSize.hero,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No recordings captured yet',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Tap the orange record button below to configure your first gameplay or tutorial capture.',
              textAlign: TextAlign.center,
              style: AppTypography.mutedBody,
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              'Quick Test',
              icon: Icons.videocam_outlined,
              onPressed: () => openRecordingSetup(context),
            ),
            TextButton(
              onPressed: () => context.push('/settings/audio-video'),
              child: const Text('Parameters'),
            ),
          ],
        ),
      ),
      const SectionTitle('Studio Master Tips'),
      const StudioCard(
        child: Column(
          children: [
            SettingsRow(
              'Quick Shaking',
              icon: Icons.vibration,
              subtitle: 'Shake to stop capture · Future engine feature',
            ),
            Divider(),
            SettingsRow(
              'Hide Floating Ball',
              icon: Icons.visibility_off_outlined,
              subtitle: 'Clean capture overlays · Future engine feature',
            ),
          ],
        ),
      ),
      TextButton(
        onPressed: () => context.go('/videos'),
        child: const Text('Load sample library'),
      ),
    ],
  );
}
