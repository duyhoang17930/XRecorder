import 'package:flutter/material.dart';

import '../../core/domain/models.dart';
import '../../core/widgets/studio_widgets.dart';
import 'media_repository.dart';
import 'media_library_screen.dart';

class VideoDetailsScreen extends StatefulWidget {
  const VideoDetailsScreen({super.key, required this.id});
  final String id;
  @override
  State<VideoDetailsScreen> createState() => _VideoDetailsScreenState();
}

class _VideoDetailsScreenState extends State<VideoDetailsScreen> {
  Future<MediaItem?>? _item;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _item ??= MediaScope.of(context).find(widget.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Media details')),
    body: FutureBuilder<MediaItem?>(
      future: _item,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    snapshot.hasError
                        ? snapshot.error.toString()
                        : 'Media unavailable',
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => _item = MediaScope.of(context).find(widget.id),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final item = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: MediaThumbnail(item: item),
            ),
            SectionTitle(item.displayName),
            ListTile(
              title: const Text('Size'),
              subtitle: Text(formatBytes(item.sizeBytes)),
            ),
            ListTile(
              title: const Text('Format'),
              subtitle: Text(item.mimeType),
            ),
            if (item.duration != null)
              ListTile(
                title: const Text('Duration'),
                subtitle: Text('${item.duration!.inSeconds} seconds'),
              ),
            if (item.width != null)
              ListTile(
                title: const Text('Dimensions'),
                subtitle: Text('${item.width} × ${item.height}'),
              ),
            const Text(
              'Playback, sharing, and file actions will be enabled after the media-actions phase.',
            ),
          ],
        );
      },
    ),
  );
}
