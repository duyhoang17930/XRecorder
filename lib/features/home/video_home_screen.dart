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
              SizedBox(width: 8),
              Text('ScreenFlow', style: TextStyle(fontSize: 17)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '/  Video Studio',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.primary, fontSize: 16),
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
          padding: const EdgeInsets.all(16),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  const StudioBadge('PRO DESIGN', color: AppColors.primary),
                  const SizedBox(width: 8),
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
              StudioCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.storage, color: AppColors.primary),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Internal Storage',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '48.2 GB free / 128 GB total',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => unsupported(context, 'Clear cache'),
                          child: const Text(
                            'Clear Cache',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      child: LinearProgressIndicator(
                        value: .623,
                        minHeight: 8,
                        backgroundColor: AppColors.background,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            '● Video Captures (79.8 GB)',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                        Text(
                          '62% used',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
                          borderRadius: BorderRadius.circular(16),
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
                                const SizedBox(height: 8),
                                Text(
                                  tool.$2,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  tool.$3,
                                  style: const TextStyle(
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
                trailing: TextButton.icon(
                  onPressed: () => setState(() => latest = !latest),
                  icon: const Icon(Icons.swap_vert, size: 16),
                  label: Text(
                    latest ? 'Latest First' : 'Oldest First',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Today', '1080p 60fps', 'Gameplay', 'Work']
                      .map(
                        (label) => Padding(
                          padding: const EdgeInsets.only(right: 8),
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
              const SizedBox(height: 16),
              if (widget.empty)
                _empty(context)
              else
                ...videos.map(
                  (video) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: StudioCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MediaPreview(
                            asset: video.asset,
                            duration: video.duration,
                            badge: '${video.fps} FPS',
                            onTap: () => context.push('/media/${video.id}'),
                          ),
                          ListTile(
                            onTap: () => context.push('/media/${video.id}'),
                            title: Text(
                              video.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${video.category}  •  ${video.time}  •  ${video.size}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                            trailing: IconButton(
                              tooltip: 'Share sample',
                              onPressed: () => unsupported(context, 'Share'),
                              icon: const Icon(Icons.share_outlined, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (!widget.empty && videos.isEmpty)
                const StudioCard(
                  child: Text('No sample clips match this filter.'),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
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
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No recordings captured yet',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'Tap the orange record button below to configure your first gameplay or tutorial capture.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
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
