import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:xrecorder/features/settings/settings_controller.dart';
import 'package:xrecorder/l10n/app_languages.dart';
import 'package:xrecorder/l10n/editor_numbers.dart';
import 'package:xrecorder/l10n/localization.dart';

import 'settings_persistence_test.dart' show MemoryStore;

void main() {
  testWidgets('cached formats keep locale and precision independent', (
    tester,
  ) async {
    final captured = <(String Function(double), String)>[];
    final date = DateTime(2026, 11, 8, 12, 30);
    for (final locale in AppLanguages.supported) {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final tag = context.l10n.localeName;
      for (final digits in [0, 3, 1, 2, 0]) {
        final oracle = NumberFormat.decimalPattern(tag)
          ..minimumFractionDigits = digits
          ..maximumFractionDigits = digits;
        expect(
          context.decimal(1234.5678, digits: digits),
          oracle.format(1234.5678),
        );
      }
      expect(
        context.displayValue(1234.5678),
        NumberFormat.decimalPattern(tag).format(1234.5678),
      );
      expect(
        context.displayValue(date),
        DateFormat.yMd(tag).add_Hm().format(date.toLocal()),
      );
      expect(context.calendarDate(date), DateFormat.yMd(tag).format(date));
      expect(
        context.calendarDate(date.add(const Duration(hours: 2))),
        context.calendarDate(date),
      );
      expect(
        context.calendarDate(date.add(const Duration(days: 1))),
        isNot(context.calendarDate(date)),
      );
      final callback = context.spokenValue((_, value) => value, digits: 2);
      captured.add((callback, context.decimal(1234.5678, digits: 2)));
    }
    await tester.pumpWidget(const SizedBox());
    // Semantics may retain a callback after its element detaches or the active
    // locale changes; it must keep its original formatter and precision.
    for (final (callback, expected) in captured) {
      expect(callback(1234.5678), expected);
    }
  });
  test('shipping ARB resources keep every key, typed placeholder and Arabic plural category', () {
    Map<String, dynamic> read(String tag) =>
        jsonDecode(File('lib/l10n/app_$tag.arb').readAsStringSync())
            as Map<String, dynamic>;
    final source = read('en');
    final keys = source.keys.where((v) => !v.startsWith('@')).toSet();
    for (final locale in AppLanguages.supported) {
      final tag = locale.toLanguageTag().replaceAll('-', '_');
      final resource = read(tag);
      expect(
        resource.keys.where((v) => !v.startsWith('@')).toSet(),
        keys,
        reason: tag,
      );
      for (final key in keys) {
        final value = resource[key] as String;
        expect(value.trim(), isNotEmpty, reason: '$tag/$key');
        expect(
          RegExp(r'\}[sS]\s+[sS]\b|%\s+%|秒\s*秒|초\s*초').hasMatch(value),
          isFalse,
          reason: '$tag/$key repeated display unit',
        );
        if ([
          'volumePercent',
          'operationProgress',
          'percentValue',
        ].contains(key)) {
          expect(
            RegExp(r'[%٪％]').allMatches(value).length,
            1,
            reason: '$tag/$key percent sign',
          );
        }
        expect(
          utf8.decode(utf8.encode(value)),
          value,
          reason: '$tag/$key UTF16',
        );
        expect(
          value.contains('\ufffd'),
          isFalse,
          reason: '$tag/$key replacement character',
        );
        final expected =
            ((source['@$key'] as Map?)?['placeholders'] as Map?)?.keys
                .toSet() ??
            <Object>{};
        final actual = RegExp(r'\{([a-zA-Z][a-zA-Z0-9]*)\s*[,}]')
            .allMatches(value)
            .map((v) => v.group(1))
            .toSet();
        expect(actual, expected, reason: '$tag/$key placeholders');
      }
    }
    final ar = read('ar');
    for (final key in ['itemCount', 'clipCount', 'segmentCount']) {
      for (final category in ['zero', 'one', 'two', 'few', 'many', 'other']) {
        expect(ar[key], contains('$category{'), reason: '$key/$category');
      }
    }
    for (final pair in [('pt', 'pt_BR'), ('zh', 'zh_Hans')]) {
      final parent = read(pair.$1), child = read(pair.$2);
      expect(
        {for (final key in keys) key: parent[key]},
        {for (final key in keys) key: child[key]},
      );
    }
  });
  test(
    'locale edits preserve corrupt and future preferences verbatim',
    () async {
      for (final document in [
        '{broken',
        '{"version":99,"values":{"fps":"30"}}',
      ]) {
        final store = MemoryStore()..document = document;
        final settings = SettingsController(store: store);
        await settings.restore();
        expect(settings.canSave, isFalse);
        settings.setAppLocale(const Locale('ar'));
        settings.setSpeechLanguage('ja');
        await settings.flushed;
        expect(store.document, document);
        expect(settings.persistenceError, isNotNull);
        settings.dispose();
      }
    },
  );

  test(
    'legacy settings migrate with system locale and retain capture choices',
    () async {
      for (final version in [0, 1]) {
        final values = <String, Object>{
          'fps': '30',
          'audio': 'Microphone',
          'gain': 125,
          'cache': false,
        };
        final store = MemoryStore()
          ..document = jsonEncode(
            version == 0 ? values : {'version': version, 'values': values},
          );
        final settings = SettingsController(store: store);
        await settings.restore();
        expect(settings.appLocale, isNull);
        expect(settings.fps, '30');
        expect(settings.audio, 'Microphone');
        expect(settings.gain, 125);
        expect(settings.cache, isFalse);
        final migrated = jsonDecode(store.document!);
        expect(migrated['version'], 2);
        expect(migrated['values']['appLocale'], 'system');
        settings.dispose();
      }
    },
  );

  test(
    'locale persistence is additive and does not change capture settings',
    () async {
      final store = MemoryStore()
        ..document = jsonEncode({
          'version': 2,
          'values': {'fps': '30', 'audio': 'Internal Audio', 'gain': 125},
        });
      final first = SettingsController(store: store);
      await first.restore();
      expect(first.appLocale, isNull);
      final capture = snapshot(first);
      for (final locale in AppLanguages.supported) {
        first.setAppLocale(locale);
        first.setSpeechLanguage('ja');
        expect(snapshot(first), capture);
      }
      first.setAppLocale(const Locale('ar'));
      await first.flushed;
      final restored = SettingsController(store: store);
      await restored.restore();
      expect(restored.appLocale, const Locale('ar'));
      expect(restored.preferredSpeechLanguage, 'ja');
      expect(restored.fps, '30');
      expect(restored.audio, 'Internal Audio');
      restored.setAppLocale(null);
      await restored.flushed;
      expect(jsonDecode(store.document!)['values']['appLocale'], 'system');
      first.dispose();
      restored.dispose();
    },
  );

  test(
    'unknown saved locale follows system and supported tags stay canonical',
    () {
      expect(AppLanguages.resolveSaved('pt_BR'), const Locale('pt', 'BR'));
      expect(AppLanguages.resolveSaved('zh_Hans')?.scriptCode, 'Hans');
      expect(AppLanguages.resolveSaved('xx-ZZ'), isNull);
      expect(AppLanguages.supported.length, 12);
    },
  );

  test('localized decimal input preserves ASCII serialization and rejects ambiguity', () {
    for (final input in ['1.25', '1,25', '١٫٢٥', '۱٫۲۵', '१.२५', '１.２５']) {
      expect(parseEditorDecimal(input), 1.25, reason: input);
    }
    for (final input in [
      'NaN',
      'Infinity',
      '1,234,567',
      '1 234',
      '1.2.3',
      '١٬٢٣٤',
      '2s',
    ]) {
      expect(parseEditorDecimal(input), isNull, reason: input);
    }
  });

  for (final locale in AppLanguages.supported) {
    testWidgets(
      'loads ${locale.toLanguageTag()} and keeps media coordinates LTR',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLanguages.supported,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    Text(context.l10n.appLanguage),
                    Text(
                      Directionality.of(context).name,
                      key: const Key('ui-direction'),
                    ),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Builder(
                        builder: (media) => Text(
                          Directionality.of(media).name,
                          key: const Key('media-direction'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.widget<Text>(find.byKey(const Key('ui-direction'))).data,
          locale.languageCode == 'ar' ? 'rtl' : 'ltr',
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('media-direction'))).data,
          'ltr',
        );
      },
    );
  }
}

List<Object?> snapshot(SettingsController settings) {
  final v = settings.recordingSnapshot;
  return [
    v.mode,
    v.audioSource,
    v.width,
    v.height,
    v.fps,
    v.bitrate,
    v.codec,
    v.orientation,
    v.countdown,
    v.durationLimit,
    v.micGain,
    v.internalGain,
    v.noiseReduction,
    v.facecam,
    v.constantFrameRate,
    v.hardwareEncoding,
    v.shakeToStop,
    v.allowScreenOff,
    v.showTouches,
    v.recoveryCache,
  ];
}
