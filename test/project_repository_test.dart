import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/editor/project_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'one unreadable document does not hide valid drafts and is reported',
    () async {
      final project = EditProject(
        id: 'valid',
        clips: [],
        updatedAt: DateTime(2026),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            AndroidEditProjectRepository.channel,
            (call) async => [
              jsonEncode(project.toJson()),
              '{"version":-1}',
              'broken json',
            ],
          );
      final repository = AndroidEditProjectRepository();
      expect((await repository.list()).single.id, 'valid');
      expect(repository.unreadableCount, 2);
    },
  );
}
