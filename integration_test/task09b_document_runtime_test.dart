import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/main.dart' as app;
import 'package:xrecorder/core/widgets/studio_shell.dart';
import 'package:xrecorder/features/editor/subtitle_editor.dart';
import 'package:xrecorder/features/editor/subtitles.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';
import 'package:xrecorder/l10n/localization.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('manual Unicode subtitle real document Cancel then verified Save', (
    tester,
  ) async {
    binding.testTextInput.register();
    binding.reportData = {'status': 'IN_PROGRESS'};
    await app.main();
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(StudioBottomNavigation));
    final settings = SettingsScope.of(context);
    settings.setAppLocale(const Locale('en'));
    await settings.flushed;
    await tester.pumpAndSettle();
    final strings = context.l10n;
    final run = DateTime.now().microsecondsSinceEpoch.toString();
    const text = 'Tiếng Việt có dấu — 日本語 한국어 中文 العربية 👩🏽‍💻\nSecond line';
    final track = SubtitleTrack([
      SubtitleCue(startMs: 125, endMs: 3125, text: text),
    ], durationMs: 4000);
    final expected = track.toSrt();
    final backup = File(
      '/data/user/0/com.xrecorder.xrecorder/files/task09b_srt_${run}_expected.srt',
    );
    await backup.create(exclusive: true);
    await backup.writeAsBytes(utf8.encode(expected), flush: true);
    final dialog = editSubtitles(context, SubtitleTrack([], durationMs: 4000));
    await tester.pumpAndSettle();
    Future<void> field(String label, String value) async {
      final target = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      await tester.ensureVisible(target);
      await tester.enterText(target, value);
      await tester.pumpAndSettle();
    }

    Future<void> click(String label) async {
      final target = find.text(label).last;
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await field(strings.subtitleText, text);
    await field(strings.startSeconds, '0.125');
    await field(strings.endSeconds, '3.125');
    await click(strings.addSubtitle);
    expect(find.text(text), findsOneWidget);
    for (final phase in ['cancel', 'save']) {
      final request = File(
        '/data/user/0/com.xrecorder.xrecorder/files/task09b_srt_${run}_$phase.request.json',
      );
      await request.create(exclusive: true);
      await request.writeAsString(
        jsonEncode({'run': run, 'phase': phase, 'expectedFile': backup.path}),
        flush: true,
      );
      await click(strings.saveSrtFile);
      final ack = File('${request.path}.ack');
      var verifiedNoticeSeen = false;
      for (var i = 0; i < 600 && !await ack.exists(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        verifiedNoticeSeen |= find
            .text(strings.subtitleSaved)
            .evaluate()
            .isNotEmpty;
      }
      expect(await ack.exists(), isTrue, reason: 'Real DocumentsUI $phase');
      if (phase == 'cancel') {
        await tester.pumpAndSettle();
        expect(find.text(strings.subtitleSaved), findsNothing);
        expect(find.byType(AlertDialog), findsOneWidget);
      } else {
        for (var i = 0; i < 100 && !verifiedNoticeSeen; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
          verifiedNoticeSeen |= find
              .text(strings.subtitleSaved)
              .evaluate()
              .isNotEmpty;
        }
        // This notice is emitted only after native read-back bytes match UTF-8.
        expect(verifiedNoticeSeen, isTrue);
      }
    }
    await click(strings.applySubtitles);
    expect((await dialog)!.toSrt(), expected);
    expect(await backup.readAsBytes(), orderedEquals(utf8.encode(expected)));
    binding.reportData = {
      'status': 'PASS',
      'run': run,
      'expectedFile': backup.path,
      'srt': expected,
      'cancelNoSavedNotice': true,
      'realDocumentSaveReadbackVerified': true,
      'manualDialogAppliedExact': true,
      'inputModality': 'Flutter test IME; actual Android DocumentsUI picker',
      'captureInvoked': false,
    };
  }, timeout: const Timeout(Duration(minutes: 5)));
}
