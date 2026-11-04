import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Native diagnostics are bounded and share handoff opens', (
    tester,
  ) async {
    const channel = MethodChannel('com.xrecorder/support');
    final details = (await channel.invokeMethod<String>('diagnostics'))!;
    expect(details, contains('Android API:'));
    expect(details, isNot(contains('serial')));
    await expectLater(
      channel.invokeMethod<void>('share', {'text': '', 'attachment': null}),
      throwsA(isA<PlatformException>()),
    );
    await channel.invokeMethod<void>('share', {
      'text': 'Local integration test report. Do not send.',
      'attachment': null,
    });
    // Successful chooser launch is the only assertion; no recipient is selected.
  });
}
