import 'package:xrecorder/l10n/localization.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/domain/models.dart';
import '../../core/widgets/studio_widgets.dart';
import '../media/media_repository.dart';
import '../media/media_library_screen.dart';

Future<MediaItem?> pickEditorMedia(BuildContext context) =>
    showStudioDialog<MediaItem>(
      context: context,
      builder: (_) => const _MediaPicker(),
    );

Future<List<MediaItem>?> pickEditorMediaBatch(BuildContext context) =>
    showStudioDialog<List<MediaItem>>(
      context: context,
      builder: (_) => const _MediaPicker(multiple: true),
    );

Future<MediaItem?> pickEditorPhoto(BuildContext context) =>
    showStudioDialog<MediaItem>(
      context: context,
      builder: (_) => const _MediaPicker(photoOnly: true),
    );

class _MediaPicker extends StatefulWidget {
  const _MediaPicker({this.multiple = false, this.photoOnly = false});
  final bool multiple, photoOnly;
  @override
  State<_MediaPicker> createState() => _MediaPickerState();
}

class _MediaPickerState extends State<_MediaPicker> {
  Future<List<MediaItem>>? items;
  String? error;
  bool busy = false;
  Uri? selectedFolder;
  MediaKind kind = MediaKind.video;
  final selected = <String, MediaItem>{};
  void completeSelection() {
    if (busy || selected.isEmpty) return;
    setState(() => busy = true);
    Navigator.pop(context, selected.values.toList());
  }

  void loadMedia({Uri? folder}) {
    if (!mounted) return;
    final next = MediaScope.of(context).list(kind: kind, folder: folder);
    setState(() {
      items = next;
      selectedFolder = folder;
      error = null;
    });
  }

  Future<void> chooseFolder() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final folder = await MediaScope.of(context).selectFolder();
      if (mounted && folder != null) loadMedia(folder: folder);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = UserMessages.failure(
            e,
            operation: UserOperation.chooseFolder,
          ).text,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> choose(MediaItem item) async {
    if (busy) return;
    if (widget.multiple && selected.containsKey(item.id)) {
      setState(() => selected.remove(item.id));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final loaded = await MediaScope.of(context).find(item.id);
      if (loaded == null ||
          (loaded.kind == MediaKind.video &&
              (loaded.duration == null ||
                  loaded.duration! < const Duration(milliseconds: 200))) ||
          (loaded.kind != MediaKind.video && loaded.kind != MediaKind.image) ||
          (widget.photoOnly && loaded.kind != MediaKind.image)) {
        throw const FormatException(
          'Choose a playable video or a still photo.',
        );
      }
      if (!mounted) return;
      if (widget.multiple) {
        if (selected.length >= 30) {
          throw const FormatException('Maximum 30 clips.');
        }
        setState(() => selected[loaded.id] = loaded);
      } else {
        Navigator.pop(context, loaded);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = UserMessages.failure(
            e,
            operation: UserOperation.openMedia,
          ).text,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (items == null) {
      kind = widget.photoOnly ? MediaKind.image : MediaKind.video;
      items = MediaScope.of(context).list(kind: kind);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(24),
    child: SizedBox(
      width: 560,
      height: math.max(
        0,
        math.min(
          560,
          MediaQuery.sizeOf(context).height -
              MediaQuery.viewInsetsOf(context).bottom -
              48,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          children: [
            StudioSheetHeader(title: context.l10n.chooseMedia),
            if (busy)
              const LinearProgressIndicator(
                minHeight: 4,
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            Expanded(
              child: FutureBuilder<List<MediaItem>>(
                future: items,
                builder: (context, snapshot) {
                  final rows = snapshot.data ?? [];
                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: AppSpacing.xs,
                          children: [
                            // Media type and source are separate choices;
                            // keep them on their own rows so two selected
                            // pills never read as one group.
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              children: [
                                for (final type
                                    in widget.photoOnly
                                        ? [MediaKind.image]
                                        : [MediaKind.video, MediaKind.image])
                                  ChoiceChip(
                                    label: Text(
                                      type == MediaKind.video
                                          ? context.l10n.videos
                                          : context.l10n.photos,
                                    ),
                                    selected: kind == type,
                                    onSelected: busy
                                        ? null
                                        : (_) {
                                            kind = type;
                                            loadMedia(folder: selectedFolder);
                                          },
                                  ),
                              ],
                            ),
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              children: [
                                _SourceChip(
                                  icon: AppIcons.storage,
                                  label: context.l10n.appMedia,
                                  selected: selectedFolder == null,
                                  onTap: busy ? null : () => loadMedia(),
                                ),
                                _SourceChip(
                                  icon: AppIcons.folder,
                                  label: context.l10n.chooseFolder,
                                  selected: selectedFolder != null,
                                  onTap: busy ? null : chooseFolder,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                          ],
                        ),
                      ),
                      if (error != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xs,
                            ),
                            child: Text(
                              context.message(error!),
                              style: TextStyle(
                                color: context.studioColors.warning,
                              ),
                            ),
                          ),
                        ),
                      if (snapshot.connectionState != ConnectionState.done)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: StudioLoadingState(
                            label: context.l10n.loadingVideos,
                          ),
                        )
                      else if (snapshot.hasError)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                context.message(
                                  UserMessages.failure(
                                    snapshot.error,
                                    operation: UserOperation.loadLibrary,
                                  ).text,
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    loadMedia(folder: selectedFolder),
                                child: Text(context.l10n.retry),
                              ),
                            ],
                          ),
                        )
                      else if (rows.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              context.l10n.noMediaHereChooseAnotherSourceOr,
                            ),
                          ),
                        )
                      else
                        SliverList.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, index) {
                            final item = rows[index];
                            return ListTile(
                              selected: selected.containsKey(item.id),
                              selectedTileColor: context.studioColors.primary
                                  .withValues(alpha: .10),
                              contentPadding: const EdgeInsetsDirectional.only(
                                start: AppSpacing.xs,
                                end: AppSpacing.xxs,
                              ),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.control,
                                ),
                                child: SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: MediaThumbnail(item: item),
                                ),
                              ),
                              title: Text(
                                item.displayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(context.fileSize(item.sizeBytes)),
                              trailing: widget.multiple
                                  ? Icon(
                                      selected.containsKey(item.id)
                                          ? AppIcons.selected
                                          : AppIcons.unselected,
                                    )
                                  : null,
                              onTap: busy ? null : () => choose(item),
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: AppSpacing.xs,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.cancel),
                ),
                if (widget.multiple)
                  Expanded(
                    child: FilledButton(
                      onPressed: busy || selected.isEmpty
                          ? null
                          : completeSelection,
                      child: Text(
                        '${context.l10n.addClip} · ${context.l10n.clipCount(selected.length)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.studioColors;
    // Outlined so the source choice reads differently from the filled
    // media-type pills above it.
    return Semantics(
      selected: selected,
      button: true,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          foregroundColor: selected ? c.primary : c.text,
          backgroundColor: selected ? c.primary.withValues(alpha: .10) : null,
          side: BorderSide(color: selected ? c.primary : c.border),
        ),
        icon: Icon(icon, size: AppIconSize.small),
        label: Text(label),
      ),
    );
  }
}
