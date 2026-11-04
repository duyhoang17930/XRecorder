import 'package:flutter/foundation.dart';

import '../../core/domain/models.dart';
import '../../core/domain/repositories.dart';

class ProjectController extends ChangeNotifier {
  ProjectController(this.project, this.repository);
  EditProject project;
  final EditProjectRepository repository;
  final _undo = <EditProject>[], _redo = <EditProject>[];
  Future<void> _pending = Future.value();
  Future<void> get flushed => _pending;
  bool _disposed = false;
  String? saveError;
  bool saving = false;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _save() {
    final snapshot = project;
    saving = true;
    saveError = null;
    _pending = _pending.then((_) async {
      try {
        await repository.save(snapshot);
        if (identical(project, snapshot)) {
          saving = false;
          saveError = null;
        }
      } catch (e) {
        saveError = 'Draft not saved: $e';
        saving = false;
      }
      _notify();
    });
    _notify();
  }

  void retrySave() => _save();
  void change(EditProject value) {
    _undo.add(project);
    if (_undo.length > 50) _undo.removeAt(0);
    _redo.clear();
    project = value;
    _save();
  }

  void add(MediaItem item) {
    final duration = item.duration;
    if (project.clips.length >= 30 ||
        item.kind != MediaKind.video ||
        duration == null ||
        duration < const Duration(milliseconds: 200)) {
      throw const FormatException(
        'Choose a playable video of at least 0.2 seconds. Maximum 30 clips.',
      );
    }
    change(
      project.copyWith(
        clips: [
          ...project.clips,
          TimelineClip(
            mediaId: item.uri.toString(),
            title: item.displayName,
            inPoint: Duration.zero,
            outPoint: duration,
            sourceDuration: duration,
          ),
        ],
      ),
    );
  }

  void update(int index, TimelineClip clip) {
    final clips = project.clips.toList();
    clips[index] = clip;
    change(project.copyWith(clips: clips));
  }

  void remove(int index) {
    final clips = project.clips.toList()..removeAt(index);
    change(project.copyWith(clips: clips));
  }

  void move(int index, int target) {
    if (target < 0 || target >= project.clips.length) return;
    final clips = project.clips.toList();
    clips.insert(target, clips.removeAt(index));
    change(project.copyWith(clips: clips));
  }

  void split(Duration position) {
    var offset = Duration.zero;
    for (var i = 0; i < project.clips.length; i++) {
      final clip = project.clips[i];
      final end = offset + clip.duration;
      if (position > offset && position < end) {
        final cut = clip.inPoint + position - offset;
        if (cut - clip.inPoint < const Duration(milliseconds: 200) ||
            clip.outPoint - cut < const Duration(milliseconds: 200) ||
            project.clips.length >= 30) {
          throw const FormatException(
            'Leave at least 0.2 seconds on both sides of the split.',
          );
        }
        final clips = project.clips.toList()
          ..replaceRange(i, i + 1, [
            clip.copyWith(outPoint: cut),
            clip.copyWith(inPoint: cut),
          ]);
        change(project.copyWith(clips: clips));
        return;
      }
      offset = end;
    }
    throw const FormatException(
      'Move the playhead inside a clip before splitting.',
    );
  }

  void undo() {
    if (!canUndo) return;
    _redo.add(project);
    project = _undo.removeLast();
    _save();
  }

  void redo() {
    if (!canRedo) return;
    _undo.add(project);
    project = _redo.removeLast();
    _save();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
