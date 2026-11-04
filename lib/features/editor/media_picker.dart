import 'package:flutter/material.dart';

import '../../core/domain/models.dart';
import '../media/media_repository.dart';
import '../media/media_library_screen.dart';

Future<MediaItem?> pickEditorMedia(BuildContext context) =>
    showDialog<MediaItem>(
      context: context,
      builder: (_) => const _MediaPicker(),
    );

class _MediaPicker extends StatefulWidget {
  const _MediaPicker();
  @override
  State<_MediaPicker> createState() => _MediaPickerState();
}

class _MediaPickerState extends State<_MediaPicker> {
  Future<List<MediaItem>>? items;
  String? error;
  bool busy = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    items ??= MediaScope.of(context).list(kind: MediaKind.video);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose a video'),
    content: SizedBox(
      width: 560,
      height: 440,
      child: Column(
        children: [
          Wrap(
            children: [
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(
                        () =>
                            items = MediaScope.of(context)
                                .list(kind: MediaKind.video),
                      ),
                child: const Text('App media'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        try {
                          final repository = MediaScope.of(context);
                          final folder = await repository.selectFolder();
                          if (folder != null && mounted) {
                            setState(
                              () => items = repository.list(
                                kind: MediaKind.video,
                                folder: folder,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) setState(() => error = e.toString());
                        }
                      },
                child: const Text('Select folder'),
              ),
            ],
          ),
          if (error != null) Text(error!),
          if (busy) const LinearProgressIndicator(),
          Expanded(
            child: FutureBuilder<List<MediaItem>>(
              future: items,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) return Text(snapshot.error.toString());
                final rows = snapshot.data ?? [];
                if (rows.isEmpty) {
                  return const Center(
                    child: Text(
                      'No videos. Record a video or select a folder.',
                    ),
                  );
                }
                return ListView(
                  children: [
                    for (final item in rows)
                      ListTile(
                        leading: SizedBox(
                          width: 64,
                          height: 48,
                          child: MediaThumbnail(item: item),
                        ),
                        title: Text(item.displayName),
                        subtitle: Text(formatBytes(item.sizeBytes)),
                        onTap: busy
                            ? null
                            : () async {
                                setState(() => busy = true);
                                try {
                                  final loaded = await MediaScope.of(context)
                                      .find(item.id);
                                  if (loaded?.duration == null ||
                                      loaded!.duration! <
                                          const Duration(milliseconds: 200)) {
                                    throw const FormatException(
                                      'This video has no usable duration.',
                                    );
                                  }
                                  if (context.mounted) {
                                    Navigator.pop(context, loaded);
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    setState(() => error = e.toString());
                                  }
                                } finally {
                                  if (mounted) setState(() => busy = false);
                                }
                              },
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}
