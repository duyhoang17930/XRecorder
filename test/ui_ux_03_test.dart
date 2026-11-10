import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/app/theme/app_theme.dart';
import 'package:xrecorder/features/onboarding/onboarding_screen.dart';
import 'package:xrecorder/features/onboarding/onboarding_store.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';
import 'package:xrecorder/features/settings/settings_hub_screen.dart';
import 'package:xrecorder/features/settings/app_language_dialog.dart';
import 'package:xrecorder/l10n/localization.dart';

void main() {
  testWidgets('language search survives rotation with a landscape keyboard', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(411, 920);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var keyboard = 0.0;
    late StateSetter update;
    final settings = SettingsController();
    await tester.pumpWidget(
      SettingsScope(
        controller: settings,
        child: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(viewInsets: EdgeInsets.only(bottom: keyboard)),
                child: child!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showAppLanguageDialog(context),
                    child: const Text('Open'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ar');
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(920, 411);
    update(() => keyboard = 260);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'ar',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
    );
    expect(find.text('العربية'), findsOneWidget);
    expect(
      tester.getRect(find.byType(TextField)).bottom,
      lessThanOrEqualTo(151),
    );
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(411, 920);
    update(() => keyboard = 0);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'ar',
    );
    expect(find.text('العربية'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    settings.dispose();
  });
  for (final width in [320.0, 360.0, 393.0, 411.0]) {
    for (final landscape in [false, true]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets(
          'text CTA stays centered and reachable ${width}dp landscape=$landscape scale=$scale',
          (tester) async {
            final size = landscape ? Size(800, width) : Size(width, 800);
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPhysicalSize);
            final locale = scale == 2
                ? const Locale('ar')
                : width == 393
                ? const Locale('ja')
                : width == 360
                ? const Locale('vi')
                : const Locale('en');
            await tester.pumpWidget(
              MaterialApp(
                theme: landscape ? AppTheme.dark : AppTheme.light,
                locale: locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: scale == 1.5,
                  ),
                  child: child!,
                ),
                home: OnboardingScreen(
                  store: const ReplayOnboardingStore(),
                  initialPage: 0,
                  onCompleted: () {},
                ),
              ),
            );
            await tester.pumpAndSettle();
            for (var page = 0; page < 3; page++) {
              final strings = tester
                  .element(find.byType(OnboardingScreen))
                  .l10n;
              if (landscape && scale == 1) {
                final description = [
                  strings.onboardingRecordDescription,
                  strings.onboardingEditDescription,
                  strings.onboardingSubtitlesDescription,
                ][page];
                expect(
                  tester.getRect(find.text(description)).bottom,
                  lessThanOrEqualTo(
                    tester.getRect(find.byType(FilledButton)).top,
                  ),
                  reason: 'Page $page description must remain above the CTA',
                );
              }
              final finder = find.byType(FilledButton);
              final button = tester.widget<FilledButton>(finder);
              expect(button.child, isA<Text>());
              final style = button.style!.textStyle!.resolve({})!;
              expect(style.fontSize, 17);
              expect(style.fontWeight, FontWeight.w600);
              final rect = tester.getRect(finder);
              expect(rect.width, inInclusiveRange(180, 220));
              expect(rect.height, greaterThanOrEqualTo(48));
              expect(rect.center.dx, closeTo(size.width / 2, .1));
              expect(rect.bottom, lessThanOrEqualTo(size.height));
              expect(rect.top, greaterThanOrEqualTo(0));
              expect(find.byTooltip('Back'), findsNothing);
              expect(tester.takeException(), isNull);
              if (page != 2) {
                await tester.tap(finder);
                await tester.pumpAndSettle();
              }
            }
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            expect(
              find.text(
                tester
                    .element(find.byType(OnboardingScreen))
                    .l10n
                    .onboardingEditTitle,
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('normal Settings has no gallery entry even in debug', (
    tester,
  ) async {
    final settings = SettingsController();
    await tester.pumpWidget(
      SettingsScope(
        controller: settings,
        child: const MaterialApp(home: Scaffold(body: SettingsHubScreen())),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('About & licenses'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('UI component gallery'), findsNothing);
    expect(find.text('About & licenses'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Use'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    settings.dispose();
  });
}
