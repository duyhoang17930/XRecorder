import 'package:xrecorder/l10n/localization.dart';
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
            title: Text(context.l10n.permanentlyDelete),
            content: Text(
              context.l10n.permanentDeleteName(
                context.displayValue(entry.originalMetadata.displayName),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.l10n.deletePermanently),
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
    appBar: AppBar(title: Text(context.l10n.trash)),
    body: CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Text(context.l10n.appOwnedMediaOnlyItemsBecomeEligible),
          ),
        ),
        if (busy) const SliverToBoxAdapter(child: LinearProgressIndicator()),
        FutureBuilder<List<TrashEntry>>(
          future: entries,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.message(
                          UserMessages.failure(
                            snapshot.error,
                            operation: UserOperation.loadTrash,
                          ).text,
                        ),
                      ),
                      TextButton(
                        onPressed: reloadEntries,
                        child: Text(context.l10n.retry),
                      ),
                    ],
                  ),
                ),
              );
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty && actions.unreadableTrashCount == 0) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text(context.l10n.trashIsEmpty)),
              );
            }
            return SliverMainAxisGroup(
              slivers: [
                if (actions.unreadableTrashCount > 0)
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        context.l10n.unreadableTrashCount(
                          context.displayValue(actions.unreadableTrashCount),
                        ),
                      ),
                    ),
                  ),
                SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final entry = items[index];
                    return ListTile(
                      title: Text(entry.originalMetadata.displayName),
                      subtitle: Text(
                        context.l10n.trashEntryExpiry(
                          context.displayValue(
                            context.fileSize(entry.originalMetadata.sizeBytes),
                          ),
                          context.displayValue(entry.expiresAt.toLocal()),
                        ),
                      ),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: context.l10n.restore,
                            onPressed: busy ? null : () => operate(entry, true),
                            icon: const Icon(AppIcons.restore),
                          ),
                          IconButton(
                            tooltip: context.l10n.deletePermanently,
                            onPressed: busy
                                ? null
                                : () => operate(entry, false),
                            icon: const Icon(AppIcons.deleteForever),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
