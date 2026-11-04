import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/domain/repositories.dart';
import 'package:xrecorder/features/editor/project_controller.dart';

class MemoryProjects implements EditProjectRepository {
  final values = <String, String>{};
  bool fail = false;
  @override
  Future<void> delete(String id) async {
    values.remove(id);
  }

  @override
  Future<EditProject?> find(String id) async => values[id] == null
      ? null
      : EditProject.fromJson(jsonDecode(values[id]!) as Map<String, dynamic>);
  @override
  Future<void> save(EditProject project) async {
    if (fail) throw StateError('Disk full');
    values[project.id] = jsonEncode(project.toJson());
  }
}

void main() {
  test(
    'Split, reorder, undo and reopened draft preserve sources and total time',
    () async {
      final original = EditProject(
        id: 'draft',
        clips: [
          TimelineClip(
            mediaId: 'content://media/external/video/media/1',
            inPoint: const Duration(seconds: 1),
            outPoint: const Duration(seconds: 9),
            sourceDuration: const Duration(seconds: 10),
          ),
        ],
        updatedAt: DateTime.now(),
      );
      final repository = MemoryProjects();
      final model = ProjectController(original, repository);
      model.split(const Duration(seconds: 3));
      expect(model.project.clips.map((c) => c.duration.inSeconds), [3, 5]);
      model.move(1, 0);
      expect(model.project.clips.first.inPoint, const Duration(seconds: 4));
      model.remove(0);
      model.undo();
      expect(model.project.duration, const Duration(seconds: 8));
      await model.flushed;
      final reopened = (await repository.find('draft'))!;
      expect(reopened.toJson(), model.project.toJson());
      expect(original.clips.length, 1);
      expect(original.clips.single.inPoint, const Duration(seconds: 1));
      expect(
        () => model.split(const Duration(milliseconds: 50)),
        throwsFormatException,
      );
      model.dispose();
    },
  );
  test('Invalid crop is rejected and failed draft save can retry', () async {
    expect(
      () => TimelineClip(
        mediaId: 'content://media/1',
        inPoint: Duration.zero,
        outPoint: const Duration(seconds: 2),
        sourceDuration: const Duration(seconds: 1),
      ),
      throwsFormatException,
    );
    final repository = MemoryProjects()..fail = true;
    final model = ProjectController(
      EditProject(id: 'retry', clips: [], updatedAt: DateTime.now()),
      repository,
    );
    model.change(model.project.copyWith(title: 'Changed'));
    await model.flushed;
    expect(model.saveError, isNotNull);
    repository.fail = false;
    model.retrySave();
    await model.flushed;
    expect(model.saveError, isNull);
    expect((await repository.find('retry'))!.title, 'Changed');
    model.dispose();
  });
}
