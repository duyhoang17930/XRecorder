import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/core/domain/models.dart';

void main() {
  test('drawing stroke separators survive immutable draft JSON roundtrip', () {
    final points = <Object?>[
      null,
      <double>[.1, .2],
      <double>[.8, .7],
      null,
      <double>[.3, .4],
    ];
    final project = EditProject(
      id: 'drawing_snapshot',
      updatedAt: DateTime(2026),
      clips: [],
      effects: {
        'layers': [
          {'kind': 'drawing', 'startMs': 0, 'endMs': 2000, 'points': points},
        ],
      },
    );
    final restored = EditProject.fromJson(
      jsonDecode(jsonEncode(project.toJson())) as Map<String, dynamic>,
    );
    final saved =
        ((restored.effects['layers'] as List).single as Map)['points'] as List;
    expect(saved, [
      null,
      [.1, .2],
      [.8, .7],
      null,
      [.3, .4],
    ]);
    (points[1] as List<double>)[0] = .99;
    points.clear();
    final snapshot =
        ((project.effects['layers'] as List).single as Map)['points'] as List;
    expect(snapshot, saved);
    expect(() => snapshot.add(null), throwsUnsupportedError);
    expect(() => (snapshot[1] as List)[0] = .9, throwsUnsupportedError);
  });
}
