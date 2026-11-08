import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/features/editor/subtitles.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Real SAF permission, verified external copy/move, SRT save and model download',
    (tester) async {
      const channel = MethodChannel('com.xrecorder/media');
      const editor = MethodChannel('com.xrecorder/editor');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('SAF and offline model verification')),
        ),
      );
      final tree = (await channel
          .invokeMethod<String>('selectDestination')
          .timeout(const Duration(minutes: 3)))!;
      const safetyOnly = bool.fromEnvironment('SAF_COPY_SAFETY_ONLY');
      if (safetyOnly) {
        const folder = String.fromEnvironment('SAF_QA_FOLDER');
        expect(RegExp(r'^P2P3_QA_TASK07_[0-9]+$').hasMatch(folder), isTrue);
        expect(
          Uri.decodeComponent(Uri.parse(tree).path).endsWith('/$folder'),
          isTrue,
        );
      }
      const source =
          'content://com.xrecorder.xrecorder.files/media/p2_p3_exif_6.jpg';
      final original = (await channel.invokeMethod<Uint8List>('imageBytes', {
        'uri': source,
      }))!;
      final copied = (await channel.invokeMapMethod<String, dynamic>(
        'transfer',
        {'uri': source, 'destination': tree, 'move': false},
      ))!;
      expect(copied['verified'], true);
      expect(copied['moved'], false);
      expect(
        await channel.invokeMethod<Uint8List>('imageBytes', {
          'uri': copied['uri'],
        }),
        orderedEquals(original),
      );
      if (safetyOnly) {
        // Release only the freshly selected QA folder, never an existing grant.
        // A move request must fail before any publication or source deletion.
        final checkpoint = await channel.invokeMapMethod<String, dynamic>(
          'transferRecovery',
        );
        await channel.invokeMethod<void>('releaseFolder', tree);
        await expectLater(
          channel.invokeMethod<Object>('transfer', {
            'uri': source,
            'destination': tree,
            'move': true,
          }),
          throwsA(isA<PlatformException>()),
        );
        expect(
          await channel.invokeMethod<Uint8List>('imageBytes', {'uri': source}),
          orderedEquals(original),
        );
        expect(
          await channel.invokeMapMethod<String, dynamic>('transferRecovery'),
          checkpoint,
        );
        binding.reportData = {
          'destination': tree,
          'copy': copied,
          'sourceByteExact': true,
          'copyByteExactBeforeDisconnect': true,
          'revokedDestinationRejected': true,
          'transferJournalUnchangedAfterRejectedMove': true,
          'fixturesRetained': true,
          'sourceOrCopyDeleted': false,
        };
        return;
      }
      final moved = (await channel.invokeMapMethod<String, dynamic>(
        'transfer',
        {'uri': copied['uri'], 'destination': tree, 'move': true},
      ))!;
      expect(moved['moved'], true);
      expect(moved['verified'], true);
      expect(
        await channel.invokeMethod<Uint8List>('imageBytes', {
          'uri': moved['uri'],
        }),
        orderedEquals(original),
      );
      expect(
        await channel.invokeMethod<Uint8List>('imageBytes', {'uri': source}),
        orderedEquals(original),
      );
      final recovery = (await channel.invokeMapMethod<String, dynamic>(
        'transferRecovery',
      ))!;
      expect(recovery['state'], 'completed');
      final selectedAudio = await channel
          .invokeMethod<String>('selectAudio', {'initialUri': tree})
          .timeout(const Duration(minutes: 3));
      expect(selectedAudio, isNotNull);
      final audioInfo = await editor.invokeMapMethod<String, dynamic>(
        'audioInfo',
        selectedAudio,
      );
      expect(audioInfo!['durationMs'], 4000);
      final srt = SubtitleTrack([
        SubtitleCue(
          startMs: 100,
          endMs: 1500,
          text: 'Xin chào Việt Nam\nHello world',
        ),
      ], durationMs: 2000).toSrt();
      final srtUri = await channel
          .invokeMethod<String>('exportSrt', srt)
          .timeout(const Duration(minutes: 3));
      expect(srtUri, isNotNull);
      // Real network download on the device, not a synthetic transfer progress.
      final download = (await editor.invokeMethod<String>(
        'transcriptionDownloadModel',
        {'model': 'tiny'},
      ))!;
      Map<String, dynamic> result = {};
      final progress = <double>[];
      for (var i = 0; i < 240; i++) {
        result = (await editor.invokeMapMethod<String, dynamic>(
          'transcriptionPoll',
          download,
        ))!;
        progress.add((result['progress'] as num).toDouble());
        if (['completed', 'failed', 'cancelled'].contains(result['state'])) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      expect(result['state'], 'completed', reason: result.toString());
      expect(progress.any((v) => v > 0 && v < 1), true);
      final shortcut = (await channel.invokeMapMethod<String, dynamic>(
        'shortcutStatus',
      ))!;
      var pinned = false;
      if (shortcut['supported'] == true) {
        expect(await channel.invokeMethod<bool>('pinShortcut', 'video'), true);
        for (var i = 0; i < 60; i++) {
          final state = (await channel.invokeMapMethod<String, dynamic>(
            'shortcutStatus',
          ))!;
          pinned = (state['pinned'] as List).contains('pinned_edit_video');
          if (pinned) break;
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        expect(pinned, true);
      }
      await channel.invokeMethod<void>('releaseFolder', tree);
      await expectLater(
        channel.invokeMethod<Object>('transfer', {
          'uri': source,
          'destination': tree,
          'move': true,
        }),
        throwsA(isA<PlatformException>()),
      );
      expect(
        await channel.invokeMethod<Uint8List>('imageBytes', {'uri': source}),
        orderedEquals(original),
      );
      binding.reportData = {
        'destination': tree,
        'copy': copied,
        'move': moved,
        'originalPreserved': true,
        'srtUri': srtUri,
        'srtText': srt,
        'modelDownload': result,
        'downloadProgressSamples': progress,
        'fixturesRetained': true,
        'disconnectedDestinationRejected': true,
        'audioPickerReadDurationMs': audioInfo['durationMs'],
        'pinnedShortcutSupported': shortcut['supported'],
        'pinnedShortcutConfirmed': pinned,
      };
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
