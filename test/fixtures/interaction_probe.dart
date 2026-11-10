import 'dart:convert';

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// QA observations of rendered controls and asserted actions. Source callsites
/// are deliberately not the denominator of this runtime control-state register.
class InteractionProbe {
  InteractionProbe(this.modality);
  final String modality;
  final controls = <Map<String, Object?>>[];
  final actions = <Map<String, Object?>>[];
  final _seen = <String>{};

  void observe(WidgetTester tester, String route, String state) {
    final root = tester
        .binding
        .renderViews
        .first
        .owner
        ?.semanticsOwner
        ?.rootSemanticsNode;
    if (root == null) return;
    void visit(SemanticsNode node) {
      final data = node.getSemanticsData();
      final events = <String>[
        for (final action in [
          SemanticsAction.tap,
          SemanticsAction.longPress,
          SemanticsAction.increase,
          SemanticsAction.decrease,
          SemanticsAction.setText,
          SemanticsAction.scrollUp,
          SemanticsAction.scrollDown,
        ])
          if (data.hasAction(action)) action.name,
      ];
      if (events.isNotEmpty) {
        final identity =
            '$route|$state|${node.id}|${data.label}|${events.join(',')}';
        if (_seen.add(identity)) {
          controls.add({
            'id': identity,
            'semanticsNodeId': node.id,
            'route': route,
            'state': state,
            'label': data.label,
            'value': data.value,
            'hint': data.hint,
            'actions': events,
            'rect': {
              'left': node.rect.left,
              'top': node.rect.top,
              'width': node.rect.width,
              'height': node.rect.height,
            },
            'modality': modality,
            'status': 'OBSERVED / NOT EXERCISED',
          });
        }
      }
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(root);
  }

  Future<void> step(
    WidgetTester tester, {
    required String id,
    required String route,
    required String state,
    required String locator,
    required String expected,
    required Future<void> Function() action,
    required void Function() verify,
    String owner = 'Shared/P2',
  }) async {
    observe(tester, route, state);
    var status = 'FAIL';
    try {
      await action();
      verify();
      status = 'PASS';
    } finally {
      actions.add({
        'id': id,
        'route': route,
        'state': state,
        'locator': locator,
        'expected': expected,
        'actual': status == 'PASS'
            ? 'Assertions passed'
            : 'See failing test log',
        'owner': owner,
        'modality': modality,
        'status': status,
      });
      observe(tester, route, '$state/result/$id');
    }
  }

  Map<String, Object?> toJson() => {
    'modality': modality,
    'observedControlStates': controls,
    'assertedActions': actions,
    'definition':
        'Rendered semantic node-state instances within this run; node IDs keep '
        'distinct controls even with empty or duplicate labels. IDs are local '
        'to the run, not stable cross-run locators. Unlabeled gestures and '
        'human controls need separate records. No source ratio.',
  };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
}
