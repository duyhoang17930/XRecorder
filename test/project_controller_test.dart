import 'dart:convert';
import 'dart:async';

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

class SlowProjects extends MemoryProjects {
  final gate = Completer<void>();
  final saved = <EditProject>[];
  @override
  Future<void> save(EditProject project) async {
    saved.add(project);
    if (saved.length == 1) await gate.future;
    await super.save(project);
  }
}

void main() {
  test('export snapshot freezes nested lists and maps', () {
    final layers = <Object>[
      <String, Object>{'text': 'Original'},
    ];
    final project = EditProject(
      id: 'snapshot',
      clips: [],
      updatedAt: DateTime(2026),
      effects: {'layers': layers},
    );
    (layers.first as Map)['text'] = 'Changed';
    layers.clear();
    expect(
      ((project.effects['layers'] as List).first as Map)['text'],
      'Original',
    );
    expect(
      () => (project.effects['layers'] as List).clear(),
      throwsUnsupportedError,
    );
  });
  test('autosave coalesces edits while write is active and flush stores newest snapshot', () async {
    final repository = SlowProjects();
    final model = ProjectController(
      EditProject(id: 'coalesce', clips: [], updatedAt: DateTime(2026)),
      repository,
    );
    model.change(model.project.copyWith(title: 'First'));
    await Future<void>.delayed(Duration.zero);
    for (var i = 0; i < 40; i++) {
      model.change(model.project.copyWith(title: 'Edit $i'));
    }
    expect(repository.saved.length, 1);
    expect(model.saving, isTrue);
    repository.gate.complete();
    await model.flushed;
    expect(repository.saved.length, 2);
    expect((await repository.find('coalesce'))!.title, 'Edit 39');
    expect(model.saving, isFalse);
    expect(model.saveError, isNull);
    model.dispose();
  });
  test('still photo, duplicate, flip and legacy document reopen without modifying source', () async {
    final repository = MemoryProjects();
    final model = ProjectController(
      EditProject(id: 'photo', clips: [], updatedAt: DateTime(2026)),
      repository,
    );
    model.add(
      MediaItem(
        id: 'content://photo/1',
        uri: Uri.parse('content://photo/1'),
        kind: MediaKind.image,
        displayName: 'Photo.png',
        mimeType: 'image/png',
        sizeBytes: 100,
        createdAt: DateTime(2026),
        modifiedAt: DateTime(2026),
        source: MediaSource.imported,
      ),
    );
    model.duplicate(0);
    model.update(0, model.project.clips[0].copyWith(flipH: true));
    expect(model.project.duration, const Duration(seconds: 10));
    expect(model.project.clips[1].flipH, false);
    await model.flushed;
    final reopened = (await repository.find('photo'))!;
    expect(reopened.clips.first.isImage, true);
    expect(reopened.clips.first.flipH, true);
    final legacy = Map<String, dynamic>.from(reopened.clips.first.toJson())
      ..remove('isImage')
      ..remove('flipH')
      ..remove('flipV');
    expect(TimelineClip.fromJson(legacy).isImage, false);
    model.dispose();
  });
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
      model.change(
        original.copyWith(effects: {'speed': 2.0, 'text': 'Caption'}),
      );
      model.split(const Duration(seconds: 1));
      expect(model.project.clips.first.duration, const Duration(seconds: 2));
      expect(model.project.duration, const Duration(seconds: 4));
      await model.flushed;
      expect((await repository.find('draft'))!.effects, {
        'speed': 2.0,
        'text': 'Caption',
      });
      expect(
        () => original.copyWith(effects: {'speed': 0.0}),
        throwsFormatException,
      );
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
