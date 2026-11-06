import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final output =
      Platform.environment['UI_ARTIFACT_DIRECTORY'] ??
      'build/verification/ui/task02';
  final directory = Directory('$output/screenshots');
  await directory.create(recursive: true);
  await integrationDriver(
    writeResponseOnFailure: true,
    onScreenshot:
        (String name, List<int> bytes, [Map<String, Object?>? args]) async {
          if (!RegExp(r'^[a-z0-9_]+$').hasMatch(name)) return false;
          await File('${directory.path}/$name.png').writeAsBytes(bytes);
          return bytes.isNotEmpty;
        },
    responseDataCallback: (data) async {
      final report = Map<String, dynamic>.from(data ?? {})
        ..remove('screenshots');
      final capture = report.remove('nativeCapturePng');
      if (capture is String) {
        await File('$output/captured-screen.png')
            .writeAsBytes(base64Decode(capture));
      }
      await File('$output/emulator_verification.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    },
  );
}
