import 'package:flutter/widgets.dart';

/// UI locales only. Whisper language codes have a separate catalog.
abstract final class AppLanguages {
  static const names = <String, String>{
    'en': 'English',
    'vi': 'Tiếng Việt',
    'es': 'Español',
    'pt-BR': 'Português (Brasil)',
    'fr': 'Français',
    'de': 'Deutsch',
    'id': 'Bahasa Indonesia',
    'ja': '日本語',
    'ko': '한국어',
    'zh-Hans': '简体中文',
    'hi': 'हिन्दी',
    'ar': 'العربية',
  };

  static const supported = <Locale>[
    Locale('en'),
    Locale('vi'),
    Locale('es'),
    Locale('pt', 'BR'),
    Locale('fr'),
    Locale('de'),
    Locale('id'),
    Locale('ja'),
    Locale('ko'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale('hi'),
    Locale('ar'),
  ];

  static Locale? resolveSaved(Object? tag) {
    if (tag is! String) return null;
    for (final locale in supported) {
      if (locale.toLanguageTag() == tag.replaceAll('_', '-')) return locale;
    }
    return null;
  }

  static String nativeName(Locale locale) =>
      names[locale.toLanguageTag()] ?? 'English';
}
