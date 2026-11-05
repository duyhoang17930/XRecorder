import 'dart:async';
import 'dart:typed_data';

import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/media/media_repository.dart';

class TestCatalog implements CatalogRepository {
  final events = StreamController<void>.broadcast();
  Object? failure;
  Uri? selection;
  bool cancelled = false;
  final items = List.generate(
    15,
    (i) => MediaItem(
      id: 'content://test/$i',
      uri: Uri.parse('content://test/$i'),
      kind: MediaKind.video,
      displayName: 'Clip $i.mp4',
      mimeType: 'video/mp4',
      sizeBytes: 2048,
      createdAt: DateTime(2026, 1, 1),
      modifiedAt: DateTime(2026, 1, 1),
      source: MediaSource.recording,
    ),
  );
  @override
  Stream<void> get changes => events.stream;
  @override
  Future<List<MediaItem>> list({required MediaKind kind, Uri? folder}) async {
    if (failure != null) throw failure!;
    return kind == MediaKind.video ? items : [];
  }

  @override
  Future<MediaItem?> find(String id) async =>
      items.where((i) => i.id == id).firstOrNull;
  @override
  Future<Uri?> savedFolder() async => selection;
  @override
  Future<Uri?> selectFolder() async => cancelled ? null : selection;
  @override
  Future<Uint8List> thumbnail(Uri uri) =>
      Future.error(const DomainFailure(FailureCode.missing, 'No thumbnail'));
  @override
  Future<Map<String, int>> storage() async => {
    'videos': 30720,
    'images': 0,
    'free': 1024000,
  };
  @override
  void refresh() => events.add(null);
  @override
  void dispose() => events.close();
}
