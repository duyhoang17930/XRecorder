import '../../core/domain/models.dart';

enum MediaSort {
  newest('Newest'),
  oldest('Oldest'),
  name('Name'),
  size('Largest'),
  duration('Longest');

  const MediaSort(this.label);
  final String label;

  int compare(MediaItem a, MediaItem b) {
    final result = switch (this) {
      MediaSort.newest => b.createdAt.compareTo(a.createdAt),
      MediaSort.oldest => a.createdAt.compareTo(b.createdAt),
      MediaSort.name => a.displayName.toLowerCase().compareTo(
        b.displayName.toLowerCase(),
      ),
      MediaSort.size => b.sizeBytes.compareTo(a.sizeBytes),
      MediaSort.duration => (b.duration?.inMilliseconds ?? -1).compareTo(
        a.duration?.inMilliseconds ?? -1,
      ),
    };
    return result != 0 ? result : a.id.compareTo(b.id);
  }

  bool get groupsByDate => this == newest || this == oldest;
}
