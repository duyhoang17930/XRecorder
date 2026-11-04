import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/widgets/studio_widgets.dart';

class EditingHubScreen extends StatelessWidget {
  const EditingHubScreen({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.md),
    children: [
      const SectionTitle(
        'Editing Studio',
        trailing: StudioBadge('PRO DESIGN', color: AppColors.primary),
      ),
      const MockBanner(),
      const StudioCard(
        child: Row(
          children: [
            Icon(Icons.bolt, color: AppColors.cyan),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart Engine CFR 4K Ready',
                    style: AppTypography.bodyEmphasis,
                  ),
                  Text(
                    'Engine preview · Processing not connected',
                    style: AppTypography.mutedCaption,
                  ),
                ],
              ),
            ),
            StudioBadge('60 FPS'),
          ],
        ),
      ),
      const SectionTitle('Workstation Tools'),
      InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => unsupported(context, 'Video editing'),
        child: StudioCard(
          child: Column(
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.video_settings,
                    size: AppIconSize.featureLarge,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit Video', style: AppTypography.headline),
                        Text(
                          'Trim, split, text, filters, audio multitrack',
                          style: AppTypography.mutedCaption,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward, color: AppColors.primary),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              StudioInset(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: const Text(
                  '4 Audio Stems  •  Keyframes  •  HDR Color',
                  style: AppTypography.mutedMicro,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      LayoutBuilder(
        builder: (context, constraints) => GridView.count(
          crossAxisCount: constraints.maxWidth > 600 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 176 * MediaQuery.textScalerOf(context).scale(1),
          children: [
            for (final tool in [
              (
                Icons.content_cut,
                'Trim & Cut',
                'Lossless fast cut without re-encoding',
              ),
              (
                Icons.join_inner,
                'Merge Clips',
                'Combine multiple recordings into one timeline',
              ),
              (
                Icons.gif_box_outlined,
                'Video to GIF',
                'Export lightweight animated loops',
              ),
              (
                Icons.compress,
                'Compress Video',
                'Shrink file size for Discord & WhatsApp',
              ),
            ])
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.card),
                onTap: () => unsupported(context, tool.$2),
                child: StudioCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(tool.$1, color: AppColors.primary),
                      const Spacer(),
                      Text(tool.$2, style: AppTypography.bodyEmphasis),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        tool.$3,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      StudioCard(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: SettingsRow(
          'Edit Photo & Annotate',
          icon: Icons.draw_outlined,
          subtitle: 'Markup, crop, blur sensitive info, OCR text',
          onTap: () => unsupported(context, 'Photo editing'),
        ),
      ),
      const SectionTitle(
        'Recent Projects',
        trailing: StudioBadge('2 SAMPLES', color: AppColors.primary),
      ),
      for (var i = 0; i < 2; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: StudioCard(
            child: Column(
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.icon),
                      child: Image.asset(
                        'assets/media/project_$i.jpg',
                        width: 104,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i == 0
                                ? 'Apex Drift Highlights'
                                : 'Flutter Tutorial Repro',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyEmphasis,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          const Text(
                            'Sample project · Multitrack',
                            style: AppTypography.mutedCaption,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const StudioBadge('DRAFT PREVIEW'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => unsupported(context, 'Resume edit'),
                    icon: const Icon(Icons.play_arrow, size: AppIconSize.small),
                    label: const Text('Resume Edit'),
                  ),
                ),
              ],
            ),
          ),
        ),
      const StudioCard(
        color: AppColors.surface,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.tips_and_updates_outlined, color: AppColors.cyan),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Zero Re-encode Cut', style: AppTypography.bodyEmphasis),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    'Future workflow: direct stream copy with original bitrate and no frame loss.',
                    style: AppTypography.mutedBodySmall,
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
