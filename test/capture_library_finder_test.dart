import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/capture_library_finder.dart';

void main() {
  testWidgets(
    'reveals the exact saved output below a header in a lazy sliver',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 1400)),
                SliverList.builder(
                  itemCount: 80,
                  itemBuilder: (_, i) =>
                      SizedBox(height: 80, child: Text('Recording_$i.mp4')),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Recording_67.mp4'), findsNothing);
      await revealCaptureOutput(tester, 'Recording_67.mp4');
      expect(find.text('Recording_67.mp4').hitTestable(), findsOneWidget);
      expect(find.text('Recording_0.mp4').hitTestable(), findsNothing);
    },
  );

  testWidgets('a missing output fails after bounded scrolling', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomScrollView(
          slivers: [SliverToBoxAdapter(child: Text('Other output'))],
        ),
      ),
    );
    await expectLater(
      () => revealCaptureOutput(tester, 'missing.mp4'),
      throwsStateError,
    );
  });
}
