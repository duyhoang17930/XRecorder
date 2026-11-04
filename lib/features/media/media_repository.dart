import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/domain/models.dart';
import '../../core/domain/repositories.dart';

abstract interface class CatalogRepository implements MediaRepository {
  Future<Uri?> savedFolder();
  Future<Uint8List> thumbnail(Uri uri);
  Future<Map<String, int>> storage();
  void refresh();
  void dispose();
}

class AndroidMediaRepository implements CatalogRepository {
  static const channel = MethodChannel('com.xrecorder/media');
  final _changes = StreamController<void>.broadcast();
  @override
  Stream<void> get changes => _changes.stream;
  Future<T?> _call<T>(String method, [Object? arguments]) async {
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw DomainFailure(
        FailureCode.values.firstWhere(
          (v) => v.name == e.code,
          orElse: () => FailureCode.io,
        ),
        e.message ?? 'Media operation failed.',
      );
    } on MissingPluginException {
      throw const DomainFailure(
        FailureCode.unavailable,
        'The media library requires Android.',
      );
    }
  }

  static MediaItem decode(Map<Object?, Object?> map) {
    final mime = map['mime'] as String? ?? 'application/octet-stream';
    return MediaItem(
      id: map['id'] as String,
      uri: Uri.parse(map['uri'] as String),
      kind: mime.startsWith('video/')
          ? MediaKind.video
          : mime == 'image/gif'
          ? MediaKind.gif
          : MediaKind.image,
      displayName: map['name'] as String? ?? 'Untitled',
      mimeType: mime,
      sizeBytes: (map['size'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created'] as num?)?.toInt() ?? 0,
      ),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['modified'] as num?)?.toInt() ?? 0,
      ),
      source: map['source'] == 'recording'
          ? MediaSource.recording
          : MediaSource.imported,
      duration: map['duration'] is num
          ? Duration(milliseconds: (map['duration'] as num).toInt())
          : null,
      width: (map['width'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toInt(),
      bitrate: (map['bitrate'] as num?)?.toInt(),
      fps: (map['fps'] as num?)?.toDouble(),
      hasAudio: map['hasAudio'] as bool?,
      owned: map['owned'] == true,
      folderUri: map['folder'] is String
          ? Uri.parse(map['folder'] as String)
          : null,
    );
  }

  @override
  Future<List<MediaItem>> list({required MediaKind kind, Uri? folder}) async {
    final rows =
        await _call<List<Object?>>('list', {
          'kind': kind == MediaKind.video ? 'video' : 'image',
          'folder': folder?.toString(),
        }) ??
        [];
    return rows.map((r) => decode(r as Map<Object?, Object?>)).toList();
  }

  @override
  Future<MediaItem?> find(String id) async {
    final row = await _call<Map<Object?, Object?>>('find', {'id': id});
    return row == null ? null : decode(row);
  }

  @override
  Future<Uri?> savedFolder() async {
    final value = await _call<String>('folder');
    return value == null ? null : Uri.parse(value);
  }

  @override
  Future<Uri?> selectFolder() async {
    final value = await _call<String>('selectFolder');
    return value == null ? null : Uri.parse(value);
  }

  @override
  Future<Uint8List> thumbnail(Uri uri) async =>
      await _call<Uint8List>('thumbnail', {'uri': uri.toString()}) ??
      Uint8List(0);
  @override
  Future<Map<String, int>> storage() async =>
      (await _call<Map<Object?, Object?>>('storage') ?? {}).map(
        (k, v) => MapEntry(k as String, (v as num).toInt()),
      );
  @override
  void refresh() => _changes.add(null);
  @override
  void dispose() => _changes.close();
}

class MediaScope extends InheritedWidget {
  const MediaScope({super.key, required this.repository, required super.child});
  final CatalogRepository repository;
  static CatalogRepository of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MediaScope>()!.repository;
  @override
  bool updateShouldNotify(MediaScope oldWidget) =>
      oldWidget.repository != repository;
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
