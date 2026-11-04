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
  Future<void> open(String id) async {
    await context.push('/editor/project/$id');
    if (mounted) setState(() => projects = repository.list());
  }

  Future<void> create() async {
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
      if (mounted) showNotice(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const SectionTitle('Editing Studio'),
      const Text(
        'Non-destructive video drafts. Trim, split, reorder, merge, crop and rotate with a native preview.',
      ),
      TextButton.icon(
        onPressed: create,
        icon: const Icon(Icons.add),
        label: const Text('New video project'),
      ),
      TextButton.icon(
        onPressed: () => context.go('/photos'),
        icon: const Icon(Icons.draw),
        label: const Text('Crop & annotate a photo'),
      ),
      const SectionTitle('Saved drafts'),
      TextButton.icon(
        onPressed: () => context.push('/exports'),
        icon: const Icon(Icons.file_upload_outlined),
        label: const Text('Export queue'),
      ),
      FutureBuilder<List<EditProject>>(
        future: projects,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Column(
              children: [
                Text(snapshot.error.toString()),
                TextButton(
                  onPressed: () => setState(() => projects = repository.list()),
                  child: const Text('Retry drafts'),
                ),
              ],
            );
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) return const Text('No drafts yet');
          return Column(
            children: [
              for (final project in rows)
                ListTile(
                  title: Text(project.title),
                  subtitle: Text(
                    '${project.clips.length} clips · ${(project.duration.inMilliseconds / 1000).toStringAsFixed(1)}s',
                  ),
                  onTap: () => open(project.id),
                  trailing: IconButton(
                    tooltip: 'Delete draft',
                    icon: const Icon(Icons.delete_outline),
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
                              onPressed: () => Navigator.pop(context, false),
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
                            setState(() => projects = repository.list());
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showNotice(context, e.toString());
                          }
                        }
                      }
                    },
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}
