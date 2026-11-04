import 'package:flutter/services.dart';

import '../../core/domain/models.dart';
import '../../core/domain/repositories.dart';
import 'media_repository.dart';

class AndroidMediaActions implements TrashRepository {
  static const channel = MethodChannel('com.xrecorder/media');
  Future<T?> call<T>(String method, [Object? arguments]) async {
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw DomainFailure(FailureCode.io, e.message ?? 'Media action failed.');
    } on MissingPluginException {
      throw const DomainFailure(
        FailureCode.unavailable,
        'This action requires Android.',
      );
    }
  }

  Future<void> preview(Uri uri) =>
      call<void>('preview', {'uri': uri.toString()});
  Future<void> share(Uri uri) => call<void>('share', {'uri': uri.toString()});
  Future<String> rename(Uri uri, String name) async =>
      (await call<String>('rename', {'uri': uri.toString(), 'name': name}))!;
  TrashEntry decode(Map<Object?, Object?> row) => TrashEntry(
    id: row['id'] as String,
    originalMetadata: AndroidMediaRepository.decode(
      row['originalMetadata'] as Map<Object?, Object?>,
    ),
    deletedAt: DateTime.fromMillisecondsSinceEpoch(
      (row['deletedAt'] as num).toInt(),
    ),
    expiresAt: DateTime.fromMillisecondsSinceEpoch(
      (row['expiresAt'] as num).toInt(),
    ),
    mode: DeletionMode.appManaged,
  );
  @override
  Future<List<TrashEntry>> list() async =>
      (await call<List<Object?>>('listTrash') ?? [])
          .map((v) => decode(v as Map<Object?, Object?>))
          .toList();
  @override
  Future<TrashEntry> trash(MediaItem item) async => decode(
    (await call<Map<Object?, Object?>>('trash', {'uri': item.uri.toString()}))!,
  );
  @override
  Future<MediaItem> restore(String id) async => AndroidMediaRepository.decode(
    (await call<Map<Object?, Object?>>('restore', {'id': id}))!,
  );
  @override
  Future<void> permanentlyDelete(String id) =>
      call<void>('permanentlyDelete', {'id': id});
}
