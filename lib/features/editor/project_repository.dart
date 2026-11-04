import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/domain/models.dart';
import '../../core/domain/repositories.dart';

class AndroidEditProjectRepository implements EditProjectRepository {
  static const channel = MethodChannel('com.xrecorder/editor');
  Future<T?> call<T>(String method, [Object? value]) async {
    try {
      return await channel.invokeMethod<T>(method, value);
    } on PlatformException catch (e) {
      throw DomainFailure(
        FailureCode.io,
        e.message ?? 'Draft operation failed.',
      );
    } on MissingPluginException {
      throw const DomainFailure(
        FailureCode.unavailable,
        'Draft storage requires Android.',
      );
    }
  }

  Future<List<EditProject>> list() async =>
      (await call<List<Object?>>('list') ?? [])
          .map(
            (v) => EditProject.fromJson(
              jsonDecode(v as String) as Map<String, dynamic>,
            ),
          )
          .toList();
  @override
  Future<EditProject?> find(String id) async {
    final value = await call<String>('find', id);
    return value == null
        ? null
        : EditProject.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  @override
  Future<void> save(EditProject project) =>
      call<void>('save', jsonEncode(project.toJson()));
  @override
  Future<void> delete(String id) => call<void>('delete', id);
}
