import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Reuses decoded pixels when the compressed LRU returns a fresh byte buffer.
/// Buffers are immutable after publication, as required by MemoryImage.
/// Exact byte equality guards hash collisions and coarse URI timestamps.
final class ThumbnailImage extends MemoryImage {
  ThumbnailImage(super.bytes, {super.scale})
    : _contentHash = Object.hashAll(bytes);

  final int _contentHash;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThumbnailImage &&
          scale == other.scale &&
          _contentHash == other._contentHash &&
          listEquals(bytes, other.bytes);

  @override
  int get hashCode => Object.hash(ThumbnailImage, _contentHash, scale);
}
