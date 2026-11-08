import '../l10n/app_languages.dart';

/// Only advertise appearance/language resources that the app actually ships.
abstract final class AppConfiguration {
  static const supportedLocales = AppLanguages.supported;
}
