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
                  ? 'Confirm the shortcut with your launcher.'
                  : 'This launcher does not support pinned shortcuts.',
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
        title: 'Video project',
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
    padding: const EdgeInsets.all(AppSpacing.md),
    children: [
      const SectionTitle('Editing Studio'),
      Wrap(
        children: [
          for (final kind in ['video', 'photo'])
            TextButton.icon(
              onPressed: pinning ? null : () => pin(kind),
              icon: const Icon(AppIcons.create),
              label: Text('Add $kind editor to Home'),
            ),
        ],
      ),
      StudioBentoGrid(
        children: [
          BentoCard(
            title: 'New video project',
            description: 'Trim, merge & effects',
            icon: AppIcons.newProject,
            onTap: creating ? null : create,
            badge: creating ? 'Opening…' : null,
          ),
          BentoCard(
            title: 'Edit photo',
            description: 'Crop & annotate a copy',
            icon: AppIcons.photoEdit,
            accent: context.studioColors.cyan,
            onTap: () => context.go('/photos'),
          ),
        ],
      ),
      const SectionTitle('Saved drafts'),
      TextButton.icon(
        onPressed: () => context.push('/exports'),
        icon: const Icon(AppIcons.export),
        label: const Text('Export queue'),
      ),
      FutureBuilder<List<EditProject>>(
        future: projects,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const StudioLoadingState(label: 'Loading your drafts…');
          }
          if (snapshot.hasError) {
            return Column(
              children: [
                Text(
                  UserMessages.failure(
                    snapshot.error,
                    operation: UserOperation.loadDrafts,
                  ).text,
                ),
                TextButton(
                  onPressed: reloadProjects,
                  child: const Text('Retry drafts'),
                ),
              ],
            );
          }
          final rows = snapshot.data ?? [];
          final warning = repository.unreadableCount == 0
              ? const SizedBox.shrink()
              : Text(
                  '${repository.unreadableCount} drafts could not be read. Their files are kept. Other drafts are available below.',
                );
          if (rows.isEmpty) {
            return Column(
              children: [
                warning,
                const StudioEmptyState(
                  title: 'No drafts yet',
                  description: 'Create a project. Originals stay unchanged.',
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
                        '${project.clips.length} clips · ${(project.duration.inMilliseconds / 1000).toStringAsFixed(1)}s',
                      ),
                      onTap: () => open(project.id),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: 'Duplicate draft',
                            onPressed: creating
                                ? null
                                : () => duplicate(project),
                            icon: const Icon(AppIcons.newProject),
                          ),
                          IconButton(
                            tooltip: 'Delete draft',
                            icon: const Icon(AppIcons.trash),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete draft?'),
                                  content: const Text(
                                    'Source videos and exported files are kept.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete draft'),
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
