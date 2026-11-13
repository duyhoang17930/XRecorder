import '../../core/domain/models.dart';
import '../../core/domain/repositories.dart';

/// A launch creates one nonempty project only after the picker is accepted.
/// Media references stay unchanged; persistence remains the P3 repository's job.
Future<EditProject> createEditorProject({
  required List<MediaItem> media,
  required String title,
  required EditProjectRepository repository,
}) async {
  if (media.isEmpty || media.length > 30) {
    throw const FormatException('Choose a playable video or a still photo.');
  }
  final clips = media.map((item) {
    final image = item.kind == MediaKind.image;
    final duration = image ? const Duration(seconds: 5) : item.duration;
    if ((!image && item.kind != MediaKind.video) || duration == null) {
      throw const FormatException('Choose a playable video or a still photo.');
    }
    return TimelineClip(
      mediaId: item.uri.toString(),
      title: item.displayName,
      inPoint: Duration.zero,
      outPoint: duration,
      sourceDuration: duration,
      isImage: image,
    );
  }).toList();
  final project = EditProject(
    id: 'project_${DateTime.now().microsecondsSinceEpoch}',
    title: title,
    clips: clips,
    updatedAt: DateTime.now(),
  );
  await repository.save(project);
  return project;
}
