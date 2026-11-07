import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/media/media_sort.dart';

MediaItem item(String id, String name, int size, int? seconds) => MediaItem(
  id: id,
  uri: Uri.parse('content://fixture/$id'),
  kind: MediaKind.video,
  displayName: name,
  mimeType: 'video/mp4',
  sizeBytes: size,
  createdAt: DateTime(2026),
  modifiedAt: DateTime(2026),
  source: MediaSource.imported,
  duration: seconds == null ? null : Duration(seconds: seconds),
);
void main() {
  test('sorts stable ties, case-insensitive names, sizes and unknown durations last', () {
    final a = item('a', 'Zebra.mp4', 30, null);
    final b = item('b', 'apple.mp4', 20, 10);
    final c = item('c', 'Banana.mp4', 50, 5);
    List<String> ids(MediaSort sort) =>
        ([c, a, b]..sort(sort.compare)).map((e) => e.id).toList();
    expect(ids(MediaSort.newest), ['a', 'b', 'c']);
    expect(ids(MediaSort.oldest), ['a', 'b', 'c']);
    expect(ids(MediaSort.name), ['b', 'c', 'a']);
    expect(ids(MediaSort.size), ['c', 'a', 'b']);
    expect(ids(MediaSort.duration), ['b', 'c', 'a']);
    expect(MediaSort.name.groupsByDate, false);
  });
}
