import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/main.dart' as app;
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/persistence/settings_store.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/media/media_actions.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/settings/help_screen.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';

import '../test/fixtures/interaction_probe.dart';

// Only the isolated TASK09B AVD is authorized. All native commands below use
// production bridges, real preferences, MediaStore and DocumentsUI. A host
// companion selects/cancels the OS picker; no shell permission grants.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => binding.testTextInput.register());
  final probe = InteractionProbe('native integration / real Android bridges');
  final results = <String, Object?>{};
  tearDown(
    () => binding.reportData = {...results, 'interactions': probe.toJson()},
  );

  Future<void> tap(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        target,
        180,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 40,
      );
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    expect(target.hitTestable(), findsOneWidget);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'G1 real Settings navigation dialogs persistence and empty support',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await app.main();
        await tester.pumpAndSettle();
        final router = GoRouter.of(tester.element(find.text('Video Library')));
        for (final tab in [
          ('Photo', 'Photo Library'),
          ('Edit', 'Editing Studio'),
          ('Settings', 'Settings'),
        ]) {
          await probe.step(
            tester,
            id: 'G1-NATIVE-TAB-${tab.$1}',
            route: 'shell',
            state: 'empty libraries',
            locator: 'text:${tab.$1}',
            expected: 'Destination ${tab.$2} renders',
            action: () => tap(tester, find.text(tab.$1)),
            verify: () => expect(find.text(tab.$2), findsWidgets),
          );
        }
        final settings = SettingsScope.of(
          tester.element(find.text('Settings').first),
        );
        for (final mode in [
          ('Light', ThemeMode.light),
          ('System', ThemeMode.system),
          ('Dark', ThemeMode.dark),
        ]) {
          await probe.step(
            tester,
            id: 'G1-NATIVE-THEME-${mode.$1}',
            route: '/settings',
            state: mode.$1,
            locator: mode.$1,
            expected: 'Native preferences durably save selected theme',
            action: () async {
              await tap(tester, find.text(mode.$1));
              await settings.flushed;
            },
            verify: () => expect(settings.themeMode, mode.$2),
          );
          final restored = SettingsController(
            store: const AndroidSettingsStore(),
          );
          await restored.restore();
          expect(restored.themeMode, mode.$2);
          restored.dispose();
        }
        final document = await const AndroidSettingsStore().read();
        for (final row in [
          ('Media storage', 'Close'),
          ('Privacy', 'Close'),
          ('Trash & restore', 'Trash'),
          ('Export queue', 'Exports'),
          ('Help & guides', 'Help & guides'),
          ('Feedback', 'Feedback & issue report'),
        ]) {
          await probe.step(
            tester,
            id: 'G1-NATIVE-ROW-${row.$1}',
            route: '/settings',
            state: 'landing',
            locator: row.$1,
            expected: 'Opens ${row.$2} without preferences changes',
            action: () => tap(tester, find.text(row.$1)),
            verify: () => expect(find.text(row.$2), findsWidgets),
          );
          if (row.$2 == 'Close') {
            await tap(tester, find.text('Close'));
          } else {
            router.pop();
            await tester.pumpAndSettle();
          }
          expect(await const AndroidSettingsStore().read(), document);
        }
        await tap(tester, find.text('About & licenses'));
        expect(find.byType(AboutDialog, skipOffstage: false), findsOneWidget);
        await tap(tester, find.text('View licenses'));
        expect(find.byType(LicensePage), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tap(tester, find.text('Close'));
        expect(find.byType(AboutDialog, skipOffstage: false), findsNothing);
        await tap(tester, find.text('Help & guides'));
        expect(find.byType(HelpScreen, skipOffstage: false), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Trash');
        FocusManager.instance.primaryFocus?.unfocus();
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        await tap(tester, find.text('How does Trash work?'));
        expect(find.textContaining('Only app-owned media'), findsOneWidget);
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'QA_NO_MATCH_09B');
        await tester.pumpAndSettle();
        expect(find.text('No matching guides'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        await tap(tester, find.text('Feedback'));
        await tap(tester, find.text('Open share sheet'));
        expect(find.text('Write a report before sharing.'), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        results['g1'] = {
          'nativePreferencesUnchangedByReading':
              await const AndroidSettingsStore().read() == document,
          'captureInvoked': false,
          'supportDelivered': false,
          'status': 'PASS',
        };
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        semantics.dispose();
      }
    },
  );

  if (const bool.fromEnvironment('TASK09B_SKIP_VERIFIED_MEDIA')) return;

  testWidgets(
    'G2 owned PNG video trash restore SAF copy move revoke preserve bytes',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('TASK09B disposable media safety')),
        ),
      );
      const media = AndroidMediaRepository.channel;
      const engine = AndroidEditProjectRepository.channel;
      final catalog = AndroidMediaRepository();
      addTearDown(catalog.dispose);
      final actions = AndroidMediaActions();
      final run = DateTime.now().microsecondsSinceEpoch.toString();
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 96, 64),
        Paint()..color = Colors.teal,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(96, 64);
      picture.dispose();
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      image.dispose();
      final backup = File(
        '/data/user/0/com.xrecorder.xrecorder/files/task09b_$run.png',
      );
      await backup.create(exclusive: true);
      await backup.writeAsBytes(bytes, flush: true);
      Future<String> save(String suffix) async {
        final uri = (await media.invokeMethod<String>('saveImage', {
          'bytes': bytes,
        }))!;
        await actions.rename(Uri.parse(uri), 'TASK09B_${run}_$suffix.png');
        return uri;
      }

      final photo = await save('trash');
      final moveSource = await save('move');
      final project = EditProject(
        id: 'task09b_$run',
        title: 'TASK09B owned video fixture',
        updatedAt: DateTime.now(),
        clips: [
          TimelineClip(
            mediaId: photo,
            inPoint: Duration.zero,
            outPoint: const Duration(seconds: 2),
            sourceDuration: const Duration(seconds: 2),
            isImage: true,
          ),
        ],
        effects: {'outputWidth': 320, 'outputHeight': 240},
      );
      await AndroidEditProjectRepository().save(project);
      final jobId = (await engine.invokeMethod<String>(
        'exportStart',
        project.toJson(),
      ))!;
      Map<String, dynamic> job = {};
      for (var i = 0; i < 180; i++) {
        final jobs = (jsonDecode(
          (await engine.invokeMethod<String>('exportList'))!,
        ) as List).cast<Map<String, dynamic>>();
        job = jobs.singleWhere((j) => j['id'] == jobId);
        if (['completed', 'failed', 'cancelled'].contains(job['state'])) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      expect(job['state'], 'completed', reason: job.toString());
      final video = job['uri'] as String;
      debugPrint('TASK09B_PICKER_CANCEL');
      expect(await media.invokeMethod<String>('selectDestination'), isNull);
      expect(await catalog.find(photo), isNotNull);
      // Let the host assert the picker returned before another picker opens.
      await Future<void>.delayed(const Duration(seconds: 5));
      debugPrint('TASK09B_PICKER_GRANT');
      final destination = (await media.invokeMethod<String>(
        'selectDestination',
      ))!;
      Future<Map<Object?, Object?>> transfer(String source, bool move) async {
        final result = (await media.invokeMapMethod<Object?, Object?>(
          'transfer',
          {'uri': source, 'destination': destination, 'move': move},
        ))!;
        final journal = (await media.invokeMapMethod<Object?, Object?>(
          'transferRecovery',
        ))!;
        expect(result['verified'], isTrue);
        expect(journal['sha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(journal['source'], source);
        return {...result, 'sha256': journal['sha256']};
      }

      final restoredRows = <Map<String, Object?>>[];
      for (final source in [photo, video]) {
        final item = (await catalog.find(source))!;
        expect(item.owned, isTrue);
        final before = await transfer(source, false);
        final entry = await actions.trash(item);
        expect(await catalog.find(source), isNull);
        expect((await actions.list()).any((row) => row.id == entry.id), isTrue);
        final restored = await actions.restore(entry.id);
        expect(restored.uri.toString(), isNot(source));
        final after = await transfer(restored.uri.toString(), false);
        expect(after['sha256'], before['sha256']);
        expect(after['bytes'], before['bytes']);
        if (source == photo) {
          expect(
            await media.invokeMethod<Uint8List>('imageBytes', {
              'uri': restored.uri.toString(),
            }),
            orderedEquals(bytes),
          );
        }
        expect(
          (await actions.list()).any((row) => row.id == entry.id),
          isFalse,
        );
        restoredRows.add({
          'source': source,
          'restored': restored.uri.toString(),
          'before': before,
          'after': after,
          'trashId': entry.id,
        });
      }
      final moved = await transfer(moveSource, true);
      expect(moved['moved'], isTrue);
      expect(await catalog.find(moveSource), isNull);
      expect(
        await media.invokeMethod<Uint8List>('imageBytes', {
          'uri': moved['uri'],
        }),
        orderedEquals(bytes),
      );
      await media.invokeMethod<void>('releaseFolder', destination);
      final kept = restoredRows.first['restored'] as String;
      await expectLater(
        transfer(kept, false),
        throwsA(isA<PlatformException>()),
      );
      expect(await catalog.find(kept), isNotNull);
      expect(await backup.readAsBytes(), orderedEquals(bytes));
      results['g2'] = {
        'backup': backup.path,
        'destination': destination,
        'restored': restoredRows,
        'moved': moved,
        'sourceAfterRevokedTransferPreserved': kept,
        'job': job,
        'project': project.id,
        'fixturesRetained': true,
        'status': 'PASS',
      };
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
