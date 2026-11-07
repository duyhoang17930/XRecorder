import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/domain/models.dart';
import '../../core/widgets/studio_widgets.dart';
import 'media_actions.dart';
import 'media_repository.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});
  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final actions = AndroidMediaActions();
  late Future<List<TrashEntry>> entries = actions.list();
  bool busy = false;
  void reloadEntries() {
    if (!mounted) return;
    final next = actions.list();
    setState(() {
      entries = next;
    });
  }

  Future<void> operate(TrashEntry entry, bool restore) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (!restore) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permanently delete?'),
            content: Text(
              '${entry.originalMetadata.displayName} cannot be restored after deletion.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete permanently'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
      MediaItem? restored;
      if (restore) {
        restored = await actions.restore(entry.id);
      } else {
        await actions.permanentlyDelete(entry.id);
      }
      if (!mounted) return;
      MediaScope.of(context).refresh();
      reloadEntries();
      if (restored != null) {
        context.push('/media/${Uri.encodeComponent(restored.id)}');
      }
    } catch (e) {
      if (mounted) {
        showFailure(
          context,
          e,
          operation: restore
              ? UserOperation.restore
              : UserOperation.deleteMedia,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Trash')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'App-owned media only. Items become eligible for permanent cleanup after 24 hours; cleanup runs when Trash is opened. Restoring creates a new item with a unique name.',
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        Expanded(
          child: FutureBuilder<List<TrashEntry>>(
            future: entries,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        UserMessages.failure(
                          snapshot.error,
                          operation: UserOperation.loadTrash,
                        ).text,
                      ),
                      TextButton(
                        onPressed: reloadEntries,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty && actions.unreadableTrashCount == 0) {
                return const Center(child: Text('Trash is empty'));
              }
              return ListView(
                children: [
                  if (actions.unreadableTrashCount > 0)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '${actions.unreadableTrashCount} trash entries need recovery. Their files have been kept.',
                      ),
                    ),
                  for (final entry in items)
                    ListTile(
                      title: Text(entry.originalMetadata.displayName),
                      subtitle: Text(
                        '${formatBytes(entry.originalMetadata.sizeBytes)} · Expires ${entry.expiresAt.toLocal()}',
                      ),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: 'Restore',
                            onPressed: busy ? null : () => operate(entry, true),
                            icon: const Icon(AppIcons.restore),
                          ),
                          IconButton(
                            tooltip: 'Delete permanently',
                            onPressed: busy
                                ? null
                                : () => operate(entry, false),
                            icon: const Icon(AppIcons.deleteForever),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
