import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/domain/models.dart';
import '../../core/widgets/studio_widgets.dart';
import '../../core/widgets/studio_create_sheet.dart';
import 'media_repository.dart';

class MediaLibraryScreen extends StatefulWidget {
  const MediaLibraryScreen({super.key, required this.kind});
  final MediaKind kind;
  @override
  State<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends State<MediaLibraryScreen> {
  CatalogRepository? _repository;
  StreamSubscription<void>? _subscription;
  List<MediaItem> _items = [];
  Uri? _folder;
  Uri? _displayedFolder;
  bool _hasResult = false;
  bool _loading = true;
  bool _newest = true;
  String _query = '';
  String? _error;
  Future<void>? _inFlight;
  bool _loadAgain = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = MediaScope.of(context);
    if (_repository != repository) {
      _subscription?.cancel();
      _repository = repository;
      _subscription = repository.changes.listen((_) => _load());
      _load();
    }
  }

  Future<void> _load() {
    if (!mounted) return Future.value();
    if (_inFlight != null) {
      _loadAgain = true;
      return _inFlight!;
    }
    final result = _drainLoads();
    _inFlight = result;
    return result;
  }

  Future<void> _drainLoads() async {
    try {
      do {
        _loadAgain = false;
        await _fetch();
      } while (mounted && _loadAgain);
    } finally {
      _inFlight = null;
    }
  }

  Future<void> _fetch() async {
    final folder = _folder;
    final repository = _repository!;
    final showLoading =
        !_hasResult || _displayedFolder != folder || _error != null;
    if (_loading != showLoading || _error != null) {
      setState(() {
        _loading = showLoading;
        _error = null;
      });
    }
    try {
      final items = await repository.list(kind: widget.kind, folder: folder);
      if (!mounted || folder != _folder || repository != _repository) return;
      final changed = !_sameItems(_items, items);
      if (changed || _loading || !_hasResult) {
        setState(() {
          if (changed) _items = List.unmodifiable(items);
          _loading = false;
          _hasResult = true;
          _displayedFolder = folder;
        });
      }
    } catch (e) {
      if (!mounted || folder != _folder || repository != _repository) return;
      setState(() {
        _error = UserMessages.failure(
          e,
          operation: UserOperation.loadLibrary,
        ).text;
        _loading = false;
        _items = [];
      });
    }
  }

  bool _sameItems(List<MediaItem> a, List<MediaItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((
            a[i].id,
            a[i].uri,
            a[i].displayName,
            a[i].modifiedAt,
            a[i].createdAt,
            a[i].sizeBytes,
            a[i].duration,
            a[i].status,
            a[i].width,
            a[i].height,
            a[i].revision,
          ) !=
          (
            b[i].id,
            b[i].uri,
            b[i].displayName,
            b[i].modifiedAt,
            b[i].createdAt,
            b[i].sizeBytes,
            b[i].duration,
            b[i].status,
            b[i].width,
            b[i].height,
            b[i].revision,
          )) {
        return false;
      }
    }
    return true;
  }

  Future<void> _pickFolder() async {
    try {
      final folder = await _repository!.selectFolder();
      if (!mounted || folder == null) return;
      setState(() {
        _folder = folder;
      });
      await _load();
    } catch (e) {
      if (mounted) {
        showFailure(context, e, operation: UserOperation.chooseFolder);
      }
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
                  icon: AppIcons.storage,
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
      if (mounted) showFailure(context, e, operation: UserOperation.storage);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.kind == MediaKind.video;
    final c = context.studioColors;
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
    void details(MediaItem item) =>
        context.push('/media/${Uri.encodeComponent(item.id)}');
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        primary: true,
        key: PageStorageKey('library-${widget.kind.name}'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '3HRECORDER',
                    style: AppTypography.section.copyWith(color: c.primary),
                  ),
                  SectionTitle(
                    video ? 'Video Library' : 'Photo Library',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Trash',
                          onPressed: () => context.push('/trash'),
                          icon: const Icon(AppIcons.trash),
                        ),
                        IconButton(
                          tooltip: 'Storage',
                          onPressed: _storage,
                          icon: const Icon(AppIcons.storage),
                        ),
                      ],
                    ),
                  ),
                  if (video) ...[
                    const StudioRecordHero(),
                    const SizedBox(height: AppSpacing.sm),
                    const StudioQuickTools(compact: true),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  StudioSearchField(
                    hintText: video ? 'Search videos' : 'Search photos',
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xxs,
                    runSpacing: AppSpacing.xxs,
                    children: [
                      ChoiceChip(
                        label: const Text('App media'),
                        selected: _folder == null,
                        onSelected: (_) {
                          if (_folder == null) return;
                          setState(() => _folder = null);
                          _load();
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Choose folder'),
                        avatar: const Icon(AppIcons.folderOpen),
                        selected: _folder != null,
                        onSelected: (_) => _pickFolder(),
                      ),
                      ActionChip(
                        label: Text(_newest ? 'Newest' : 'Oldest'),
                        avatar: const Icon(AppIcons.sort),
                        onPressed: () => setState(() => _newest = !_newest),
                      ),
                    ],
                  ),
                  SectionTitle(
                    _query.isNotEmpty
                        ? 'Search results'
                        : video
                        ? 'Recent videos'
                        : 'Your photos',
                    trailing: Text(
                      '${items.length} items',
                      style: TextStyle(color: c.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverToBoxAdapter(
              child: StudioLoadingState(label: 'Loading your media…'),
            )
          else if (_error != null)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: StudioEmptyState(
                  title: 'Library unavailable',
                  description: _error,
                  icon: AppIcons.folderUnavailable,
                  action: OutlinedButton(
                    onPressed: _load,
                    child: const Text('Retry'),
                  ),
                ),
              ),
            )
          else if (items.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: StudioEmptyState(
                  title: _query.isEmpty
                      ? (video ? 'No videos yet' : 'No photos yet')
                      : 'No matching media',
                  description: _query.isEmpty
                      ? 'Choose a folder to browse existing media. Only files directly inside the selected folder are shown.'
                      : 'Try a different name or browse another folder.',
                  icon: video ? AppIcons.videos : AppIcons.photos,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverList.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (index == 0 ||
                          _day(item.createdAt) !=
                              _day(items[index - 1].createdAt))
                        StudioSectionLabel(
                          _day(item.createdAt),
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: StudioCard(
                          padding: EdgeInsets.zero,
                          child: InkWell(
                            onTap: () => details(item),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Row(
                                children: [
                                  ExcludeSemantics(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.icon,
                                      ),
                                      child: SizedBox(
                                        width: AppSize.thumbnailWidth,
                                        height: AppSize.thumbnailHeight,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            ColoredBox(
                                              color: c.elevated,
                                              child: MediaThumbnail(
                                                key: ValueKey(
                                                  '${item.id}-${item.modifiedAt.millisecondsSinceEpoch}-${item.sizeBytes}-${item.revision}',
                                                ),
                                                item: item,
                                              ),
                                            ),
                                            if (item.duration != null)
                                              Positioned(
                                                bottom: AppSpacing.xxs,
                                                right: AppSpacing.xxs,
                                                child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    color: AppColors.mediaScrim,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          AppRadius.icon / 2,
                                                        ),
                                                  ),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal:
                                                              AppSpacing.xxs,
                                                        ),
                                                    child: Text(
                                                      _duration(item.duration!),
                                                      style: AppTypography.micro
                                                          .copyWith(
                                                            color: AppColors
                                                                .onMedia,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.displayName,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.bodyEmphasis,
                                        ),
                                        const SizedBox(height: AppSpacing.xxs),
                                        Text(
                                          '${formatBytes(item.sizeBytes)}${item.duration == null ? '' : ' · ${_duration(item.duration!)}'}',
                                          style: AppTypography.bodySmall
                                              .copyWith(color: c.muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Actions for ${item.displayName}',
                                    onSelected: (_) => details(item),
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'details',
                                        child: Text('Open details'),
                                      ),
                                    ],
                                    icon: const Icon(AppIcons.more),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        ],
      ),
    );
  }

  String _duration(Duration value) {
    final seconds = value.inSeconds;
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
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
          child: Icon(AppIcons.imageUnavailable),
        );
      }
      if (!snapshot.hasData) return const Icon(AppIcons.image);
      return Image.memory(
        snapshot.data!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(AppIcons.imageUnavailable),
      );
    },
  );
}
