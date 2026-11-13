import 'package:xrecorder/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/domain/models.dart';
import '../../core/widgets/studio_widgets.dart';
import '../../core/ui/components/dialogs/studio_name_dialog.dart';
import 'media_repository.dart';
import 'media_library_screen.dart';
import 'media_actions.dart';
import '../editor/editor_entry.dart';
import '../editor/project_repository.dart';

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
  String? editingProjectId;

  Future<void> editVideo(MediaItem item) async {
    final repository = AndroidEditProjectRepository();
    final previous = editingProjectId;
    final existing = previous == null ? null : await repository.find(previous);
    if (!mounted) return;
    final project =
        existing ??
        await createEditorProject(
          media: [item],
          title: item.displayName,
          repository: repository,
        );
    editingProjectId = project.id;
    if (mounted) await context.push('/editor/project/${project.id}');
  }

  void closeDetails(MediaItem item) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(item.kind == MediaKind.video ? '/videos' : '/photos');
    }
  }

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
    final name = await showStudioDialog<String>(
      context: context,
      builder: (dialog) => StudioNameDialog(
        initial: item.displayName,
        title: dialog.l10n.renameMedia,
        label: dialog.l10n.filename,
        maxLength: 120,
        submitLabel: dialog.l10n.rename,
        onSubmit: (value) => Navigator.pop(dialog, value),
      ),
    );
    if (name == null || !mounted) return;
    final id = await actions.rename(item.uri, name);
    if (!mounted) return;
    MediaScope.of(context).refresh();
    if (id != widget.id) {
      context.pushReplacement('/media/${Uri.encodeComponent(id)}');
    } else {
      reloadItem();
    }
  }

  Future<void> trash(MediaItem item) async {
    final confirm = await showStudioDialog<bool>(
      context: context,
      builder: (context) => StudioDialog(
        title: Text(context.l10n.moveToTrash756188),
        content: Text(
          context.l10n.moveMediaToTrashName(
            context.displayValue(item.displayName),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.moveToTrash),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await actions.trash(item);
    if (mounted) {
      MediaScope.of(context).refresh();
      closeDetails(item);
    }
  }

  Future<void> transfer(MediaItem item, bool move) async {
    if (move) {
      final confirmed = await showStudioDialog<bool>(
        context: context,
        builder: (dialog) => StudioDialog(
          title: Text(dialog.l10n.moveToAnotherFolder),
          content: Text(dialog.l10n.theCopyWillBeVerifiedFirstThe),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(dialog.l10n.chooseDestination),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final result = await actions.transfer(item.uri, move: move);
    if (result == null || !mounted) return;
    MediaScope.of(context).refresh();
    final message =
        result['warning'] as String? ??
        (result['moved'] == true
            ? 'Move verified and completed.'
            : 'Copy verified and saved.');
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.message(message))));
    if (result['moved'] == true) closeDetails(item);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _item ??= MediaScope.of(context).find(widget.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.mediaDetails)),
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
                    context.message(
                      snapshot.hasError
                          ? UserMessages.failure(
                              snapshot.error,
                              operation: UserOperation.openMedia,
                            ).text
                          : context.l10n.mediaUnavailable,
                    ),
                  ),
                  TextButton(
                    onPressed: reloadItem,
                    child: Text(context.l10n.retry),
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
            SizedBox(
              height: (MediaQuery.sizeOf(context).height * .25).clamp(
                120.0,
                220.0,
              ),
              child: MediaThumbnail(item: item),
            ),
            SectionTitle(item.displayName),
            if (busy && (ModalRoute.of(context)?.isCurrent ?? true))
              const LinearProgressIndicator(),
            SectionTitle(context.l10n.preview),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
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
                  label: Text(context.l10n.preview),
                ),
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          await actions.share(item.uri);
                        }, purpose: UserOperation.share),
                  icon: const Icon(AppIcons.share),
                  label: Text(context.l10n.share),
                ),
                if (item.kind == MediaKind.video &&
                    item.duration != null &&
                    item.duration! >= const Duration(milliseconds: 200))
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => run(() => editVideo(item)),
                    icon: const Icon(AppIcons.edit),
                    label: Text(context.l10n.editVideo),
                  ),
              ],
            ),
            if (item.kind == MediaKind.image) ...[
              SectionTitle(context.l10n.edit),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => context.push(
                        '/photo-tools/${Uri.encodeComponent(item.id)}',
                      ),
                icon: const Icon(AppIcons.photoEdit),
                label: Text(context.l10n.cropAnnotateACopy),
              ),
            ],
            if (item.kind != MediaKind.image &&
                (item.kind != MediaKind.video ||
                    item.duration == null ||
                    item.duration! < const Duration(milliseconds: 200)))
              Text(context.l10n.chooseAPlayableVideoOfAtLeast),
            SectionTitle(context.l10n.fileManagement),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item.owned)
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () => run(
                            () => rename(item),
                            purpose: UserOperation.rename,
                          ),
                    icon: const Icon(AppIcons.rename),
                    label: Text(context.l10n.rename),
                  ),
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => run(() => transfer(item, false)),
                  icon: const Icon(AppIcons.folder),
                  label: Text(context.l10n.copyToFolder),
                ),
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => run(() => transfer(item, true)),
                  icon: const Icon(AppIcons.folderOpen),
                  label: Text(context.l10n.moveToFolder),
                ),
              ],
            ),
            if (!item.owned)
              Text(context.l10n.externalFilesCanBeCopiedMovingRequires),
            if (item.owned) ...[
              const Divider(height: 32),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: context.studioColors.warning,
                  ),
                  onPressed: busy
                      ? null
                      : () => run(
                          () => trash(item),
                          purpose: UserOperation.trash,
                        ),
                  icon: const Icon(AppIcons.trash),
                  label: Text(context.l10n.moveToTrash),
                ),
              ),
            ],
            ListTile(
              title: Text(context.l10n.size),
              subtitle: Text(context.fileSize(item.sizeBytes)),
            ),
            ListTile(
              title: Text(context.l10n.format),
              subtitle: Text(item.mimeType),
            ),
            if (item.duration != null)
              ListTile(
                title: Text(context.l10n.duration),
                subtitle: Text(
                  context.l10n.secondsValue(
                    context.displayValue(item.duration!.inSeconds),
                  ),
                ),
              ),
            if (item.width != null)
              ListTile(
                title: Text(context.l10n.dimensions),
                subtitle: Text(
                  context.l10n.dimensionsValue(
                    context.displayValue(item.width),
                    context.displayValue(item.height),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
