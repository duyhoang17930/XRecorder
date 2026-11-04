import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/domain/models.dart';
import '../../core/constants/design_tokens.dart';
import '../../core/widgets/studio_widgets.dart';
import '../recording/recording_setup_sheet.dart';
import 'media_repository.dart';

class MediaLibraryScreen extends StatefulWidget {
  const MediaLibraryScreen({super.key, required this.kind});
  final MediaKind kind;
  @override
  State<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends State<MediaLibraryScreen>
    with WidgetsBindingObserver {
  CatalogRepository? _repository;
  StreamSubscription<void>? _subscription;
  List<MediaItem> _items = [];
  Uri? _folder;
  Uri? _savedFolder;
  bool _loading = true;
  bool _newest = true;
  String _query = '';
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = MediaScope.of(context);
    if (_repository != repository) {
      _subscription?.cancel();
      _repository = repository;
      _subscription = repository.changes.listen((_) => _load());
      _load();
      repository
          .savedFolder()
          .then((value) {
            if (mounted) setState(() => _savedFolder = value);
          })
          .catchError((Object _) {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repository!.list(kind: widget.kind, folder: _folder);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _items = [];
      });
    }
  }

  Future<void> _pickFolder() async {
    try {
      final folder = await _repository!.selectFolder();
      if (!mounted || folder == null) return;
      setState(() {
        _folder = folder;
        _savedFolder = folder;
      });
      await _load();
    } catch (e) {
      if (mounted) showNotice(context, e.toString());
    }
  }

  Future<void> _storage() async {
    try {
      final values = await _repository!.storage();
      if (!mounted) return;
      await showStudioBottomSheet<void>(
        context: context,
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ListView(
              shrinkWrap: true,
              children: [
                const StudioSheetHeader(
                  title: 'Storage',
                  description: 'App-owned media only. Selected external folders are excluded.',
                  icon: Icons.storage,
                ),
                for (final entry in {
                  'Videos': 'videos',
                  'Photos': 'images',
                  'Cache': 'cache',
                  'Trash': 'trash',
                  'Device free space': 'free',
                }.entries)
                  ListTile(
                    title: Text(entry.key),
                    trailing: Text(formatBytes(values[entry.value] ?? 0)),
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) showNotice(context, e.toString());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.kind == MediaKind.video;
    final items =
        _items
            .where(
              (i) => i.displayName.toLowerCase().contains(_query.toLowerCase()),
            )
            .toList()
          ..sort(
            (a, b) => _newest
                ? b.createdAt.compareTo(a.createdAt)
                : a.createdAt.compareTo(b.createdAt),
          );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: PageStorageKey('library-${widget.kind.name}'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          SectionTitle(
            video ? 'Video Library' : 'Photo Library',
            trailing: IconButton(
              tooltip: 'Storage',
              onPressed: _storage,
              icon: const Icon(Icons.storage_outlined),
            ),
          ),
          StudioSearchField(
            hintText: video ? 'Search videos' : 'Search photos',
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('App media'),
                selected: _folder == null,
                onSelected: (_) {
                  setState(() => _folder = null);
                  _load();
                },
              ),
              if (_savedFolder != null)
                ChoiceChip(
                  label: const Text('Selected folder'),
                  selected: _folder != null,
                  onSelected: (_) {
                    setState(() => _folder = _savedFolder);
                    _load();
                  },
                ),
              ActionChip(
                label: const Text('Choose folder'),
                avatar: const Icon(Icons.folder_open),
                onPressed: _pickFolder,
              ),
              ActionChip(
                label: Text(_newest ? 'Newest first' : 'Oldest first'),
                onPressed: () => setState(() => _newest = !_newest),
              ),
              ActionChip(label: const Text('Refresh'), onPressed: _load),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            StudioCard(
              child: Column(
                children: [
                  Text(_error!),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          else if (items.isEmpty)
            StudioCard(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      video
                          ? Icons.video_library_outlined
                          : Icons.photo_library_outlined,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _query.isEmpty
                          ? (video ? 'No videos yet' : 'No photos yet')
                          : 'No matching media',
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose a folder to browse existing media. Only files directly inside the selected folder are shown.',
                    ),
                  ],
                ),
              ),
            )
          else
            for (var index = 0; index < items.length; index++) ...[
              if (index == 0 ||
                  _day(items[index].createdAt) !=
                      _day(items[index - 1].createdAt))
                StudioSectionLabel(_day(items[index].createdAt)),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: StudioCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: SizedBox(
                      width: 72,
                      height: 54,
                      child: MediaThumbnail(
                        key: ValueKey('${items[index].id}-$_generation'),
                        item: items[index],
                      ),
                    ),
                    title: Text(
                      items[index].displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${formatBytes(items[index].sizeBytes)}${items[index].duration == null ? '' : ' · ${items[index].duration!.inSeconds}s'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(
                      '/media/${Uri.encodeComponent(items[index].id)}',
                    ),
                  ),
                ),
              ),
            ],
          if (video) ...[
            const SizedBox(height: 16),
            PrimaryButton(
              'Record screen',
              icon: Icons.videocam,
              onPressed: () => openRecordingSetup(context),
            ),
          ],
        ],
      ),
    );
  }

  String _day(DateTime value) => value.millisecondsSinceEpoch == 0
      ? 'Date unavailable'
      : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class MediaThumbnail extends StatefulWidget {
  const MediaThumbnail({super.key, required this.item});
  final MediaItem item;
  @override
  State<MediaThumbnail> createState() => _MediaThumbnailState();
}

class _MediaThumbnailState extends State<MediaThumbnail> {
  Future<Uint8List>? _image;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _image ??= MediaScope.of(context).thumbnail(widget.item.uri);
  }

  @override
  void didUpdateWidget(MediaThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.uri != widget.item.uri ||
        oldWidget.item.modifiedAt != widget.item.modifiedAt) {
      _image = MediaScope.of(context).thumbnail(widget.item.uri);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _image,
    builder: (_, snapshot) {
      if (snapshot.hasError) {
        return const Tooltip(
          message: 'Preview unavailable; open details or refresh',
          child: Icon(Icons.broken_image_outlined),
        );
      }
      if (!snapshot.hasData) return const Icon(Icons.image_outlined);
      return Image.memory(
        snapshot.data!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
      );
    },
  );
}
