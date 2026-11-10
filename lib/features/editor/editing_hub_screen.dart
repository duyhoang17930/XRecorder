import 'package:xrecorder/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import '../../core/domain/models.dart';
import '../../core/widgets/studio_widgets.dart';
import 'project_repository.dart';

class EditingHubScreen extends StatefulWidget {
  const EditingHubScreen({super.key});
  @override
  State<EditingHubScreen> createState() => _EditingHubScreenState();
}

class _EditingHubScreenState extends State<EditingHubScreen> {
  final repository = AndroidEditProjectRepository();
  late Future<List<EditProject>> projects = repository.list();
  bool creating = false, opening = false;
  bool pinning = false;
  Future<void> pin(String kind) async {
    if (pinning) return;
    setState(() => pinning = true);
    try {
      final supported = await const MethodChannel('com.xrecorder/media')
          .invokeMethod<bool>('pinShortcut', kind);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              supported == true
                  ? context.l10n.confirmTheShortcutWithYourLauncher
                  : context.l10n.thisLauncherDoesNotSupportPinnedShortcuts,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) showFailure(context, e, operation: UserOperation.openMedia);
    } finally {
      if (mounted) setState(() => pinning = false);
    }
  }

  void reloadProjects() {
    if (!mounted) return;
    final next = repository.list();
    setState(() {
      projects = next;
    });
  }

  Future<void> open(String id) async {
    if (opening) return;
    opening = true;
    try {
      await context.push('/editor/project/$id');
      reloadProjects();
    } finally {
      opening = false;
    }
  }

  Future<void> create() async {
    if (creating) return;
    setState(() => creating = true);
    try {
      final project = EditProject(
        id: 'project_${DateTime.now().microsecondsSinceEpoch}',
        title: context.l10n.videoProject,
        clips: [],
        updatedAt: DateTime.now(),
      );
      await repository.save(project);
      if (mounted) await open(project.id);
    } catch (e) {
      if (mounted) {
        showFailure(context, e, operation: UserOperation.createDraft);
      }
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  Future<void> duplicate(EditProject source) async {
    if (creating) return;
    setState(() => creating = true);
    try {
      final copy = EditProject(
        id: 'project_${DateTime.now().microsecondsSinceEpoch}',
        clips: source.clips,
        effects: source.effects,
        title: '${source.title} copy',
        updatedAt: DateTime.now(),
      );
      await repository.save(copy);
      reloadProjects();
    } catch (e) {
      if (mounted) {
        showFailure(context, e, operation: UserOperation.createDraft);
      }
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    primary: true,
    padding: EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md + MediaQuery.paddingOf(context).bottom,
    ),
    children: [
      SectionTitle(context.l10n.editingStudio),
      Wrap(
        children: [
          for (final kind in ['video', 'photo'])
            TextButton.icon(
              onPressed: pinning ? null : () => pin(kind),
              icon: const Icon(AppIcons.create),
              label: Text(
                context.l10n.pinEditorShortcut(context.effectValue(kind)),
              ),
            ),
        ],
      ),
      StudioBentoGrid(
        children: [
          BentoCard(
            title: context.l10n.newVideoProject,
            description: context.l10n.trimMergeEffects,
            icon: AppIcons.newProject,
            onTap: creating ? null : create,
            badge: creating ? context.l10n.openingYourProject : null,
          ),
          BentoCard(
            title: context.l10n.editPhoto,
            description: context.l10n.cropAnnotateACopy,
            icon: AppIcons.photoEdit,
            accent: context.studioColors.cyan,
            onTap: () => context.go('/photos'),
          ),
        ],
      ),
      SectionTitle(context.l10n.savedDrafts),
      TextButton.icon(
        onPressed: () => context.push('/exports'),
        icon: const Icon(AppIcons.export),
        label: Text(context.l10n.exportQueue),
      ),
      FutureBuilder<List<EditProject>>(
        future: projects,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return StudioLoadingState(label: context.l10n.loadingYourDrafts);
          }
          if (snapshot.hasError) {
            return Column(
              children: [
                Text(
                  context.message(
                    UserMessages.failure(
                      snapshot.error,
                      operation: UserOperation.loadDrafts,
                    ).text,
                  ),
                ),
                TextButton(
                  onPressed: reloadProjects,
                  child: Text(context.l10n.retryDrafts),
                ),
              ],
            );
          }
          final rows = snapshot.data ?? [];
          final warning = repository.unreadableCount == 0
              ? const SizedBox.shrink()
              : Text(
                  context.l10n.unreadableDraftCount(
                    context.displayValue(repository.unreadableCount),
                  ),
                );
          if (rows.isEmpty) {
            return Column(
              children: [
                warning,
                StudioEmptyState(
                  title: context.l10n.noDraftsYet,
                  description:
                      context.l10n.createAProjectOriginalsStayUnchanged,
                  icon: AppIcons.videos,
                ),
              ],
            );
          }
          return Column(
            children: [
              warning,
              for (final project in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: StudioCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: const StudioIconTile(icon: AppIcons.videos),
                      title: Text(project.title),
                      subtitle: Text(
                        context.l10n.projectClipSummary(
                          context.displayValue(project.clips.length),
                          context.displayValue(
                            context.decimal(
                              (project.duration.inMilliseconds / 1000),
                              digits: 1,
                            ),
                          ),
                        ),
                      ),
                      onTap: () => open(project.id),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: context.l10n.duplicateDraft,
                            onPressed: creating
                                ? null
                                : () => duplicate(project),
                            icon: const Icon(AppIcons.newProject),
                          ),
                          IconButton(
                            tooltip: context.l10n.deleteDraft,
                            icon: const Icon(AppIcons.trash),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(context.l10n.deleteDraft785099),
                                  content: Text(
                                    context
                                        .l10n
                                        .sourceVideosAndExportedFilesAreKept,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(context.l10n.cancel),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(context.l10n.deleteDraft),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                try {
                                  await repository.delete(project.id);
                                  if (mounted) {
                                    reloadProjects();
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    showFailure(
                                      context,
                                      e,
                                      operation: UserOperation.deleteDraft,
                                    );
                                  }
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}
