import 'dart:typed_data';

/// Compressed thumbnails only. Decoded images remain owned by Flutter's image cache.
/// Futures coalesce in-flight reads; a clear/eviction cannot be undone by a late reply.
class ThumbnailCache {
  ThumbnailCache({this.maxEntries = 64, this.maxBytes = 8 * 1024 * 1024})
    : assert(maxEntries >= 0),
      assert(maxBytes >= 0);
  final int maxEntries, maxBytes;
  final _entries = <Object, _ThumbnailEntry>{};
  int _bytes = 0;
  int get retainedBytes => _bytes;
  int get length => _entries.length;

  Future<Uint8List> load(Object key, Future<Uint8List> Function() read) {
    final hit = _entries.remove(key);
    if (hit != null) {
      _entries[key] = hit;
      return hit.future;
    }
    final entry = _ThumbnailEntry();
    _entries[key] = entry;
    entry.future = Future<Uint8List>.sync(read).then(
      (data) {
        if (identical(_entries[key], entry)) {
          if (data.isEmpty) {
            _remove(key);
            return data;
          }
          entry.bytes = data.length;
          _bytes += entry.bytes;
          _trim();
        }
        return data;
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_entries[key], entry)) _remove(key);
        Error.throwWithStackTrace(error, stack);
      },
    );
    _trim();
    return entry.future;
  }

  void _remove(Object key) {
    final entry = _entries.remove(key);
    if (entry != null) _bytes -= entry.bytes;
  }

  void _trim() {
    while (_entries.length > maxEntries || _bytes > maxBytes) {
      _remove(_entries.keys.first);
    }
  }

  void clear() {
    _entries.clear();
    _bytes = 0;
  }
}

class _ThumbnailEntry {
  late Future<Uint8List> future;
  int bytes = 0;
}
