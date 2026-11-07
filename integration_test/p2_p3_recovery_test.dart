import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/media/media_actions.dart';
import 'package:xrecorder/features/media/media_repository.dart';

import '../test/fixtures/visual_catalog.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'backup-only draft recovery, corrupt IO isolation and fixture trash restore',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Recovery test: synthetic data only')),
        ),
      );
      final repository = AndroidEditProjectRepository();
      await repository.list();
      final baselineUnreadable = repository.unreadableCount;
      final id = 'm6_recovery_${DateTime.now().microsecondsSinceEpoch}';
      final original = EditProject(
        id: id,
        title: 'Recovery fixture',
        clips: [],
        updatedAt: DateTime.now(),
      );
      await repository.save(original);
      await expectLater(
        repository.call<void>(
          'save',
          jsonEncode({
            ...original.toJson(),
            'notes': List.filled(400000, 'ế').join(),
          }),
        ),
        throwsA(isA<DomainFailure>()),
      );
      expect((await repository.find(id))!.toJson(), original.toJson());
      debugPrint('P2_P3_RECOVERY_READY=$id');
      // The host moves only this newly-created fixture to .bak and adds a bounded unreadable fixture.
      var recovered = false;
      for (var i = 0; i < 120; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final rows = await repository.list();
        if (repository.unreadableCount > baselineUnreadable &&
            rows.any((p) => p.id == id)) {
          recovered = true;
          break;
        }
      }
      expect(
        recovered,
        isTrue,
        reason: 'Host recovery fixture not injected; run tool/p2_p3_recovery_fixture.py.',
      );
      expect((await repository.find(id))!.toJson(), original.toJson());
      final observedUnreadable = repository.unreadableCount;
      // Repair only the deliberately unreadable fixture created by this run; keep it as a normal draft.
      await repository.save(
        EditProject(
          id: '${id}_unreadable',
          title: 'Preserved recovery test fixture',
          clips: [],
          updatedAt: DateTime.now(),
        ),
      );
      final catalog = AndroidMediaRepository();
      addTearDown(catalog.dispose);
      final bytes = await fixtureImage();
      final sourceUri = (await AndroidMediaRepository.channel
          .invokeMethod<String>('saveImage', {'bytes': bytes}))!;
      final source = (await catalog.find(sourceUri))!;
      final actions = AndroidMediaActions();
      final entry = await actions.trash(
        source,
      ); // Only the fresh fixture, never existing media/trash collections.
      expect(await catalog.find(sourceUri), isNull);
      final restored = await actions.restore(entry.id);
      expect(
        await AndroidMediaRepository.channel.invokeMethod('imageBytes', {
          'uri': restored.id,
        }),
        orderedEquals(bytes),
      );
      expect(restored.id, isNot(sourceUri));
      final broken = EditProject(
        id: '${id}_missing',
        updatedAt: DateTime.now(),
        clips: [
          TimelineClip(
            mediaId: 'content://media/external/video/media/999999999',
            inPoint: Duration.zero,
            outPoint: const Duration(seconds: 1),
            sourceDuration: const Duration(seconds: 1),
          ),
        ],
      );
      final jobId = await AndroidEditProjectRepository.channel
          .invokeMethod<String>('exportStart', broken.toJson());
      Map<String, dynamic> job = {};
      for (var i = 0; i < 60; i++) {
        final rows = (jsonDecode(
          (await AndroidEditProjectRepository.channel.invokeMethod<String>(
            'exportList',
          ))!,
        ) as List).cast<Map<String, dynamic>>();
        job = rows.firstWhere((row) => row['id'] == jobId);
        if (['failed', 'completed'].contains(job['state'])) break;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      expect(job['state'], 'failed');
      expect(job['uri'], isNull);
      binding.reportData = {
        'draftId': id,
        'backupOnlyRecovered': true,
        'oversizedUtf8WriteRejected': true,
        'unreadableCount': observedUnreadable,
        'baselineUnreadable': baselineUnreadable,
        'restoredImageUri': restored.id,
        'sourceBytesPreserved': true,
        'outputsRetained': true,
        'missingSourceJobFailed': job['state'] == 'failed',
      };
      debugPrint('P2_P3_RECOVERY_COMPLETE=$id');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
