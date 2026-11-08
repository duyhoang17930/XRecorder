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

class _MediaPicker extends StatefulWidget {
  const _MediaPicker();
  @override
  State<_MediaPicker> createState() => _MediaPickerState();
}

class _MediaPickerState extends State<_MediaPicker> {
  Future<List<MediaItem>>? items;
  String? error;
  bool busy = false;
  Uri? selectedFolder;
  MediaKind kind = MediaKind.video;
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
          (loaded.kind != MediaKind.video && loaded.kind != MediaKind.image)) {
        throw const FormatException(
          'Choose a playable video or a still photo.',
        );
      }
      if (mounted) Navigator.pop(context, loaded);
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
    items ??= MediaScope.of(context).list(kind: MediaKind.video);
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            StudioSheetHeader(title: context.l10n.chooseMedia),
            if (busy) const LinearProgressIndicator(),
            Expanded(
              child: FutureBuilder<List<MediaItem>>(
                future: items,
                builder: (context, snapshot) {
                  final rows = snapshot.data ?? [];
                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Wrap(
                          spacing: 8,
                          children: [
                            for (final type in [
                              MediaKind.video,
                              MediaKind.image,
                            ])
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
                            ChoiceChip(
                              label: Text(context.l10n.appMedia),
                              selected: selectedFolder == null,
                              onSelected: busy ? null : (_) => loadMedia(),
                            ),
                            ChoiceChip(
                              label: Text(context.l10n.chooseFolder),
                              selected: selectedFolder != null,
                              onSelected: busy ? null : (_) => chooseFolder(),
                            ),
                          ],
                        ),
                      ),
                      if (error != null)
                        SliverToBoxAdapter(
                          child: Text(context.message(error!)),
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
                              leading: SizedBox(
                                width: 48,
                                height: 48,
                                child: MediaThumbnail(item: item),
                              ),
                              title: Text(item.displayName),
                              subtitle: Text(context.fileSize(item.sizeBytes)),
                              onTap: busy ? null : () => choose(item),
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.cancel),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
