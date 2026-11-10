import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';
import 'package:xrecorder/features/settings/settings_hub_screen.dart';

void main() {
  testWidgets('app language has a distinct accessibility target from theme', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final settings = SettingsController();
    try {
      await tester.pumpWidget(
        SettingsScope(
          controller: settings,
          child: const MaterialApp(home: Scaffold(body: SettingsHubScreen())),
        ),
      );
      await tester.pumpAndSettle();
      final node = tester.getSemantics(find.text('App language'));
      expect(node.getSemanticsData().label, 'App language\nFollow system');
      expect(node.rect.height, lessThan(120));
    } finally {
      await tester.pumpWidget(const SizedBox());
      settings.dispose();
      semantics.dispose();
    }
  });
}
