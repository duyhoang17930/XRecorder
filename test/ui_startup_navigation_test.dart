import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/app/theme/app_theme.dart';
import 'package:xrecorder/core/widgets/startup_splash.dart';
import 'package:xrecorder/core/widgets/studio_shell.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';
import 'package:xrecorder/features/onboarding/onboarding_store.dart';
import 'package:xrecorder/l10n/generated/app_localizations.dart';
import 'package:xrecorder/l10n/generated/app_localizations_en.dart';

import 'fixtures/catalog.dart';

void main() {
  testWidgets('startup reveals the app as soon as preferences finish loading', (
    tester,
  ) async {
    final startup = Completer<OnboardingState>();
    await tester.pumpWidget(
      XRecorderApp(
        settings: SettingsController(),
        mediaRepository: TestCatalog(),
        startupFuture: startup.future,
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('startup-initializing')), findsOneWidget);
    expect(find.byType(StartupSplash), findsNothing);
    expect(find.bySemanticsLabel('3HRecorder'), findsNothing);
    expect(find.text('Video Library'), findsNothing);

    startup.complete(OnboardingState.complete);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Video Library'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'legacy logo painter remains stable when explicitly mounted with reduced motion',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const StartupSplash(),
          ),
        ),
      );

      final logo = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is HandDrawnLogoPainter,
      );
      final painter =
          tester.widget<CustomPaint>(logo).painter! as HandDrawnLogoPainter;
      expect(painter.progress, 1);
      expect(find.bySemanticsLabel('3HRecorder'), findsOneWidget);
    },
  );

  testWidgets('floating navigation keeps destinations and Create reachable', (
    tester,
  ) async {
    var selected = -1;
    var createCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          bottomNavigationBar: StudioBottomNavigation(
            selected: 0,
            onDestination: (index) => selected = index,
            onCreate: () => createCount++,
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
    final l10n = AppLocalizationsEn();
    await tester.tap(find.byTooltip(l10n.photo));
    expect(selected, 1);
    await tester.tap(find.byTooltip(l10n.create));
    expect(createCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('floating navigation yields space to the keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 280)),
          child: Scaffold(
            bottomNavigationBar: StudioBottomNavigation(
              selected: 0,
              onDestination: (_) {},
              onCreate: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selected pill stays inside the capsule across compact RTL layouts',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final theme in [AppTheme.light, AppTheme.dark]) {
        for (final width in [320.0, 360.0, 393.0, 411.0]) {
          tester.view.physicalSize = Size(width, 568);
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              locale: const Locale('ar'),
              supportedLocales: const [Locale('ar')],
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  padding: const EdgeInsets.only(bottom: 24),
                  viewPadding: const EdgeInsets.only(bottom: 24),
                ),
                child: child!,
              ),
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  bottomNavigationBar: StudioBottomNavigation(
                    selected: 3,
                    onDestination: (_) {},
                    onCreate: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final capsule = tester.getRect(find.byType(ClipRRect));
          final indicator = tester.getRect(
            find.byKey(const ValueKey('navigation-selected-indicator')),
          );
          expect(indicator.left, greaterThanOrEqualTo(capsule.left));
          expect(indicator.right, lessThanOrEqualTo(capsule.right));
          expect(indicator.top, greaterThanOrEqualTo(capsule.top));
          expect(indicator.bottom, lessThanOrEqualTo(capsule.bottom));
          expect(
            tester
                .widget<AnimatedPositionedDirectional>(
                  find.byType(AnimatedPositionedDirectional),
                )
                .duration,
            const Duration(milliseconds: 260),
          );

          final destinations = find.byType(TextButton);
          for (var index = 0; index < destinations.evaluate().length; index++) {
            expect(
              tester.getSize(destinations.at(index)).width,
              greaterThanOrEqualTo(48),
            );
          }
          final create = tester.getRect(find.byType(FilledButton));
          expect(create.shortestSide, 52);
          expect(create.left, greaterThan(capsule.right));
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets('navigation motion becomes immediate with Reduce Motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          bottomNavigationBar: StudioBottomNavigation(
            selected: 2,
            onDestination: (_) {},
            onCreate: () {},
          ),
        ),
      ),
    );

    expect(
      tester
          .widget<AnimatedPositionedDirectional>(
            find.byType(AnimatedPositionedDirectional),
          )
          .duration,
      Duration.zero,
    );
    expect(tester.takeException(), isNull);
  });
}
