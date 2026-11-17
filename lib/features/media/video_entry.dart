import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/domain/models.dart';
import '../../core/widgets/studio_widgets.dart';
import '../editor/editor_entry.dart';
import '../editor/project_repository.dart';
import 'media_actions.dart';
import 'media_repository.dart';

/// Both entry points use the same Android menu and existing media operations.
Future<void> openVideo(
  BuildContext context,
  MediaItem item, {
  bool play = true,
}) async {
  final repository = MediaScope.of(context);
  try {
    final editUri = await AndroidMediaActions().videoMenu(item.uri, play: play);
    repository.refresh();
    if (editUri == null || !context.mounted) return;
    // Rename on API 24–28 can change the URI; resolve the current metadata.
    final current = await repository.find(editUri);
    if (current == null || !context.mounted) return;
    final project = await createEditorProject(
      media: [current],
      title: current.displayName,
      repository: AndroidEditProjectRepository(),
    );
    if (context.mounted) {
      await context.push('/editor/project/${project.id}');
    }
  } catch (error) {
    if (context.mounted) {
      showFailure(context, error, operation: UserOperation.openMedia);
    }
  }
}
