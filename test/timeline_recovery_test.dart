import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/domain/repositories.dart';
import 'package:xrecorder/features/editor/project_controller.dart';

class _Repository implements EditProjectRepository {
  EditProject? saved;
  @override
  Future<void> save(EditProject value) async {
    saved = value;
  }

  @override
  Future<EditProject?> find(String id) async => saved;
  @override
  Future<void> delete(String id) async {}
}

void main() {
  test(
    'timeline shortening trims annotation and fades, Undo restores all content',
    () async {
      final clip = TimelineClip(
        mediaId: 'content://qa/video',
        inPoint: Duration.zero,
        outPoint: const Duration(seconds: 4),
        sourceDuration: const Duration(seconds: 4),
      );
      final original = EditProject(
        id: 'annotation',
        clips: [clip],
        updatedAt: DateTime(2026),
        effects: {
          'subtitles': [
            {'startMs': 500, 'endMs': 3500, 'text': 'Kept and trimmed'},
            {'startMs': 3500, 'endMs': 4000, 'text': 'Outside cut'},
          ],
          'layers': [
            {'kind': 'text', 'text': 'Overlay', 'startMs': 500, 'endMs': 3500},
          ],
          'audioTracks': [
            {
              'uri': 'content://qa/audio',
              'inMs': 0,
              'outMs': 3500,
              'offsetMs': 500,
              'fadeInMs': 1000,
              'fadeOutMs': 2000,
            },
          ],
          'fadeInMs': 1000,
          'fadeOutMs': 2000,
        },
      );
      final repository = _Repository();
      final controller = ProjectController(original, repository);
      controller.update(0, clip.copyWith(outPoint: const Duration(seconds: 2)));
      final effects = controller.project.effects;
      expect((effects['subtitles'] as List).length, 1);
      expect(((effects['subtitles'] as List).single as Map)['endMs'], 2000);
      final audio = (effects['audioTracks'] as List).single as Map;
      expect(audio['outMs'], 1500);
      expect((audio['fadeInMs'] as int) + (audio['fadeOutMs'] as int), 1500);
      controller.undo();
      await controller.flushed;
      expect(controller.project.effects, original.effects);
      expect(controller.project.duration, original.duration);
      expect(repository.saved!.effects, original.effects);
      controller.dispose();
    },
  );
}
