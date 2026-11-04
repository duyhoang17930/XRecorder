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
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Row(
          children: [
            Icon(
              Icons.movie_creation_outlined,
              color: AppColors.primary,
              size: 32,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SCREENFLOW',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    'Photo Gallery',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
        const MockBanner(),
        const SizedBox(height: 16),
        const Row(
          children: [
            StudioBadge('● 1.4 GB USED'),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '100% Lossless PNG',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Today', 'This Week', 'Favorites']
                .map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(right: 8),
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
                borderRadius: BorderRadius.circular(16),
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
                          gradient: LinearGradient(
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black],
                          ),
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
                              : Colors.white,
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
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              MockMediaRepository.photos[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
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
          const StudioCard(
            child: Text('No favorites yet. Tap a heart to add a sample photo.'),
          ),
        const SizedBox(height: 24),
        StudioCard(
          child: Row(
            children: [
              const Icon(Icons.auto_fix_high, color: AppColors.cyan, size: 32),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Stitch & Crop',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Merge scrolling chat receipts seamlessly',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
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
        const SizedBox(height: 24),
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

  void _preview(BuildContext context, int i) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Image.asset(
              'assets/media/photo_$i.jpg',
              fit: BoxFit.contain,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(MockMediaRepository.photos[i]),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close sample preview'),
          ),
        ],
      ),
    ),
  );
}
