import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/app/theme/app_theme.dart';
import 'package:xrecorder/features/media/photo_tools_screen.dart';
import 'package:xrecorder/l10n/app_languages.dart';
import 'package:xrecorder/l10n/localization.dart';

import 'fixtures/visual_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const media = MethodChannel('com.xrecorder/media');
  for (final locale in AppLanguages.supported) {
    testWidgets(
      '${locale.toLanguageTag()} photo Undo and Redo are distinct accessible actions',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          messenger.setMockMethodCallHandler(media, null);
        });
        final bytes = (await tester.runAsync(fixtureImage))!;
        messenger.setMockMethodCallHandler(
          media,
          (call) async => call.method == 'decodePhoto' ? bytes : null,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PhotoToolsScreen(uri: 'content://qa/task09b/history'),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pumpAndSettle();
        final strings = tester.element(find.byType(PhotoToolsScreen)).l10n;
        // Domain guard: photo cropping must not be translated as agriculture.
        // This catches known catalog mistakes; it is not a full linguistic review.
        final wrongDomain = <String, String>{
          'vi': r'\bcrop\b',
          'es': r'cultivos|cerveza|\bcrop\b',
          'fr': r'\bcrop\b',
          'de': r'pflanzen|\bcrop\b',
          'pt': r'crescimento|\bcrop\b',
          'id': r'tanaman|tumbuhan|tumbuh',
          'ja': r'植物|クロアチア',
          'ko': r'식물',
          'zh': r'种植|\bcrop\b',
          'hi': r'फसल',
          'ar': r'زراع',
        }[locale.languageCode];
        if (wrongDomain != null) {
          for (final label in [
            strings.resetCrop,
            strings.cropLeftRight,
            strings.cropTopBottom,
            strings.cropLeftAndRight,
            strings.cropTopAndBottom,
          ]) {
            expect(
              RegExp(wrongDomain, caseSensitive: false).hasMatch(label),
              isFalse,
              reason: 'Photo crop label must describe image editing: $label',
            );
          }
        }
        expect(strings.undoPhotoEdit, isNot(strings.redoPhotoEdit));
        expect(strings.undoEdit, isNot(strings.redoEdit));
        if (locale.languageCode != 'en') {
          for (final label in [
            strings.undoPhotoEdit,
            strings.redoPhotoEdit,
            strings.undoEdit,
            strings.redoEdit,
          ]) {
            expect(
              RegExp(r'\bedit\b', caseSensitive: false).hasMatch(label),
              isFalse,
              reason: 'History action must use the selected language: $label',
            );
          }
        }
        Finder button(String tooltip) => find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == tooltip,
        );
        final undo = button(strings.undoPhotoEdit),
            redo = button(strings.redoPhotoEdit);
        await tester.scrollUntilVisible(undo, 160, maxScrolls: 25);
        await tester.pumpAndSettle();
        expect(undo, findsOneWidget);
        expect(redo, findsOneWidget);
        Future<void> click(Finder target) async {
          if (target.evaluate().isEmpty) {
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .jumpTo(0);
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(target, 160, maxScrolls: 25);
          }
          await tester.ensureVisible(target);
          await tester.pumpAndSettle();
          expect(target.hitTestable(), findsOneWidget);
          await tester.tap(target);
          await tester.pumpAndSettle();
        }

        expect(tester.widget<IconButton>(undo).onPressed, isNull);
        expect(tester.widget<IconButton>(redo).onPressed, isNull);
        await click(find.text(strings.rotate90));
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(undo, 160, maxScrolls: 25);
        await tester.pumpAndSettle();
        expect(tester.widget<IconButton>(undo).onPressed, isNotNull);
        await click(undo);
        expect(tester.widget<IconButton>(undo).onPressed, isNull);
        expect(tester.widget<IconButton>(redo).onPressed, isNotNull);
        await click(redo);
        expect(tester.widget<IconButton>(undo).onPressed, isNotNull);
        expect(tester.widget<IconButton>(redo).onPressed, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
