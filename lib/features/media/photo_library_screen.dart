import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';
import '../../core/widgets/studio_widgets.dart';
import 'mock_media_repository.dart';

class PhotoLibraryScreen extends StatefulWidget {
  const PhotoLibraryScreen({super.key});
  @override
  State<PhotoLibraryScreen> createState() => _PhotoLibraryScreenState();
}

class _PhotoLibraryScreenState extends State<PhotoLibraryScreen> {
  String filter = 'All';
  String searchQuery = '';
  final favorites = <int>{};
  @override
  Widget build(BuildContext context) {
    final indices = List.generate(6, (i) => i)
        .where(
          (i) =>
              filter == 'All' ||
              filter == 'This Week' ||
              (filter == 'Today' && i < 3) ||
              (filter == 'Favorites' && favorites.contains(i)),
        )
        .where(
          (i) => MockMediaRepository.photos[i].toLowerCase().contains(
            searchQuery.toLowerCase(),
          ),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          children: [
            Icon(
              Icons.movie_creation_outlined,
              color: AppColors.primary,
              size: AppIconSize.feature,
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SCREENFLOW',
                    style: AppTypography.overline.copyWith(
                      color: AppColors.primary,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                  Text('Photo Gallery', style: AppTypography.display),
                ],
              ),
            ),
          ],
        ),
        const MockBanner(),
        StudioSearchField(
          hintText: 'Search photos',
          onChanged: (value) => setState(() => searchQuery = value),
        ),
        const SizedBox(height: AppSpacing.md),
        const Row(
          children: [
            StudioBadge('● 1.4 GB USED'),
            SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                '100% Lossless PNG',
                style: AppTypography.mutedBodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Today', 'This Week', 'Favorites']
                .map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: ChoiceChip(
                      label: Text(f),
                      selected: f == filter,
                      onSelected: (_) => setState(() => filter = f),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SectionTitle('Timeline Capture', trailing: StudioBadge('DEMO')),
        LayoutBuilder(
          builder: (context, constraints) => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: indices.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: constraints.maxWidth > 600 ? 4 : 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: .58,
            ),
            itemBuilder: (context, index) {
              final i = indices[index];
              return Material(
                color: AppColors.card,
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Ink.image(
                      image: AssetImage('assets/media/photo_$i.jpg'),
                      fit: BoxFit.cover,
                      child: InkWell(onTap: () => _preview(context, i)),
                    ),
                    const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppGradients.photoScrim,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        tooltip: favorites.contains(i)
                            ? 'Remove favorite'
                            : 'Favorite photo',
                        onPressed: () => setState(
                          () => favorites.contains(i)
                              ? favorites.remove(i)
                              : favorites.add(i),
                        ),
                        icon: Icon(
                          favorites.contains(i)
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: favorites.contains(i)
                              ? AppColors.primary
                              : AppColors.text,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: IgnorePointer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [
                                '09:41',
                                '10:14',
                                '11:02',
                                '11:58',
                                '12:30',
                                '13:15',
                              ][i],
                              style: AppTypography.timecode,
                            ),
                            Text(
                              MockMediaRepository.photos[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.badge,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (indices.isEmpty)
          const StudioEmptyState(
            icon: Icons.search_off,
            title: 'No photos found',
            description: 'Try changing your search or filter.',
          ),
        const SizedBox(height: AppSpacing.lg),
        StudioCard(
          child: Row(
            children: [
              const Icon(
                Icons.auto_fix_high,
                color: AppColors.cyan,
                size: AppIconSize.feature,
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Smart Stitch & Crop', style: AppTypography.title),
                    Text(
                      'Merge scrolling chat receipts seamlessly',
                      style: AppTypography.mutedBodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Assemble',
                onPressed: () => unsupported(context, 'Smart Stitch'),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () => unsupported(context, 'Instant Snap'),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Instant Snap'),
          ),
        ),
      ],
    );
  }

  void _preview(BuildContext context, int i) => showStudioDialog<void>(
    context: context,
    builder: (context) => StudioDialog(
      contentPadding: EdgeInsets.zero,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Image.asset(
              'assets/media/photo_$i.jpg',
              fit: BoxFit.contain,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(MockMediaRepository.photos[i]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close sample preview'),
            ),
          ),
        ],
      ),
    ),
  );
}
