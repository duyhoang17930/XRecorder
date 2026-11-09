import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> revealCaptureOutput(
  WidgetTester tester,
  String displayName,
) async {
  final name = find.text(displayName);
  await tester.scrollUntilVisible(
    name,
    300,
    scrollable: find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first,
    maxScrolls: 40,
    duration: const Duration(milliseconds: 200),
  );
  expect(name.hitTestable(), findsOneWidget);
}
