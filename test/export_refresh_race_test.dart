import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/features/editor/export_screen.dart';
import 'package:xrecorder/features/editor/project_repository.dart';

void main() {
  testWidgets('retry refresh survives an older in-flight terminal snapshot', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final stale = Completer<String>();
    var lists = 0;
    var retries = 0;
    String document(String state) => jsonEncode([
      {
        'id': 'race',
        'state': state,
        'progress': state == 'running' ? 20 : 0,
        'project': {'title': 'Retry race fixture'},
      },
    ]);
    messenger.setMockMethodCallHandler(AndroidEditProjectRepository.channel, (
      call,
    ) async {
      if (call.method == 'exportList') {
        lists++;
        if (lists == 2) return stale.future;
        return document(lists > 2 ? 'running' : 'failed');
      }
      expect(call.method, 'exportRetry');
      expect(call.arguments, 'race');
      retries++;
      return null;
    });
    try {
      await tester.pumpWidget(MaterialApp(home: const ExportScreen()));
      await tester.pump();
      expect(find.text('Retry export'), findsOneWidget);
      final observer =
          tester.state(find.byType(ExportScreen)) as WidgetsBindingObserver;
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(lists, 2);
      await tester.tap(find.text('Retry export'));
      await tester.pump();
      expect(retries, 1);
      stale.complete(document('failed'));
      await tester.pump();
      await tester.pump();
      expect(
        lists,
        3,
        reason: 'The retry must re-read after the older snapshot.',
      );
      expect(find.text('Exporting · 20%'), findsOneWidget);
      expect(find.text('Cancel export'), findsOneWidget);
      expect(find.text('Retry export'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      if (!stale.isCompleted) stale.complete(document('failed'));
      await tester.pumpWidget(const SizedBox());
      messenger.setMockMethodCallHandler(
        AndroidEditProjectRepository.channel,
        null,
      );
    }
  });
}
