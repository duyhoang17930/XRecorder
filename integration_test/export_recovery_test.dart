import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xrecorder/features/editor/project_repository.dart';

// The host injects an interrupted journal through adb run-as before opening the queue.
// See tool/seed_export_recovery.py. No production test-only channel is introduced.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Interrupted export journal becomes retryable failure', (
    tester,
  ) async {
    final drafts = AndroidEditProjectRepository();
    debugPrint('WAITING_FOR_EXPORT_RECOVERY_FIXTURE');
    var ready = false;
    for (var i = 0; i < 120; i++) {
      if (await drafts.find('recovery_ready') != null) {
        ready = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    expect(
      ready,
      isTrue,
      reason: 'Run tool/seed_export_recovery.py while this test waits',
    );
    final jobs = (jsonDecode(
      (await AndroidEditProjectRepository.channel.invokeMethod<String>(
        'exportList',
      ))!,
    ) as List).cast<Map<String, dynamic>>();
    expect(jobs.single['state'], 'failed');
    expect(jobs.single['error'], contains('interrupted'));
    expect(jobs.single['uri'], isNull);
    debugPrint('RECOVERY_JOURNAL_VERIFIED');
    await Future<void>.delayed(const Duration(seconds: 10));
  });
}
