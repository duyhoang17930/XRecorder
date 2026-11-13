import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/app/theme/app_theme.dart';
import 'package:xrecorder/core/widgets/studio_shell.dart';
import 'package:xrecorder/core/widgets/studio_widgets.dart';
import 'package:xrecorder/l10n/localization.dart';

class _TrackedAnimation extends Animation<double> {
  final statuses = <AnimationStatusListener>{};
  @override
  double get value => .5;
  @override
  AnimationStatus get status => AnimationStatus.forward;
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  @override
  void addStatusListener(AnimationStatusListener listener) =>
      statuses.add(listener);
  @override
  void removeStatusListener(AnimationStatusListener listener) =>
      statuses.remove(listener);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Manrope')
          ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))
          ..addFont(
            File('test/fixtures/fonts/NotoNaskhArabic-wght.ttf')
                .readAsBytes()
                .then(ByteData.sublistView),
          ))
        .load();
    await (FontLoader('packages/lucide_flutter/LucideIcons')..addFont(
          rootBundle.load('packages/lucide_flutter/assets/lucide.ttf'),
        ))
        .load();
  });
  testWidgets(
    'page transition rebuilds do not accumulate animation listeners',
    (tester) async {
      final animation = _TrackedAnimation();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              for (var i = 0; i < 60; i++) {
                const StudioPageTransitions().buildTransitions<void>(
                  MaterialPageRoute<void>(builder: (_) => const SizedBox()),
                  context,
                  animation,
                  kAlwaysDismissedAnimation,
                  const Text('Page'),
                );
              }
              return const SizedBox();
            },
          ),
        ),
      );
      expect(animation.statuses, isEmpty);
    },
  );

  testWidgets('one dialog per nested origin, current dialog can open a child', (
    tester,
  ) async {
    late BuildContext origin;
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) {
              origin = context;
              return const Scaffold(body: Text('Nested page'));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Widget dialog(BuildContext context) => StudioDialog(
      title: const Text('Parent dialog'),
      actions: [
        TextButton(
          onPressed: () => showStudioDialog<void>(
            context: context,
            builder: (_) => const StudioDialog(title: Text('Child dialog')),
          ),
          child: const Text('Open child'),
        ),
      ],
    );
    final first = showStudioDialog<void>(context: origin, builder: dialog);
    final duplicate = showStudioDialog<void>(context: origin, builder: dialog);
    await tester.pumpAndSettle();
    expect(find.text('Parent dialog'), findsOneWidget);
    await tester.tap(find.text('Open child'));
    await tester.pumpAndSettle();
    expect(find.text('Child dialog'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Parent dialog'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await Future.wait([first, duplicate]);
    expect(find.text('Nested page'), findsOneWidget);
  });

  testWidgets('notices finish their entrance immediately with Reduce Motion', (
    tester,
  ) async {
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              host = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    showNotice(host, 'Saved');
    await tester.pump();
    final notice = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(notice.animation!.isCompleted, isTrue);
    ScaffoldMessenger.of(host).removeCurrentSnackBar();
    await tester.pumpAndSettle();
  });

  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('navigation accessibility dark=$dark scale=$scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 640);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              locale: Locale(scale == 2 ? 'ar' : 'en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                bottomNavigationBar: StudioBottomNavigation(
                  selected: 0,
                  onDestination: (_) {},
                  onCreate: () {},
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          final artifacts = Platform.environment['UI_ARTIFACT_DIRECTORY'];
          if (!dark && scale == 2 && artifacts != null) {
            await tester.runAsync(() async {
              final view = tester.binding.renderViews.single;
              final image = await (view.debugLayer! as OffsetLayer).toImage(
                view.paintBounds,
              );
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                '$artifacts/navigation_contrast_${DateTime.now().microsecondsSinceEpoch}.png',
              );
              try {
                await file.create(exclusive: true);
                await file.writeAsBytes(bytes!.buffer.asUint8List());
              } finally {
                image.dispose();
              }
            });
          }
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      });
    }
    testWidgets(
      'navigation labels contrast over black and white media dark=$dark',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            home: Scaffold(
              bottomNavigationBar: StudioBottomNavigation(
                selected: 0,
                onDestination: (_) {},
                onCreate: () {},
              ),
            ),
          ),
        );
        final filter = tester.widget<BackdropFilter>(
          find.byType(BackdropFilter),
        );
        final glass =
            ((filter.child! as DecoratedBox).decoration as BoxDecoration)
                .color!;
        final indicator = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('navigation-selected-indicator')),
        );
        final tint = (indicator.decoration as BoxDecoration).color!;
        final labels = tester
            .widgetList<AnimatedDefaultTextStyle>(
              find.byType(AnimatedDefaultTextStyle),
            )
            .where((w) => w.child is FittedBox)
            .toList();
        expect(labels.length, 4);
        for (final media in [Colors.black, Colors.white]) {
          final surface = Color.alphaBlend(glass, media);
          for (var i = 0; i < labels.length; i++) {
            final bg = i == 0 ? Color.alphaBlend(tint, surface) : surface;
            final a = labels[i].style.color!.computeLuminance(),
                b = bg.computeLuminance();
            final ratio = ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05);
            expect(
              ratio,
              greaterThanOrEqualTo(4.5),
              reason: 'label $i over $media',
            );
          }
        }
      },
    );
  }
  testWidgets(
    'high contrast disables glass filtering; rapid selection stays clipped',
    (tester) async {
      final selected = ValueNotifier<int>(0);
      addTearDown(selected.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(highContrast: true),
            child: child!,
          ),
          home: Scaffold(
            bottomNavigationBar: ValueListenableBuilder<int>(
              valueListenable: selected,
              builder: (_, value, _) => StudioBottomNavigation(
                selected: value,
                onDestination: (next) => selected.value = next,
                onCreate: () {},
              ),
            ),
          ),
        ),
      );
      final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      expect(filter.enabled, isFalse);
      expect(
        ((filter.child! as DecoratedBox).decoration as BoxDecoration).color!.a,
        1,
      );
      for (final next in [3, 0, 2, 1, 3]) {
        selected.value = next;
        await tester.pump(const Duration(milliseconds: 25));
        final indicator = tester.getRect(
          find.byKey(const ValueKey('navigation-selected-indicator')),
        );
        final capsule = tester.getRect(find.byType(BackdropFilter));
        expect(indicator.left, greaterThanOrEqualTo(capsule.left));
        expect(indicator.right, lessThanOrEqualTo(capsule.right));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
