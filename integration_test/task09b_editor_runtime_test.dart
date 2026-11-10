import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/editor/layers_editor.dart';
import 'package:xrecorder/features/editor/project_repository.dart';

import '../test/fixtures/interaction_probe.dart';
import '../test/task09b_editor_interactions_test.dart' as editor_ui;
import 'task09b_interactions_test.dart' as shared;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final probe = InteractionProbe(
    'native Flutter interaction / actual Android app; test metrics 411x920',
  );
  final outputs = <String, Object?>{};
  if (!const bool.fromEnvironment('TASK09B_OUTPUT_ONLY')) {
    shared.main(); // TASK09B_SKIP_VERIFIED_MEDIA avoids repeating verified G2.
    editor_ui.registerEditorInteractionTests(evidence: probe);
  }
  tearDownAll(
    () => binding.reportData = {
      ...binding.reportData ?? {},
      'editorInteractions': probe.toJson(),
      'nativeOutputs': outputs,
    },
  );

  testWidgets('drawing gesture and preset committed through real MP4 export', (
    tester,
  ) async {
    List<Map<String, Object>>? layers;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  layers = await editLayers(context, [], 2000),
              child: const Text('Open native drawing'),
            ),
          ),
        ),
      ),
    );
    Future<void> tap(String label) async {
      final target = find.text(label).last;
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await tap('Open native drawing');
    await tap('Add Drawing');
    final pad = find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          w.properties.label?.startsWith('Drawing pad') == true,
    );
    await tester.ensureVisible(pad);
    await tester.pumpAndSettle();
    await tester.drag(pad, const Offset(55, 25));
    await tester.pumpAndSettle();
    await tap('Add straight line');
    await tap('Use layer');
    await tap('Use layers');
    expect(layers!.single['points'], isNotEmpty);
    expect(tester.takeException(), isNull);
    const image = String.fromEnvironment('TASK09B_IMAGE_URI');
    expect(image, startsWith('content://media/'));
    final project = EditProject(
      id: 'task09b_drawing_${DateTime.now().microsecondsSinceEpoch}',
      title: 'TASK09B actual drawing gesture',
      updatedAt: DateTime.now(),
      clips: [
        TimelineClip(
          mediaId: image,
          isImage: true,
          inPoint: Duration.zero,
          outPoint: const Duration(seconds: 2),
          sourceDuration: const Duration(seconds: 2),
        ),
      ],
      effects: {'layers': layers!, 'height': 480},
    );
    await AndroidEditProjectRepository().save(project);
    const engine = AndroidEditProjectRepository.channel;
    final jobId = (await engine.invokeMethod<String>(
      'exportStart',
      project.toJson(),
    ))!;
    Map<String, dynamic> job = {};
    for (var i = 0; i < 180; i++) {
      final rows = (jsonDecode(
        (await engine.invokeMethod<String>('exportList'))!,
      ) as List).cast<Map<String, dynamic>>();
      job = rows.singleWhere((v) => v['id'] == jobId);
      if (['completed', 'failed', 'cancelled'].contains(job['state'])) break;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    expect(job['state'], 'completed', reason: job.toString());
    final path =
        '/data/user/0/com.xrecorder.xrecorder/files/task09b_drawing_${DateTime.now().microsecondsSinceEpoch}.json';
    final file = File(path);
    await file.create(exclusive: true);
    await file.writeAsString(
      jsonEncode({'project': project.toJson(), 'job': job}),
      flush: true,
    );
    outputs['drawing'] = {
      'project': project.toJson(),
      'job': job,
      'deviceEvidence': path,
    };
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets(
    'new disposable model store download cancellation checksum import remove',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('TASK09B real model management')),
        ),
      );
      const engine = AndroidEditProjectRepository.channel;
      Future<List<Map>> models() async =>
          (await engine.invokeListMethod<dynamic>('transcriptionModels'))!
              .cast<Map>();
      Future<Map<String, dynamic>> poll(String id) async => (await engine
          .invokeMapMethod<String, dynamic>('transcriptionPoll', id))!;
      Future<Map<String, dynamic>> terminal(
        String id, {
        int seconds = 240,
      }) async {
        var state = await poll(id);
        for (
          var i = 0;
          i < seconds * 4 && ['queued', 'running'].contains(state['state']);
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          state = await poll(id);
        }
        return state;
      }

      final installed = await models();
      if (installed.any((v) => v['id'] == 'tiny' && v['installed'] == true)) {
        final jobs = (await engine.invokeListMethod<dynamic>(
          'transcriptionJobs',
        ))!.cast<Map>();
        expect(
          jobs.where((v) => v['type'] == 'model' && v['state'] == 'completed'),
          isNotEmpty,
        );
        expect(
          jobs.where((v) => v['type'] == 'model' && v['state'] == 'cancelled'),
          isNotEmpty,
        );
        expect(
          jobs.where((v) => v['type'] == 'model' && v['state'] == 'failed'),
          isNotEmpty,
        );
        outputs['modelsReadback'] = {
          'status': 'PASS',
          'installed': installed,
          'jobs': jobs,
          'scope': 'Readback of previous real operations; no download/import/delete replay',
        };
        if (const bool.fromEnvironment('TASK09B_TEST_MODEL_REMOVE')) {
          final original = File(
            '/data/user/0/com.xrecorder.xrecorder/files/trash/task09b_ggml-tiny.bin',
          );
          expect(await original.length(), 77691713);
          await engine.invokeMethod<void>('transcriptionDeleteModel', 'tiny');
          expect(
            (await models()).singleWhere((v) => v['id'] == 'tiny')['installed'],
            isFalse,
          );
          final replacement = (await engine.invokeMethod<String>(
            'transcriptionImportModel',
            {
              'model': 'tiny',
              'uri': 'content://com.xrecorder.xrecorder.files/trash/task09b_ggml-tiny.bin',
            },
          ))!;
          await expectLater(
            engine.invokeMethod<void>('transcriptionDeleteModel', 'tiny'),
            throwsA(isA<PlatformException>()),
          );
          final restored = await terminal(replacement, seconds: 90);
          expect(restored['state'], 'completed', reason: restored.toString());
          expect(
            (await models()).singleWhere((v) => v['id'] == 'tiny')['installed'],
            isTrue,
          );
          outputs['modelRemove'] = {
            'removedAndReportedUnavailable': true,
            'activeModelDeleteRejected': true,
            'reimport': restored,
            'scope': 'Only tiny created by TASK09B; immutable import fixture and pre-install archive retained.',
          };
        }
        return;
      }
      final cancellation = (await engine.invokeMethod<String>(
        'transcriptionDownloadModel',
        {'model': 'tiny'},
      ))!;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await engine.invokeMethod<void>('transcriptionCancel', cancellation);
      final cancelled = await terminal(cancellation, seconds: 25);
      expect(cancelled['state'], 'cancelled');
      final download = (await engine.invokeMethod<String>(
        'transcriptionDownloadModel',
        {'model': 'tiny'},
      ))!;
      var downloaded = await terminal(download);
      if (['queued', 'running'].contains(downloaded['state'])) {
        await engine.invokeMethod<void>('transcriptionCancel', download);
        downloaded = await terminal(download, seconds: 25);
      }
      // Preserve actual network failures as external evidence, never synthesize
      // a downloaded model or a transcript. Local import is independently tested.
      outputs['models'] = {
        'cancel': cancelled,
        'download': downloaded,
        'downloadStatus': downloaded['state'] == 'completed'
            ? 'PASS'
            : 'PARTIAL / actual network failure or timeout',
      };
      if (downloaded['state'] == 'completed') {
        await engine.invokeMethod<void>('transcriptionDeleteModel', 'tiny');
      }
      const source =
          'content://com.xrecorder.xrecorder.files/trash/task09b_ggml-tiny.bin';
      final imported = (await engine.invokeMethod<String>(
        'transcriptionImportModel',
        {'model': 'tiny', 'uri': source},
      ))!;
      final importedState = await terminal(imported, seconds: 90);
      expect(
        importedState['state'],
        'completed',
        reason: importedState.toString(),
      );
      expect(
        (await models()).singleWhere((v) => v['id'] == 'tiny')['installed'],
        isTrue,
      );
      final rejected = (await engine.invokeMethod<String>(
        'transcriptionImportModel',
        {
          'model': 'tiny',
          'uri': 'content://com.xrecorder.xrecorder.files/trash/task09b_wrong-model.bin',
        },
      ))!;
      final wrong = await terminal(rejected, seconds: 20);
      expect(wrong['state'], 'failed');
      expect(
        (await models()).singleWhere((v) => v['id'] == 'tiny')['installed'],
        isTrue,
      );
      outputs['models'] = <String, Object?>{
        ...Map<String, Object?>.from(outputs['models'] as Map),
        'import': importedState,
        'wrongChecksum': wrong,
        'installedAfterRejectedImport': await models(),
        'existingModelsPreserved': true,
      };
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
