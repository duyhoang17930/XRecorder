import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/features/settings/support_screen.dart';
import 'package:xrecorder/features/settings/help_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.xrecorder/support');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  testWidgets('Diagnostics require consent and handoff never claims delivery', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'diagnostics' ? 'Android API: 36' : null;
        });
    await tester.pumpWidget(const MaterialApp(home: SupportScreen()));
    await tester.enterText(
      find.byType(TextField),
      'Recording stopped unexpectedly',
    );
    await tester.ensureVisible(find.text('Open share sheet'));
    await tester.tap(find.text('Open share sheet'));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'diagnostics'), isEmpty);
    expect(
      (calls.last.arguments as Map)['text'],
      'Recording stopped unexpectedly',
    );
    expect(find.textContaining('Delivery depends'), findsOneWidget);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(find.text('Android API: 36'), findsOneWidget);
    await tester.ensureVisible(find.text('Open share sheet'));
    await tester.tap(find.text('Open share sheet'));
    await tester.pumpAndSettle();
    expect((calls.last.arguments as Map)['text'], contains('Android API: 36'));
  });
  testWidgets('Help search filters structured guides', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpScreen()));
    await tester.enterText(find.byType(TextField), 'Trash');
    await tester.pumpAndSettle();
    expect(find.text('How does Trash work?'), findsOneWidget);
    expect(find.text('How do I record my screen?'), findsNothing);
  });
  testWidgets(
    'empty support report explains the required input without sharing',
    (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      await tester.pumpWidget(const MaterialApp(home: SupportScreen()));
      await tester.ensureVisible(find.text('Open share sheet'));
      await tester.tap(find.text('Open share sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Write a report before sharing.'), findsOneWidget);
      expect(calls, isEmpty);
    },
  );
  testWidgets(
    'support actions reject duplicate commands before the next frame',
    (tester) async {
      final pending = Completer<void>();
      var shares = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'share') {
              shares++;
              await pending.future;
            }
            return null;
          });
      await tester.pumpWidget(const MaterialApp(home: SupportScreen()));
      await tester.enterText(
        find.byType(TextField),
        'QA report, mocked delivery',
      );
      await tester.ensureVisible(find.text('Open share sheet'));
      final share = tester.widget<FilledButton>(find.byType(FilledButton));
      share.onPressed!();
      share.onPressed!();
      await tester.pump();
      try {
        expect(shares, 1);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
      } finally {
        pending.complete();
        await tester.pumpAndSettle();
      }
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    },
  );
}
