import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/features/editor/export_screen.dart';
import 'package:xrecorder/features/editor/project_repository.dart';

void main() {
  for (final count in [0, 20, 21, 77, 100, 1001]) {
    testWidgets(
      '$count export rows remain reachable and retry targets oldest identity once',
      (tester) async {
        final rows = [
          for (var i = 0; i < count; i++)
            <String, Object>{
              'id': 'task09b_export_$i',
              'state': 'cancelled',
              'progress': 0,
              'project': {'title': 'QA cancelled $i', 'clips': <Object>[]},
            },
        ];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        var retries = 0;
        messenger.setMockMethodCallHandler(
          AndroidEditProjectRepository.channel,
          (call) async {
            if (call.method == 'exportList') return jsonEncode(rows);
            expect(call.method, 'exportRetry');
            expect(call.arguments, 'task09b_export_0');
            retries++;
            rows[0]['state'] = 'running';
            rows[0]['progress'] = 20;
            return null;
          },
        );
        try {
          await tester.pumpWidget(const MaterialApp(home: ExportScreen()));
          await tester.pumpAndSettle();
          if (count == 0) {
            expect(find.text('No exports yet'), findsOneWidget);
            expect(find.text('Retry export'), findsNothing);
          } else {
            expect(find.text('QA cancelled ${count - 1}'), findsOneWidget);
            final scroll = tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position;
            for (var i = 0; i < 5; i++) {
              scroll.jumpTo(scroll.maxScrollExtent);
              await tester.pumpAndSettle();
            }
            expect(find.text('QA cancelled 0'), findsOneWidget);
            final card = find.ancestor(
              of: find.text('QA cancelled 0'),
              matching: find.byType(Card),
            );
            final retry = find.descendant(
              of: card,
              matching: find.widgetWithText(TextButton, 'Retry export'),
            );
            await tester.ensureVisible(retry);
            final button = tester.widget<TextButton>(retry);
            button.onPressed!();
            button.onPressed!();
            await tester.pumpAndSettle();
            expect(retries, 1);
            expect(find.text('Exporting · 20%'), findsOneWidget);
            expect(
              find.descendant(of: card, matching: find.text('Cancel export')),
              findsOneWidget,
            );
          }
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          messenger.setMockMethodCallHandler(
            AndroidEditProjectRepository.channel,
            null,
          );
        }
      },
    );
  }
}
