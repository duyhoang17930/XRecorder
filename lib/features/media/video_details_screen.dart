import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/domain/models.dart';
import '../../core/widgets/studio_widgets.dart';
import 'media_repository.dart';
import 'media_library_screen.dart';
import 'media_actions.dart';

class VideoDetailsScreen extends StatefulWidget {
  const VideoDetailsScreen({super.key, required this.id});
  final String id;
  @override
  State<VideoDetailsScreen> createState() => _VideoDetailsScreenState();
}

class _VideoDetailsScreenState extends State<VideoDetailsScreen> {
  Future<MediaItem?>? _item;
  final actions = AndroidMediaActions();
  bool busy = false;
  void reloadItem() {
    if (!mounted) return;
    final next = MediaScope.of(context).find(widget.id);
    setState(() {
      _item = next;
    });
  }

  Future<void> run(
    Future<void> Function() operation, {
    UserOperation purpose = UserOperation.openMedia,
  }) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await operation();
    } catch (e) {
      if (mounted) showFailure(context, e, operation: purpose);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> rename(MediaItem item) async {
    final field = TextEditingController(text: item.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename media'),
        content: TextField(
          controller: field,
          maxLength: 120,
          decoration: const InputDecoration(labelText: 'Filename'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, field.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    field.dispose();
    if (name == null || !mounted) return;
    await run(() async {
      final id = await actions.rename(item.uri, name);
      if (!mounted) return;
      MediaScope.of(context).refresh();
      if (id != widget.id) {
        context.pushReplacement('/media/${Uri.encodeComponent(id)}');
      } else {
        reloadItem();
      }
    }, purpose: UserOperation.rename);
  }

  Future<void> trash(MediaItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Trash?'),
        content: Text(
          '${item.displayName} will be copied to private trash, then removed from the library. It becomes eligible for permanent cleanup after 24 hours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await run(() async {
      await actions.trash(item);
      if (mounted) {
        MediaScope.of(context).refresh();
        context.pop();
      }
    }, purpose: UserOperation.trash);
  }

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
                        ? UserMessages.failure(
                            snapshot.error,
                            operation: UserOperation.openMedia,
                          ).text
                        : 'Media unavailable',
                  ),
                  TextButton(onPressed: reloadItem, child: const Text('Retry')),
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
            if (busy) const LinearProgressIndicator(),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          if (item.kind == MediaKind.video) {
                            await actions.preview(item.uri);
                          } else {
                            context.push(
                              '/photo-preview/${Uri.encodeComponent(item.id)}',
                            );
                          }
                        }),
                  icon: const Icon(AppIcons.play),
                  label: const Text('Preview'),
                ),
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          await actions.share(item.uri);
                        }, purpose: UserOperation.share),
                  icon: const Icon(AppIcons.share),
                  label: const Text('Share'),
                ),
                if (item.owned)
                  TextButton.icon(
                    onPressed: busy ? null : () => rename(item),
                    icon: const Icon(AppIcons.rename),
                    label: const Text('Rename'),
                  ),
                if (item.owned)
                  TextButton.icon(
                    onPressed: busy ? null : () => trash(item),
                    icon: const Icon(AppIcons.trash),
                    label: const Text('Move to Trash'),
                  ),
              ],
            ),
            if (!item.owned)
              const Text(
                'External media is read-only here. Use the owning app to rename or delete it.',
              ),
            if (item.kind == MediaKind.image)
              TextButton.icon(
                onPressed: () => context.push(
                  '/photo-tools/${Uri.encodeComponent(item.id)}',
                ),
                icon: const Icon(AppIcons.photoEdit),
                label: const Text('Crop & annotate a copy'),
              ),
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
          ],
        );
      },
    ),
  );
}
