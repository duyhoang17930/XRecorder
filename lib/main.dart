import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'app/app.dart';
import 'core/persistence/settings_store.dart';
import 'features/settings/settings_controller.dart';
import 'features/onboarding/onboarding_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Manrope',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
    yield LicenseEntryWithLineBreaks([
      'Lucide artwork (ISC / Feather MIT)',
    ], await rootBundle.loadString('assets/licenses/Lucide-LICENSE.txt'));
    yield LicenseEntryWithLineBreaks([
      'AndroidX Media3',
      'AndroidX',
      'Kotlin',
      'Guava',
      'ReLinker',
      'JSpecify',
      'J2ObjC',
      'JSR305',
      'Error Prone',
    ], await rootBundle.loadString('assets/licenses/Media3-APACHE-2.0.txt'));
    yield LicenseEntryWithLineBreaks(
      ['checker-qual (MIT annotations)'],
      await rootBundle.loadString(
        'assets/licenses/CheckerFramework-LICENSE.txt',
      ),
    );
    yield LicenseEntryWithLineBreaks([
      'Android runtime dependency inventory',
    ], await rootBundle.loadString('assets/licenses/ANDROID_DEPENDENCIES.txt'));
    yield LicenseEntryWithLineBreaks(
      ['whisper.cpp', 'ggml', 'RNNoise'],
      await rootBundle.loadString('assets/licenses/EDITOR_NATIVE_LICENSES.txt'),
    );
    yield LicenseEntryWithLineBreaks([
      'Unicode CLDR language names',
      'Babel',
    ], await rootBundle.loadString('assets/licenses/CLDR-LICENSE.txt'));
  });
  final settings = SettingsController(store: const AndroidSettingsStore());
  const onboardingStore = AndroidOnboardingStore();
  final startup = () async {
    await settings.restore();
    try {
      return await onboardingStore.load();
    } catch (_) {
      // Keep an existing user moving if the optional welcome-state store fails.
      return OnboardingState.complete;
    }
  }();
  runApp(
    XRecorderApp(
      settings: settings,
      startupFuture: startup,
      onboardingStore: onboardingStore,
    ),
  );
}
