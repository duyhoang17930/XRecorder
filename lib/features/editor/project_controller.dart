import 'package:flutter/foundation.dart';

import '../../core/domain/models.dart';
import '../../core/domain/repositories.dart';
import 'timeline_effects.dart';

class ProjectController extends ChangeNotifier {
  ProjectController(this.project, this.repository);
  EditProject project;
  final EditProjectRepository repository;
  final _undo = <EditProject>[], _redo = <EditProject>[];
  Future<void> _pending = Future.value();
  Future<void> get flushed => _pending;
  EditProject? _queued;
  bool _draining = false;
  bool _disposed = false;
  String? saveError;
  bool saving = false;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _save() {
    _queued = project;
    saving = true;
    saveError = null;
    if (!_draining) {
      _draining = true;
      _pending = Future<void>.microtask(_drainSaves);
    }
    _notify();
  }

  Future<void> _drainSaves() async {
    while (_queued != null) {
      final snapshot = _queued!;
      _queued = null;
      try {
        await repository.save(snapshot);
        if (identical(project, snapshot)) saveError = null;
      } catch (_) {
        if (identical(project, snapshot)) {
          saveError = 'Draft could not be saved. Free some storage and retry.';
        }
      }
    }
    _draining = false;
    saving = false;
    _notify();
  }

  void retrySave() => _save();
  void change(EditProject value) {
    if (value.duration < project.duration && value.speed == project.speed) {
      value = value.copyWith(
        effects: fitTimelineEffects(
          value.effects,
          value.duration.inMilliseconds,
        ),
      );
    }
    _undo.add(project);
    if (_undo.length > 50) _undo.removeAt(0);
    _redo.clear();
    project = value;
    _save();
  }

  void add(MediaItem item) {
    final duration = item.kind == MediaKind.image
        ? const Duration(seconds: 5)
        : item.duration;
    if (project.clips.length >= 30 ||
        (item.kind != MediaKind.video && item.kind != MediaKind.image) ||
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
            isImage: item.kind == MediaKind.image,
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

  void duplicate(int index) {
    if (project.clips.length >= 30) {
      throw const FormatException('Maximum 30 clips.');
    }
    final clips = project.clips.toList();
    clips.insert(index + 1, clips[index]);
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
    position = Duration(
      microseconds: (position.inMicroseconds * project.speed).round(),
    );
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
