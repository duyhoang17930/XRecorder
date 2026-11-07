import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/features/editor/export_screen.dart';
import 'package:xrecorder/features/editor/project_repository.dart';

void main() {
  testWidgets(
    'published output keeps Saved and a storage warning without a duplicate retry',
    (tester) async {
      const warning =
          'File saved. Export history could not be updated. Free storage before exporting again.';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            AndroidEditProjectRepository.channel,
            (call) async => jsonEncode([
              {
                'id': 'published',
                'state': 'completed',
                'progress': 100,
                'uri': 'content://fixture/saved',
                'project': {'title': 'Fixture'},
                'warning': warning,
              },
            ]),
          );
      await tester.pumpWidget(const MaterialApp(home: ExportScreen()));
      await tester.pumpAndSettle();
      expect(find.text(warning), findsOneWidget);
      expect(find.text('Saved · 100%'), findsOneWidget);
      expect(find.text('Retry export'), findsNothing);
    },
  );
  testWidgets('Retry holds one native command until it settles', (
    tester,
  ) async {
    final pending = Completer<void>();
    var retries = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidEditProjectRepository.channel, (
          call,
        ) async {
          if (call.method == 'exportList') {
            return jsonEncode([
              {
                'id': 'job',
                'state': 'failed',
                'progress': 0,
                'project': {'title': 'Fixture'},
              },
            ]);
          }
          if (call.method == 'exportRetry') {
            retries++;
            await pending.future;
          }
          return null;
        });
    await tester.pumpWidget(const MaterialApp(home: ExportScreen()));
    await tester.pumpAndSettle();
    final retry = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Retry export'),
    );
    retry.onPressed!();
    retry.onPressed!();
    await tester.pump();
    expect(retries, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
