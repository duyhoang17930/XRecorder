import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  @override
  Widget build(BuildContext context) => ListView(
    primary: true,
    padding: const EdgeInsets.all(AppSpacing.md),
    children: [
      const SectionTitle('Editing Studio'),
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
          if (rows.isEmpty) {
            return const StudioEmptyState(
              title: 'No drafts yet',
              description: 'Create a project. Originals stay unchanged.',
              icon: AppIcons.videos,
            );
          }
          return Column(
            children: [
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
                      trailing: IconButton(
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
                                  onPressed: () => Navigator.pop(context, true),
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
