import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 60),
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final path = Platform.environment['UI_ARTIFACT_DIRECTORY'];
    if (path == null) throw StateError('Set a new TASK08 evidence directory.');
    final directory = Directory(path);
    await directory.create(recursive: true);
    final output = File('$path/emulator_verification.json');
    await output.create(exclusive: true);
    await output.writeAsString(jsonEncode(data), flush: true);
  },
);
