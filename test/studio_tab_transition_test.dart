import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/core/widgets/studio_tab_transition.dart';

void main() {
  for (final reduceMotion in [false, true]) {
    testWidgets(
      'tab slide preserves scroll state, reduced motion=$reduceMotion',
      (tester) async {
        final selected = ValueNotifier(0);
        final scrolls = [ScrollController(), ScrollController()];
        final pages = [
          for (var i = 0; i < 2; i++)
            ListView.builder(
              key: ValueKey('page-$i'),
              controller: scrolls[i],
              itemExtent: 50,
              itemCount: 50,
              itemBuilder: (_, row) => Text('Tab $i row $row'),
            ),
        ];
        try {
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(disableAnimations: reduceMotion),
                child: ValueListenableBuilder<int>(
                  valueListenable: selected,
                  builder: (_, index, _) =>
                      StudioTabTransition(index: index, children: pages),
                ),
              ),
            ),
          );
          scrolls[0].jumpTo(300);
          await tester.pump();
          selected.value = 1;
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          if (!reduceMotion) {
            expect(
              tester.getTopLeft(find.byKey(const ValueKey('page-0'))).dx,
              lessThan(0),
            );
            expect(
              tester.getTopLeft(find.byKey(const ValueKey('page-1'))).dx,
              greaterThan(0),
            );
          }
          await tester.pumpAndSettle();
          expect(scrolls[0].hasClients, isTrue);
          expect(scrolls[0].offset, 300);
          selected.value = 0;
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          if (!reduceMotion) {
            expect(
              tester.getTopLeft(find.byKey(const ValueKey('page-0'))).dx,
              lessThan(0),
            );
          }
          await tester.pumpAndSettle();
          expect(scrolls[0].offset, 300);
          expect(tester.getTopLeft(find.byKey(const ValueKey('page-0'))).dx, 0);
          // Rapid reversal must keep the same scroll controller and mounted page.
          selected.value = 1;
          await tester.pump(const Duration(milliseconds: 30));
          selected.value = 0;
          await tester.pumpAndSettle();
          expect(scrolls[0].offset, 300);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          selected.dispose();
          for (final controller in scrolls) {
            controller.dispose();
          }
        }
      },
    );
  }
}
