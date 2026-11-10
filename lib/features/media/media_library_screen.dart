import 'package:xrecorder/l10n/localization.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/domain/models.dart';
import '../../core/presentation/thumbnail_image.dart';
import '../../core/widgets/studio_widgets.dart';
import '../../core/widgets/studio_create_sheet.dart';
import 'media_repository.dart';
import 'media_sort.dart';
import 'media_actions.dart';

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
  MediaSort _sort = MediaSort.newest;
  bool _pickingFolder = false;
  String _query = '';
  final _search = TextEditingController();
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
    if (_pickingFolder) return;
    setState(() => _pickingFolder = true);
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
    } finally {
      if (mounted) setState(() => _pickingFolder = false);
    }
  }

  Future<void> _disconnectFolder() async {
    if (_pickingFolder || _folder == null) return;
    final folder = _folder!;
    setState(() => _pickingFolder = true);
    try {
      final confirmed = await showStudioDialog<bool>(
        context: context,
        builder: (dialog) => StudioDialog(
          title: Text(context.l10n.disconnectThisFolder),
          content: Text(context.l10n.filesStayInTheFolderDraftsUsing),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(context.l10n.disconnect),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await AndroidMediaActions().call<void>(
        'releaseFolder',
        folder.toString(),
      );
      if (!mounted) return;
      setState(() => _folder = null);
      await _load();
    } catch (e) {
      if (mounted) {
        showFailure(context, e, operation: UserOperation.chooseFolder);
      }
    } finally {
      if (mounted) setState(() => _pickingFolder = false);
    }
  }

  Future<void> _chooseSort() async {
    final result = await showStudioBottomSheet<MediaSort>(
      context: context,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            StudioSheetHeader(title: context.l10n.sortMedia),
            for (final value in MediaSort.values)
              if (value != MediaSort.duration || widget.kind == MediaKind.video)
                ListTile(
                  title: Text(context.message(value.label)),
                  selected: value == _sort,
                  leading: Icon(
                    value == _sort ? AppIcons.selected : AppIcons.unselected,
                  ),
                  onTap: () => Navigator.pop(sheet, value),
                ),
          ],
        ),
      ),
    );
    if (mounted && result != null) setState(() => _sort = result);
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
                StudioSheetHeader(
                  title: context.l10n.storage,
                  description:
                      context.l10n.appOwnedMediaOnlySelectedExternalFolders,
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
                    title: Text(context.message(entry.key)),
                    trailing: Text(context.fileSize(values[entry.value] ?? 0)),
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
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.kind == MediaKind.video;
    final c = context.studioColors;
    final query = _query.trim().toLowerCase();
    final items =
        _items
            .where((i) => i.displayName.toLowerCase().contains(query))
            .toList()
          ..sort(_sort.compare);
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
                    video
                        ? context.l10n.videoLibrary
                        : context.l10n.photoLibrary,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: context.l10n.trash,
                          onPressed: () => context.push('/trash'),
                          icon: const Icon(AppIcons.trash),
                        ),
                        IconButton(
                          tooltip: context.l10n.storage,
                          onPressed: _storage,
                          icon: const Icon(AppIcons.storage),
                        ),
                      ],
                    ),
                  ),
                  if (video) ...[
                    const StudioRecordHero(),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const StudioQuickTools(compact: true),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    context.l10n.screenshotMinimizesTheAppAfterApproval3s,
                    style: AppTypography.caption.copyWith(color: c.muted),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...[
                    StudioSearchField(
                      controller: _search,
                      hintText: video
                          ? context.l10n.searchVideos
                          : context.l10n.searchPhotos,
                      onChanged: (value) => setState(() => _query = value),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Wrap(
                    spacing: AppSpacing.xxs,
                    runSpacing: AppSpacing.xxs,
                    children: [
                      ChoiceChip(
                        label: Text(context.l10n.appMedia),
                        selected: _folder == null,
                        onSelected: (_) {
                          if (_folder == null) return;
                          setState(() => _folder = null);
                          _load();
                        },
                      ),
                      ChoiceChip(
                        label: Text(context.l10n.chooseFolder),
                        avatar: const Icon(AppIcons.folderOpen),
                        selected: _folder != null,
                        onSelected: _pickingFolder
                            ? null
                            : (_) => _pickFolder(),
                      ),
                      if (_folder != null)
                        TextButton(
                          onPressed: _pickingFolder ? null : _disconnectFolder,
                          child: Text(context.l10n.disconnectFolder),
                        ),
                      Tooltip(
                        message: context.l10n.sortMedia,
                        child: ActionChip(
                          label: Text(context.message(_sort.label)),
                          avatar: const Icon(AppIcons.sort),
                          onPressed: _chooseSort,
                        ),
                      ),
                    ],
                  ),
                  SectionTitle(
                    _query.isNotEmpty
                        ? context.l10n.searchResults
                        : video
                        ? context.l10n.recentVideos
                        : context.l10n.yourPhotos,
                    trailing: Text(
                      context.l10n.itemCount(items.length),
                      style: TextStyle(color: c.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            SliverToBoxAdapter(
              child: StudioLoadingState(label: context.l10n.loadingYourMedia),
            )
          else if (_error != null)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              sliver: SliverToBoxAdapter(
                child: StudioEmptyState(
                  title: context.l10n.libraryUnavailable,
                  description: context.message(_error!),
                  icon: AppIcons.folderUnavailable,
                  action: OutlinedButton(
                    onPressed: _load,
                    child: Text(context.l10n.retry),
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
                      ? (_folder != null
                            ? (video
                                  ? context.l10n.noVideosInThisFolder
                                  : context.l10n.noPhotosInThisFolder)
                            : (video
                                  ? context.l10n.noRecordingsYet
                                  : context.l10n.noScreenshotsYet))
                      : context.l10n.noMatchingMedia,
                  description: _query.isEmpty
                      ? (_folder != null
                            ? context.l10n.onlyFilesInThisFolderAreShown
                            : video
                            ? context.l10n.yourVideosWillAppearHere
                            : context
                                  .l10n
                                  .yourScreenshotsAndEditedPhotosWillAppear)
                      : context.l10n.tryADifferentNameOrBrowseAnother,
                  icon: video ? AppIcons.videos : AppIcons.photos,
                  action: _query.isNotEmpty
                      ? TextButton(
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                          child: Text(context.l10n.clearSearch),
                        )
                      : _folder != null
                      ? TextButton(
                          onPressed: () {
                            setState(() => _folder = null);
                            _load();
                          },
                          child: Text(context.l10n.showAppMedia),
                        )
                      : null,
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
                      if (_sort.groupsByDate &&
                          (index == 0 ||
                              _day(item.createdAt) !=
                                  _day(items[index - 1].createdAt)))
                        StudioSectionLabel(
                          _day(item.createdAt),
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: StudioCard(
                          padding: EdgeInsets.zero,
                          // Content is inset and thumbnails clip themselves. Bound
                          // ink at the source rather than clipping every scroll frame.
                          clipBehavior: Clip.none,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            onTap: () => details(item),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Row(
                                children: [
                                  ExcludeSemantics(
                                    child: ClipRRect(
                                      clipBehavior: Clip.hardEdge,
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
                                              child: RepaintBoundary(
                                                key: ValueKey(
                                                  'library-thumbnail-${item.id}',
                                                ),
                                                child: MediaThumbnail(
                                                  key: ValueKey(
                                                    '${item.id}-${item.modifiedAt.millisecondsSinceEpoch}-${item.sizeBytes}-${item.revision}',
                                                  ),
                                                  item: item,
                                                ),
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
                                          context.l10n.mediaSizeDuration(
                                            context.displayValue(
                                              context.fileSize(item.sizeBytes),
                                            ),
                                            context.displayValue(
                                              item.duration == null
                                                  ? ''
                                                  : ' · ${_duration(item.duration!)}',
                                            ),
                                          ),
                                          style: AppTypography.bodySmall
                                              .copyWith(color: c.muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: context.l10n.mediaActionsFor(
                                      context.displayValue(item.displayName),
                                    ),
                                    onSelected: (_) => details(item),
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        value: 'details',
                                        child: Text(context.l10n.openDetails),
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
          SliverToBoxAdapter(
            child: SizedBox(
              height: AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
            ),
          ),
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
      ? context.l10n.dateUnavailable
      : context.calendarDate(value);
}

class MediaThumbnail extends StatefulWidget {
  const MediaThumbnail({super.key, required this.item});
  final MediaItem item;
  @override
  State<MediaThumbnail> createState() => _MediaThumbnailState();
}

class _MediaThumbnailState extends State<MediaThumbnail> {
  Future<ThumbnailImage>? _image;
  CatalogRepository? _repository;
  Future<ThumbnailImage> _loadImage() =>
      MediaScope.thumbnail(context, widget.item).then(ThumbnailImage.new);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = MediaScope.of(context);
    if (_repository != repository || _image == null) {
      _repository = repository;
      _image = _loadImage();
    }
  }

  @override
  void didUpdateWidget(MediaThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (MediaScope.thumbnailKey(oldWidget.item) !=
        MediaScope.thumbnailKey(widget.item)) {
      _image = _loadImage();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ThumbnailImage>(
    future: _image,
    builder: (_, snapshot) {
      if (snapshot.hasError) {
        return Tooltip(
          message: context.l10n.previewUnavailableOpenDetailsOrRefresh,
          child: Icon(AppIcons.imageUnavailable),
        );
      }
      if (!snapshot.hasData) return const Icon(AppIcons.image);
      return LayoutBuilder(
        builder: (context, constraints) {
          final ratio = MediaQuery.devicePixelRatioOf(context);
          final compact = constraints.maxWidth <= AppSize.thumbnailWidth;
          final scale = compact && ratio > 2 ? 2.0 : ratio;
          final width = constraints.maxWidth.isFinite
              ? (constraints.maxWidth * scale).ceil().clamp(1, 320)
              : 320;
          return Image(
            image: ResizeImage.resizeIfNeeded(width, null, snapshot.data!),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const Icon(AppIcons.imageUnavailable),
          );
        },
      );
    },
  );
}
