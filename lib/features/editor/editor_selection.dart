import '../../core/domain/models.dart';

/// Presentation selection only. History and clip identity stay owned by P3.
int retainClipSelection(
  List<TimelineClip> before,
  List<TimelineClip> after,
  int selected,
) {
  if (after.isEmpty) return 0;
  final previous = before.elementAtOrNull(selected);
  if (previous != null) {
    if (selected < after.length && identical(previous, after[selected])) {
      return selected;
    }
    final moved = after.indexWhere((clip) => identical(clip, previous));
    if (moved >= 0) return moved;
  }
  return selected.clamp(0, after.length - 1);
}
