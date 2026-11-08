import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/editor/project_repository.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Export/draft process kill recovery without source loss', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Process recovery QA'))),
    );
    const engine = AndroidEditProjectRepository.channel;
    const media = MethodChannel('com.xrecorder/media');
    const source =
        'content://com.xrecorder.xrecorder.files/media/p2_p3_audio_video.mp4';
    final repo = AndroidEditProjectRepository();
    if (const bool.fromEnvironment('PUBLICATION_REPLAY')) {
      final marker = File(
        '/sdcard/Android/data/com.xrecorder.xrecorder/files/media/quality_publication.json',
      );
      final original = File(
        '/sdcard/Android/data/com.xrecorder.xrecorder/files/media/p2_p3_audio_video.mp4',
      );
      if (!const bool.fromEnvironment('PUBLICATION_RESUME')) {
        final project = EditProject(
          id: 'publication_qa_${DateTime.now().microsecondsSinceEpoch}',
          title: 'publication_qa',
          updatedAt: DateTime.now(),
          clips: [
            TimelineClip(
              mediaId: source,
              inPoint: Duration.zero,
              outPoint: const Duration(seconds: 4),
              sourceDuration: const Duration(seconds: 4),
            ),
          ],
        );
        await repo.save(project);
        final id = (await engine.invokeMethod<String>(
          'exportStart',
          project.toJson(),
        ))!;
        Map<String, dynamic> job = {};
        for (var n = 0; n < 240; n++) {
          final rows = (jsonDecode(
            (await engine.invokeMethod<String>('exportList'))!,
          ) as List).cast<Map<String, dynamic>>();
          job = rows.firstWhere((row) => row['id'] == id);
          if (['completed', 'failed', 'cancelled'].contains(job['state'])) {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        expect(job['state'], 'completed', reason: job.toString());
        final count = (await media.invokeListMethod<dynamic>('list', {
          'kind': 'video',
        }))!.length;
        final data = {
          'jobId': id,
          'projectId': project.id,
          'uri': job['uri'],
          'videoCount': count,
          'project': project.toJson(),
          'sourceBytes': base64Encode(await original.readAsBytes()),
        };
        await marker.writeAsString(jsonEncode(data));
        binding.reportData = {
          'phase': 'publication_before',
          'jobId': id,
          'projectId': project.id,
          'uri': job['uri'],
          'videoCount': count,
        };
      } else {
        final data =
            jsonDecode(await marker.readAsString()) as Map<String, dynamic>;
        final rows = (jsonDecode(
          (await engine.invokeMethod<String>('exportList'))!,
        ) as List).cast<Map<String, dynamic>>();
        final recovered = rows.firstWhere((row) => row['id'] == data['jobId']);
        expect(recovered['state'], 'completed');
        expect(recovered['uri'], data['uri']);
        expect(
          (await media.invokeListMethod<dynamic>('list', {
            'kind': 'video',
          }))!.length,
          data['videoCount'],
        );
        expect(
          (await repo.find(data['projectId'] as String))!.toJson(),
          data['project'],
        );
        expect(
          await original.readAsBytes(),
          orderedEquals(base64Decode(data['sourceBytes'] as String)),
        );
        expect(
          await media.invokeMethod<Uint8List>('thumbnail', {
            'uri': data['uri'],
          }),
          isNotEmpty,
        );
        binding.reportData = {
          'phase': 'publication_after',
          'jobId': data['jobId'],
          'uri': data['uri'],
          'completedWithoutDuplicate': true,
          'draftUnchanged': true,
          'sourceUnchanged': true,
          'scope': 'Real published MediaStore URI recovered from a simulated finalizing checkpoint, followed by actual process restart.',
        };
      }
      return;
    }
    if (const bool.fromEnvironment('IO_FAULT')) {
      final project = EditProject(
        id: 'io_fault_qa_${DateTime.now().microsecondsSinceEpoch}',
        title: 'io_fault_qa',
        updatedAt: DateTime.now(),
        clips: [
          TimelineClip(
            mediaId: source,
            inPoint: Duration.zero,
            outPoint: const Duration(seconds: 4),
            sourceDuration: const Duration(seconds: 4),
          ),
        ],
      );
      await repo.save(project);
      final id = (await engine.invokeMethod<String>(
        'exportStart',
        project.toJson(),
      ))!;
      Future<Map<String, dynamic>> terminal() async {
        for (var i = 0; i < 180; i++) {
          final jobs = (jsonDecode(
            (await engine.invokeMethod<String>('exportList'))!,
          ) as List).cast<Map<String, dynamic>>();
          final job = jobs.firstWhere((j) => j['id'] == id);
          if (['failed', 'completed', 'cancelled'].contains(job['state'])) {
            return job;
          }
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        throw StateError('Journal fault job did not finish');
      }

      final failed = await terminal();
      expect(
        failed['state'],
        'failed',
        reason:
            'Host must inject a real journal write failure before publication',
      );
      expect(failed['uri'], isNull);
      expect((await repo.find(project.id))!.toJson(), project.toJson());
      await Future<void>.delayed(const Duration(seconds: 12));
      await engine.invokeMethod<void>('exportRetry', id);
      final retried = await terminal();
      expect(retried['state'], 'completed', reason: retried.toString());
      binding.reportData = {
        'journalWriteFailureHandled': true,
        'draftUnchanged': true,
        'retryCompleted': true,
        'jobId': id,
        'uri': retried['uri'],
        'fixturesRetained': true,
      };
      return;
    }
    if (!const bool.fromEnvironment('RECOVERY_RESUME')) {
      final longSource =
          'content://com.xrecorder.xrecorder.files/media/p2_p3_two_hour_sparse.mp4';
      final beforeJobs = await engine.invokeMethod<String>('exportList');
      final budget = EditProject(
        id: 'budget_qa_${DateTime.now().microsecondsSinceEpoch}',
        title: 'QA insufficient export space',
        updatedAt: DateTime.now(),
        clips: [
          TimelineClip(
            mediaId: longSource,
            inPoint: Duration.zero,
            outPoint: const Duration(hours: 2),
            sourceDuration: const Duration(hours: 2),
          ),
        ],
      );
      await repo.save(budget);
      await expectLater(
        engine.invokeMethod<String>('exportStart', budget.toJson()),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.message,
            'message',
            contains('storage'),
          ),
        ),
      );
      expect(await engine.invokeMethod<String>('exportList'), beforeJobs);
      expect((await repo.find(budget.id))!.toJson(), budget.toJson());
      final id = 'process_qa_${DateTime.now().microsecondsSinceEpoch}';
      final project = EditProject(
        id: id,
        title: id,
        updatedAt: DateTime.now(),
        effects: {'height': 720, 'fps': 60, 'bitrate': 1000000},
        clips: List.generate(
          30,
          (_) => TimelineClip(
            mediaId: source,
            inPoint: Duration.zero,
            outPoint: const Duration(seconds: 4),
            sourceDuration: const Duration(seconds: 4),
          ),
        ),
      );
      await repo.save(project);
      final job = await engine.invokeMethod<String>(
        'exportStart',
        project.toJson(),
      );
      binding.reportData = {
        'phase': 'start',
        'projectId': id,
        'jobId': job,
        'expectedDraft': project.toJson(),
        'sourceUri': source,
        'insufficientExportStorageRejected': true,
      };
      // Finish the driver but retain the native process/export. The host verifies
      // a real encoder temporary file before explicitly killing this QA process.
    } else {
      final jobs = (jsonDecode(
        (await engine.invokeMethod<String>('exportList'))!,
      ) as List).cast<Map<String, dynamic>>();
      final job = jobs.lastWhere(
        (j) =>
            (j['project'] as Map)['title'].toString().startsWith('process_qa_'),
      );
      expect(job['state'], 'failed');
      expect(job['error'], contains('interrupted'));
      final project = (await repo.find(
        (job['project'] as Map)['id'] as String,
      ))!;
      expect(project.toJson(), job['project']);
      final thumbnail = await media.invokeMethod<Uint8List>('thumbnailAt', {
        'uri': source,
        'timeMs': 1100,
      });
      expect(thumbnail, isNotEmpty);
      final retry = EditProject(
        id: '${project.id}_retry',
        title: 'Recovery verification',
        updatedAt: DateTime.now(),
        clips: [project.clips.first],
        effects: {'bitrate': 1000000},
      );
      final retryId = (await engine.invokeMethod<String>(
        'exportStart',
        retry.toJson(),
      ))!;
      Map<String, dynamic> result = {};
      for (var i = 0; i < 180; i++) {
        final current = (jsonDecode(
          (await engine.invokeMethod<String>('exportList'))!,
        ) as List).cast<Map<String, dynamic>>();
        result = current.firstWhere((j) => j['id'] == retryId);
        if (['completed', 'failed', 'cancelled'].contains(result['state'])) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      expect(result['state'], 'completed', reason: result.toString());
      binding.reportData = {
        'phase': 'resumed',
        'projectId': project.id,
        'interruptedJob': job['id'],
        'draftUnchanged': true,
        'sourceReadable': true,
        'newExport': result['uri'],
        'fixturesRetained': true,
      };
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
