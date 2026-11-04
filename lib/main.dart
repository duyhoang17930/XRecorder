import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'app/app.dart';
import 'core/constants/design_tokens.dart';
import 'core/persistence/settings_store.dart';
import 'features/settings/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Manrope',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
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
  });
  final settings = SettingsController(store: const AndroidSettingsStore());
  await settings.restore();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
    ),
  );
  runApp(XRecorderApp(settings: settings));
}
