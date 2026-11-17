import 'package:xrecorder/l10n/localization.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/domain/models.dart';
import '../../core/presentation/thumbnail_image.dart';
import '../../core/widgets/studio_widgets.dart';
import '../../core/widgets/studio_create_sheet.dart';
import '../../core/widgets/studio_quick_create.dart';
import 'media_repository.dart';
import 'media_sort.dart';
import 'media_actions.dart';
import 'video_entry.dart';

const _mediaSortIcons = <MediaSort, IconData>{
  MediaSort.newest: AppIcons.sortNewest,
  MediaSort.oldest: AppIcons.sortOldest,
  MediaSort.name: AppIcons.sortName,
  MediaSort.size: AppIcons.sortSize,
  MediaSort.duration: AppIcons.sortDuration,
};

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
  int _folderRevision = 0;
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
      unawaited(_restoreSavedFolder(repository));
    }
  }

  Future<void> _restoreSavedFolder(CatalogRepository repository) async {
    final revision = _folderRevision;
    Uri? folder;
    try {
      folder = await repository.savedFolder();
    } catch (_) {
      // App-owned media remains available if a provider cannot restore its
      // saved folder preference. A saved but revoked grant is reported by
      // the normal list operation below.
    }
    if (!mounted || repository != _repository) return;
    if (revision != _folderRevision) {
      await _load();
      return;
    }
    if (_folder != folder) setState(() => _folder = folder);
    await _load();
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
    _folderRevision++;
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
    _folderRevision++;
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StudioSheetHeader(
                title: context.l10n.sortMedia,
                icon: AppIcons.sort,
              ),
              for (final value in MediaSort.values)
                if (value != MediaSort.duration ||
                    widget.kind == MediaKind.video) ...[
                  _MediaSortOption(
                    value: value,
                    selected: value == _sort,
                    onTap: () => Navigator.pop(sheet, value),
                  ),
                  if (value != MediaSort.duration)
                    const SizedBox(height: AppSpacing.xs),
                ],
            ],
          ),
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
                  StudioRootHeader(
                    video
                        ? context.l10n.videoLibrary
                        : context.l10n.photoLibrary,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HeaderAction(
                          tooltip: context.l10n.trash,
                          icon: AppIcons.trash,
                          onPressed: () => context.push('/trash'),
                        ),
                        _HeaderAction(
                          tooltip: context.l10n.storage,
                          icon: AppIcons.storage,
                          onPressed: _storage,
                        ),
                      ],
                    ),
                  ),
                  if (video) ...[
                    const StudioRecordHero(),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const StudioLibraryQuickActions(),
                  const SizedBox(height: AppSpacing.md),
                  StudioSearchField(
                    controller: _search,
                    hintText: video
                        ? context.l10n.searchVideos
                        : context.l10n.searchPhotos,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _FilterTrack(
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
                            avatar: Icon(
                              AppIcons.folderOpen,
                              color: _folder != null
                                  ? c.primaryForeground
                                  : c.muted,
                            ),
                            selected: _folder != null,
                            onSelected: _pickingFolder
                                ? null
                                : (_) => _pickFolder(),
                          ),
                        ],
                      ),
                      _FilterTrack(
                        children: [
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
                      if (_folder != null)
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: c.warning,
                            shape: const StadiumBorder(),
                          ),
                          onPressed: _pickingFolder ? null : _disconnectFolder,
                          child: Text(context.l10n.disconnectFolder),
                        ),
                    ],
                  ),
                  SectionTitle(
                    _query.isNotEmpty
                        ? context.l10n.searchResults
                        : video
                        ? context.l10n.recentVideos
                        : context.l10n.yourPhotos,
                    padding: const EdgeInsets.only(
                      top: AppSpacing.md,
                      bottom: AppSpacing.sm,
                    ),
                    trailing: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.elevated,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xxs,
                        ),
                        child: Text(
                          context.l10n.itemCount(items.length),
                          style: AppTypography.caption.copyWith(color: c.muted),
                        ),
                      ),
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
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: _MediaTile(
                          item: item,
                          duration: item.duration == null
                              ? null
                              : _duration(item.duration!),
                          onTap: () => video
                              ? openVideo(context, item)
                              : details(item),
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

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.studioColors;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: c.card,
        foregroundColor: c.text,
        shape: CircleBorder(side: BorderSide(color: c.border)),
      ),
      icon: Icon(icon, size: AppIconSize.medium),
    );
  }
}

/// Groups related filter chips; the chips themselves carry all styling.
class _FilterTrack extends StatelessWidget {
  const _FilterTrack({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: AppSpacing.xxs, children: children);
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.item,
    required this.duration,
    required this.onTap,
  });
  final MediaItem item;
  final String? duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studioColors;
    final radius = BorderRadius.circular(AppRadius.card - AppBorder.subtle);
    return StudioFadeBorder(
      // Content is inset and thumbnails clip themselves. Bound ink at the
      // source rather than clipping every scroll frame.
      clipBehavior: Clip.none,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Row(
            children: [
              ExcludeSemantics(
                child: ClipRRect(
                  clipBehavior: Clip.hardEdge,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  child: SizedBox(
                    width: AppSize.thumbnailWidth,
                    height: AppSize.thumbnailHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: c.elevated,
                          child: RepaintBoundary(
                            key: ValueKey('library-thumbnail-${item.id}'),
                            child: MediaThumbnail(
                              key: ValueKey(
                                '${item.id}-${item.modifiedAt.millisecondsSinceEpoch}-${item.sizeBytes}-${item.revision}',
                              ),
                              item: item,
                            ),
                          ),
                        ),
                        if (duration != null)
                          Positioned(
                            bottom: AppSpacing.xxs + 2,
                            right: AppSpacing.xxs + 2,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.mediaScrim,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs - 2,
                                ),
                                child: Text(
                                  duration!,
                                  style: AppTypography.micro.copyWith(
                                    color: AppColors.onMedia,
                                    fontWeight: FontWeight.w600,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyEmphasis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.mediaSizeDuration(
                        context.displayValue(context.fileSize(item.sizeBytes)),
                        context.displayValue(
                          duration == null ? '' : ' · $duration',
                        ),
                      ),
                      style: AppTypography.bodySmall.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
              _MediaActionsMenu(item: item, onOpen: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaActionsMenu extends StatelessWidget {
  const _MediaActionsMenu({required this.item, required this.onOpen});
  final MediaItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.studioColors;
    return PopupMenuButton<String>(
      tooltip: context.l10n.mediaActionsFor(
        context.displayValue(item.displayName),
      ),
      onSelected: (_) => onOpen(),
      position: PopupMenuPosition.under,
      offset: const Offset(0, AppSpacing.xxs),
      color: c.surface,
      elevation: AppElevation.dialog,
      shadowColor: Colors.black.withValues(alpha: .18),
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
      menuPadding: const EdgeInsets.all(AppSpacing.xxs + 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.menu + 2),
        side: BorderSide(color: c.border),
      ),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          height: 0,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          child: Text(
            item.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(color: c.muted),
          ),
        ),
        const PopupMenuDivider(height: AppSpacing.xxs),
        PopupMenuItem<String>(
          value: 'details',
          padding: EdgeInsets.zero,
          child: Container(
            margin: const EdgeInsets.only(top: AppSpacing.xxs),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Row(
              children: [
                StudioIconTile(
                  icon: AppIcons.info,
                  size: 32,
                  iconSize: AppIconSize.small,
                  radius: AppRadius.pill,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    context.l10n.openDetails,
                    style: AppTypography.bodyEmphasis.copyWith(color: c.text),
                  ),
                ),
                Icon(
                  AppIcons.chevronRight,
                  size: AppIconSize.small,
                  color: c.muted,
                ),
              ],
            ),
          ),
        ),
      ],
      style: IconButton.styleFrom(foregroundColor: c.muted),
      icon: const Icon(AppIcons.more),
    );
  }
}

class _MediaSortOption extends StatelessWidget {
  const _MediaSortOption({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final MediaSort value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.studioColors;
    final accent = colors.primary;
    final background = selected
        ? accent.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark ? .16 : .08,
          )
        : colors.card;

    return Semantics(
      key: ValueKey('media-sort-${value.name}'),
      button: true,
      selected: selected,
      label: context.message(value.label),
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
            side: BorderSide(
              color: selected ? accent : colors.border,
              width: selected ? 1.5 : AppBorder.subtle,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  StudioIconTile(
                    icon: _mediaSortIcons[value]!,
                    size: AppSize.touchTarget,
                    iconSize: AppIconSize.medium,
                    color: selected ? accent : colors.muted,
                    backgroundColor: selected
                        ? accent.withValues(alpha: .13)
                        : colors.elevated,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      context.message(value.label),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyEmphasis.copyWith(
                        color: selected ? accent : colors.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  SizedBox(
                    width: 36,
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: selected
                          ? Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.icon,
                                ),
                              ),
                              child: Icon(
                                AppIcons.check,
                                color: colors.primaryForeground,
                                size: AppIconSize.small,
                              ),
                            )
                          : const SizedBox.square(dimension: 32),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
