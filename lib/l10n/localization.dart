import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'generated/app_localizations.dart';
import 'generated/app_localizations_en.dart';
import 'message_catalog.dart';

export 'generated/app_localizations.dart';

// Intl parses patterns and constructs locale symbols on creation. Library
// scrolling repeatedly formats the same locales; keep a bounded cache of
// private, fully configured formatters. Fraction precision is part of the key
// so a slider cannot change the format used by another control.
final _numbers = <(String, int?), NumberFormat>{};
final _dates = <(String, bool), DateFormat>{};

V _cachedFormat<K, V>(Map<K, V> cache, K key, V Function() create) {
  final value = cache.remove(key) ?? create();
  cache[key] = value;
  if (cache.length > 32) cache.remove(cache.keys.first);
  return value;
}

NumberFormat _numberFormat(String locale, [int? digits]) =>
    _cachedFormat(_numbers, (locale, digits), () {
      final format = NumberFormat.decimalPattern(locale);
      if (digits != null) {
        format.minimumFractionDigits = digits;
        format.maximumFractionDigits = digits;
      }
      return format;
    });

DateFormat _dateFormat(String locale, {bool withTime = false}) =>
    _cachedFormat(_dates, (locale, withTime), () {
      final format = DateFormat.yMd(locale);
      return withTime ? format.add_Hm() : format;
    });

extension StudioLocalization on BuildContext {
  /// Slider semantics can be queried while their elements are being detached.
  /// Resolve inherited resources now, never from the returned callback.
  String Function(double) spokenValue(
    String Function(AppLocalizations, String) label, {
    double multiplier = 1,
    int digits = 0,
  }) {
    final strings = l10n;
    final formatter = _numberFormat(strings.localeName, digits);
    return (value) => label(strings, formatter.format(value * multiplier));
  }

  /// The fallback also supports isolated widgets hosted outside the app shell.
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      AppLocalizationsEn();

  /// Adapts existing stable validation messages at the presentation boundary.
  /// Unknown strings are retained; never pass user-authored media text here.
  String message(String source) => localizedMessage(l10n, source);

  String displayValue(Object? value) => switch (value) {
    num number => _numberFormat(l10n.localeName).format(number),
    DateTime date => _dateFormat(
      l10n.localeName,
      withTime: true,
    ).format(date.toLocal()),
    _ => value?.toString() ?? '',
  };

  /// Calendar-day headings must not split one day into separate time groups.
  String calendarDate(DateTime value) =>
      _dateFormat(l10n.localeName).format(value.toLocal());

  String decimal(num value, {int digits = 1}) =>
      _numberFormat(l10n.localeName, digits).format(value);

  String fileSize(int bytes) {
    if (bytes < 1024) return '${displayValue(bytes)} ${l10n.bytes}';
    if (bytes < 1024 * 1024) return '${decimal(bytes / 1024)} ${l10n.kib}';
    if (bytes < 1024 * 1024 * 1024) {
      return '${decimal(bytes / (1024 * 1024))} ${l10n.mib}';
    }
    return '${decimal(bytes / (1024 * 1024 * 1024))} ${l10n.gib}';
  }

  String effectValue(Object value) => switch (value) {
    'none' => l10n.none,
    'deep' => l10n.deepVoice,
    'bright' => l10n.brightVoice,
    'robot' => l10n.robotVoice,
    'grayscale' => l10n.grayscale,
    'invert' => l10n.invertColors,
    'white' => l10n.white,
    'yellow' => l10n.yellow,
    'small' => l10n.small,
    'normal' => l10n.normal,
    'large' => l10n.large,
    'dark' => l10n.dark,
    'bottom' => l10n.bottom,
    'top' => l10n.top,
    'text' => l10n.text,
    'sticker' => l10n.sticker,
    'drawing' => l10n.drawing,
    'star' => l10n.stickerStar,
    'heart' => l10n.stickerHeart,
    'circle' => l10n.circle,
    'video' => l10n.video,
    'photo' => l10n.photo,
    _ => displayValue(value),
  };
}
