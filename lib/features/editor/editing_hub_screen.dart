import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/widgets/studio_widgets.dart';

class EditingHubScreen extends StatelessWidget {
  const EditingHubScreen({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
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
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart Engine CFR 4K Ready',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Engine preview · Processing not connected',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
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
        borderRadius: BorderRadius.circular(16),
        onTap: () => unsupported(context, 'Video editing'),
        child: StudioCard(
          child: Column(
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.video_settings,
                    size: 40,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Video',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Trim, split, text, filters, audio multitrack',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward, color: AppColors.primary),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '4 Audio Stems  •  Keyframes  •  HDR Color',
                  style: TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
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
                borderRadius: BorderRadius.circular(16),
                onTap: () => unsupported(context, tool.$2),
                child: StudioCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(tool.$1, color: AppColors.primary),
                      const Spacer(),
                      Text(
                        tool.$2,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tool.$3,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
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
      const SizedBox(height: 12),
      StudioCard(
        padding: const EdgeInsets.all(8),
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
          padding: const EdgeInsets.only(bottom: 12),
          child: StudioCard(
            child: Column(
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/media/project_$i.jpg',
                        width: 104,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
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
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Sample project · Multitrack',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const StudioBadge('DRAFT PREVIEW'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => unsupported(context, 'Resume edit'),
                    icon: const Icon(Icons.play_arrow, size: 16),
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
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zero Re-encode Cut',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Future workflow: direct stream copy with original bitrate and no frame loss.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
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
