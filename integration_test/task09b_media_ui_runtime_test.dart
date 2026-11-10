import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/main.dart' as app;
import 'package:xrecorder/core/widgets/studio_shell.dart';
import 'package:xrecorder/features/media/media_actions.dart';
import 'package:xrecorder/features/media/media_repository.dart';
import 'package:xrecorder/features/media/photo_tools_screen.dart';
import 'package:xrecorder/features/media/video_details_screen.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';
import 'package:xrecorder/l10n/localization.dart';

import '../test/fixtures/interaction_probe.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real media dialogs rename trash restore and photo JPEG save-copy',
    (tester) async {
      binding.testTextInput.register();
      final semantics = tester.ensureSemantics();
      final probe = InteractionProbe(
        'real app, native storage and photo encoder; new backed-up QA fixture only',
      );
      binding.reportData = {'status': 'IN_PROGRESS'};
      final output = <String, Object?>{};
      try {
        await app.main();
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(StudioBottomNavigation));
        final settings = SettingsScope.of(context);
        settings.setAppLocale(const Locale('en'));
        await settings.flushed;
        await tester.pumpAndSettle();
        final strings = context.l10n;
        final router = GoRouter.of(context);
        final catalog = AndroidMediaRepository();
        addTearDown(catalog.dispose);
        const channel = AndroidMediaRepository.channel;
        final run = DateTime.now().microsecondsSinceEpoch.toString();
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        for (final (rect, color) in [
          (const Rect.fromLTWH(0, 0, 512, 384), Colors.red),
          (const Rect.fromLTWH(512, 0, 512, 384), Colors.green),
          (const Rect.fromLTWH(0, 384, 512, 384), Colors.blue),
          (const Rect.fromLTWH(512, 384, 512, 384), Colors.yellow),
        ]) {
          canvas.drawRect(rect, Paint()..color = color);
        }
        final picture = recorder.endRecording();
        final image = await picture.toImage(1024, 768);
        picture.dispose();
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
        image.dispose();
        final backup = File(
          '/data/user/0/com.xrecorder.xrecorder/files/task09b_media_ui_$run.png',
        );
        await backup.create(exclusive: true);
        await backup.writeAsBytes(bytes, flush: true);
        final uri = (await channel.invokeMethod<String>('saveImage', {
          'bytes': bytes,
        }))!;
        final original = (await catalog.find(uri))!;
        expect(original.owned, isTrue);
        output.addAll({'run': run, 'backup': backup.path, 'originalUri': uri});

        Future<void> frames() async {
          // The busy indicator stays alive while a media dialog awaits input.
          // Wait for its transition, not for every background animation to stop.
          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        Future<void> click(Finder target) async {
          FocusManager.instance.primaryFocus?.unfocus();
          await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
          await frames();
          if (target.evaluate().isEmpty) {
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .jumpTo(0);
            await frames();
            await tester.scrollUntilVisible(
              target,
              180,
              maxScrolls: 40,
              scrollable: find.byType(Scrollable).first,
            );
          }
          await tester.ensureVisible(target);
          await frames();
          expect(target.hitTestable(), findsOneWidget);
          await tester.tap(target);
          await frames();
        }

        Future<void> label(String text) => click(find.text(text).last);
        Finder dialogAction(String text) => find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, text),
        );
        Future<void> action(
          String id,
          String locator,
          Future<void> Function() work,
          void Function() verify,
        ) => probe.step(
          tester,
          id: id,
          route: router.routeInformationProvider.value.uri.path,
          state: id,
          locator: locator,
          expected: 'Rendered action and native state assertions in test',
          action: work,
          verify: verify,
          owner: 'P2/P3',
        );
        router.push('/media/${Uri.encodeComponent(uri)}');
        await tester.pumpAndSettle();
        await action('MEDIA-RENAME-CANCEL', strings.rename, () async {
          await label(strings.rename);
          await tester.enterText(find.byType(TextField), 'must-not-save.png');
          await click(dialogAction(strings.cancel));
          expect((await catalog.find(uri))!.displayName, original.displayName);
        }, () => expect(find.byType(VideoDetailsScreen), findsOneWidget));
        await action('MEDIA-RENAME-INVALID', strings.rename, () async {
          await label(strings.rename);
          await tester.enterText(find.byType(TextField), '../invalid.png');
          await click(dialogAction(strings.rename));
          expect((await catalog.find(uri))!.displayName, original.displayName);
        }, () => expect(find.byType(SnackBar), findsOneWidget));
        final filename = 'TASK09B_${run}_Tiếng_Việt_日本語_العربية_👩🏽‍💻.png';
        await action('MEDIA-RENAME-UNICODE', strings.rename, () async {
          await label(strings.rename);
          await tester.enterText(find.byType(TextField), filename);
          await click(dialogAction(strings.rename));
          expect((await catalog.find(uri))!.displayName, filename);
          expect(
            await channel.invokeMethod<List<int>>('imageBytes', {'uri': uri}),
            orderedEquals(bytes),
          );
        }, () => expect(find.text(filename), findsWidgets));
        Future<void> waitMediaIdle() async {
          final copy = find.widgetWithText(TextButton, strings.copyToFolder);
          for (var i = 0; i < 900; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            await tester.pump();
            if (copy.evaluate().isNotEmpty &&
                tester.widget<TextButton>(copy).onPressed != null) {
              return;
            }
          }
          fail('Real system picker/media operation did not return to idle.');
        }

        await action(
          'MEDIA-COPY-PICKER-CANCEL',
          strings.copyToFolder,
          () async {
            await label(strings.copyToFolder);
            await waitMediaIdle();
            expect(
              await channel.invokeMethod<List<int>>('imageBytes', {'uri': uri}),
              orderedEquals(bytes),
            );
          },
          () => expect(find.byType(VideoDetailsScreen), findsOneWidget),
        );
        await Future<void>.delayed(const Duration(seconds: 5));
        await action('MEDIA-COPY-REAL-GRANT', strings.copyToFolder, () async {
          await label(strings.copyToFolder);
          await waitMediaIdle();
          final journal = (await channel.invokeMapMethod<String, dynamic>(
            'transferRecovery',
          ))!;
          expect(journal['source'], uri);
          expect(journal['state'], 'completed');
          expect(journal['moved'], isFalse);
          expect(journal['sha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
          expect(
            await channel.invokeMethod<List<int>>('imageBytes', {
              'uri': journal['destination'],
            }),
            orderedEquals(bytes),
          );
          expect(
            await channel.invokeMethod<List<int>>('imageBytes', {'uri': uri}),
            orderedEquals(bytes),
          );
          output['copyJournal'] = journal;
        }, () => expect(find.byType(VideoDetailsScreen), findsOneWidget));
        await action('MEDIA-MOVE-CANCEL', strings.moveToFolder, () async {
          await label(strings.moveToFolder);
          await click(dialogAction(strings.cancel));
          expect(await catalog.find(uri), isNotNull);
        }, () => expect(find.byType(AlertDialog), findsNothing));
        await action('MEDIA-TRASH-CANCEL', strings.moveToTrash, () async {
          await label(strings.moveToTrash);
          await click(dialogAction(strings.cancel));
          expect(await catalog.find(uri), isNotNull);
        }, () => expect(find.byType(VideoDetailsScreen), findsOneWidget));
        await action('MEDIA-TRASH-CONFIRM', strings.moveToTrash, () async {
          await label(strings.moveToTrash);
          await click(dialogAction(strings.moveToTrash));
          expect(await catalog.find(uri), isNull);
        }, () => expect(find.byType(VideoDetailsScreen), findsNothing));
        final trash = AndroidMediaActions();
        final entry = (await trash.list()).singleWhere(
          (row) => row.originalMetadata.displayName == filename,
        );
        output['trashId'] = entry.id;
        router.push('/trash');
        await tester.pumpAndSettle();
        final tile = find.ancestor(
          of: find.text(filename),
          matching: find.byType(ListTile),
        );
        Finder tileButton(String tooltip) => find.descendant(
          of: tile,
          matching: find.byWidgetPredicate(
            (w) => w is IconButton && w.tooltip == tooltip,
          ),
        );
        await action(
          'TRASH-DELETE-CANCEL',
          strings.deletePermanently,
          () async {
            await click(tileButton(strings.deletePermanently));
            await click(dialogAction(strings.cancel));
            expect(
              (await trash.list()).any((row) => row.id == entry.id),
              isTrue,
            );
          },
          () => expect(find.text(filename), findsOneWidget),
        );
        await action('TRASH-RESTORE', strings.restore, () async {
          await click(tileButton(strings.restore));
          expect(
            (await trash.list()).any((row) => row.id == entry.id),
            isFalse,
          );
        }, () => expect(find.byType(VideoDetailsScreen), findsOneWidget));
        final restoredUri = tester
            .widget<VideoDetailsScreen>(find.byType(VideoDetailsScreen))
            .id;
        expect(restoredUri, isNot(uri));
        expect(
          await channel.invokeMethod<List<int>>('imageBytes', {
            'uri': restoredUri,
          }),
          orderedEquals(bytes),
        );
        output['restoredUri'] = restoredUri;
        await label(strings.cropAnnotateACopy);
        await tester.pumpAndSettle();
        await label(strings.rotate90);
        await click(find.byType(BackButton));
        await click(dialogAction(strings.keepEditing));
        expect(find.byType(PhotoToolsScreen), findsOneWidget);
        Future<void> choose(String title, Object value) async {
          final field = find.ancestor(
            of: find.text(title),
            matching: find.byWidgetPredicate(
              (w) => w is DropdownButtonFormField,
            ),
          );
          await click(field);
          await click(find.text(value as String).last);
        }

        await choose(strings.exportImageFormat, strings.jpegSmallerFile);
        await choose(
          strings.longestEdgeNoEnlargement,
          strings.pixelCount('480'),
        );
        await action('PHOTO-JPEG-SAVE-COPY', strings.saveCopy, () async {
          await label(strings.saveCopy);
          for (
            var i = 0;
            i < 150 && find.byType(VideoDetailsScreen).evaluate().isEmpty;
            i++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            await tester.pump();
          }
        }, () => expect(find.byType(VideoDetailsScreen), findsOneWidget));
        final jpegUri = tester
            .widget<VideoDetailsScreen>(find.byType(VideoDetailsScreen))
            .id;
        final jpeg = (await channel.invokeMethod<List<int>>('imageBytes', {
          'uri': jpegUri,
        }))!;
        expect(jpeg.take(3), [0xff, 0xd8, 0xff]);
        final decoded = await ui.instantiateImageCodec(
          Uint8List.fromList(jpeg),
        );
        final frame = await decoded.getNextFrame();
        expect([frame.image.width, frame.image.height], [360, 480]);
        frame.image.dispose();
        decoded.dispose();
        expect(
          await channel.invokeMethod<List<int>>('imageBytes', {
            'uri': restoredUri,
          }),
          orderedEquals(bytes),
        );
        expect(await backup.readAsBytes(), orderedEquals(bytes));
        output.addAll({
          'jpegUri': jpegUri,
          'jpegBytes': jpeg.length,
          'dimensions': [360, 480],
          'sourceBytesExact': true,
        });
        binding.reportData = {
          'status': 'PASS',
          'mediaUI': output,
          'interactions': probe.toJson(),
          'captureInvoked': false,
          'permanentDeleteInvoked': false,
        };
      } finally {
        binding.reportData = {
          ...binding.reportData ?? {},
          'mediaUI': output,
          'interactions': probe.toJson(),
        };
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        semantics.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
