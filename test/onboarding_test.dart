import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/app/theme/app_theme.dart';
import 'package:xrecorder/core/persistence/settings_store.dart';
import 'package:xrecorder/features/onboarding/onboarding_screen.dart';
import 'package:xrecorder/features/onboarding/onboarding_store.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';
import 'package:xrecorder/l10n/generated/app_localizations.dart';

import 'fixtures/catalog.dart';

class MemoryOnboardingStore implements OnboardingStore {
  bool completed = false;
  int page = 0;
  bool failComplete = false;

  @override
  Future<OnboardingState> load() async =>
      OnboardingState(completed: completed, page: page);

  @override
  Future<void> savePage(int value) async => page = value;

  @override
  Future<void> complete() async {
    if (failComplete) throw StateError('simulated persistence error');
    completed = true;
    page = 2;
  }
}

class MemorySettingsStore implements SettingsStore {
  final writes = <String>[];
  String? document;

  @override
  Future<String?> read() async => document;

  @override
  Future<void> write(String document) async => writes.add(document);
}

Widget onboardingApp(
  OnboardingStore store, {
  int page = 0,
  Locale locale = const Locale('en'),
  ThemeData? theme,
  bool reducedMotion = false,
  Key? screenKey,
}) => MaterialApp(
  theme: theme ?? AppTheme.dark,
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('vi'), Locale('ar')],
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reducedMotion),
    child: OnboardingScreen(
      key: screenKey,
      store: store,
      initialPage: page,
      onCompleted: () {},
    ),
  ),
);

String artworkAsset(ImageProvider provider) {
  if (provider is ResizeImage) {
    expect(provider.width, inInclusiveRange(1, 1200));
    provider = provider.imageProvider;
  }
  return (provider as AssetImage).assetName;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fresh install shows the first onboarding screen', (
    tester,
  ) async {
    await tester.pumpWidget(onboardingApp(MemoryOnboardingStore()));
    expect(find.text('Record Anything'), findsOneWidget);
    expect(
      find.text(
        'Capture your screen in high quality. Choose your audio settings and start recording in just a few taps.',
      ),
      findsOneWidget,
    );
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Skip persists completion and keeps controls guarded', (
    tester,
  ) async {
    final store = MemoryOnboardingStore();
    var completedCallback = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        supportedLocales: const [Locale('en')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: OnboardingScreen(
          store: store,
          initialPage: 0,
          onCompleted: () => completedCallback++,
        ),
      ),
    );

    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(store.completed, isTrue);
    expect(store.page, 2);
    expect(completedCallback, 1);
  });

  testWidgets('Next, swipe, Back and interrupted progress persist', (
    tester,
  ) async {
    final store = MemoryOnboardingStore();
    await tester.pumpWidget(onboardingApp(store));
    expect(
      artworkAsset(
        tester
            .widget<Image>(find.byKey(const ValueKey('onboarding-art-0')))
            .image,
      ),
      'assets/images/onboarding/record_anything_v1.png',
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Your Way'), findsOneWidget);
    expect(
      artworkAsset(
        tester
            .widget<Image>(find.byKey(const ValueKey('onboarding-art-1')))
            .image,
      ),
      'assets/images/onboarding/edit_your_way_v1.png',
    );
    expect(store.page, 1);

    await tester.drag(find.byType(PageView), const Offset(-640, 0));
    await tester.pumpAndSettle();
    expect(find.text('Smart Subtitles'), findsOneWidget);
    expect(
      artworkAsset(
        tester
            .widget<Image>(find.byKey(const ValueKey('onboarding-art-2')))
            .image,
      ),
      'assets/images/onboarding/smart_subtitles_v1.png',
    );
    expect(store.page, 2);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Edit Your Way'), findsOneWidget);
    expect(store.page, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      onboardingApp(store, page: store.page, screenKey: UniqueKey()),
    );
    expect(find.text('Edit Your Way'), findsOneWidget);
  });

  testWidgets('Get Started retries after a persistence failure', (
    tester,
  ) async {
    final store = MemoryOnboardingStore()..page = 2;
    store.failComplete = true;
    await tester.pumpWidget(onboardingApp(store, page: 2));
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Couldn'), findsOneWidget);
    expect(store.completed, isFalse);

    store.failComplete = false;
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(store.completed, isTrue);
  });

  testWidgets('completed onboarding does not replay after app restart', (
    tester,
  ) async {
    final onboarding = MemoryOnboardingStore()..completed = true;
    final settingsStore = MemorySettingsStore();
    final settings = SettingsController(store: settingsStore);
    await tester.pumpWidget(
      XRecorderApp(
        settings: settings,
        mediaRepository: TestCatalog(),
        startupFuture: onboarding.load(),
        onboardingStore: onboarding,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Video Library'), findsOneWidget);
    expect(find.text('Record Anything'), findsNothing);
    expect(settingsStore.writes, isEmpty);
  });

  testWidgets(
    'fresh onboarding is the startup destination and leaves settings intact',
    (tester) async {
      final onboarding = MemoryOnboardingStore();
      final settingsStore = MemorySettingsStore()
        ..document =
            '{"version":2,"values":{"themeMode":"light","appLocale":"en","speechLanguage":"auto"}}';
      final settings = SettingsController(store: settingsStore);
      await settings.restore();
      expect(settings.themeMode, ThemeMode.light);

      await tester.pumpWidget(
        XRecorderApp(
          settings: settings,
          mediaRepository: TestCatalog(),
          startupFuture: onboarding.load(),
          onboardingStore: onboarding,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Record Anything'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Your Way'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Smart Subtitles'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Edit Your Way'), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('Video Library'), findsOneWidget);
      expect(settings.themeMode, ThemeMode.light);
      expect(settingsStore.writes, isEmpty);
    },
  );

  testWidgets('rapid repeated Next taps advance only one page', (tester) async {
    final store = MemoryOnboardingStore();
    await tester.pumpWidget(onboardingApp(store));
    await tester.tap(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Your Way'), findsOneWidget);
    expect(find.text('Smart Subtitles'), findsNothing);
    expect(store.page, 1);
  });

  testWidgets(
    'Arabic RTL, light theme, large text and narrow layout do not clip',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: OnboardingScreen(
            store: MemoryOnboardingStore(),
            initialPage: 0,
            onCompleted: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(PageView), findsOneWidget);
    },
  );

  testWidgets('reduced motion shows a stable onboarding artwork', (
    tester,
  ) async {
    await tester.pumpWidget(
      onboardingApp(MemoryOnboardingStore(), reducedMotion: true),
    );
    final illustration = tester.widget<Image>(
      find.byKey(const ValueKey('onboarding-art-0')),
    );
    expect(
      artworkAsset(illustration.image),
      'assets/images/onboarding/record_anything_v1.png',
    );
    expect(illustration.fit, BoxFit.contain);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android store uses the isolated onboarding channel contract', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidOnboardingStore.channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'read' => {'completed': false, 'page': 1},
            _ => null,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(AndroidOnboardingStore.channel, null),
    );

    const store = AndroidOnboardingStore();
    final state = await store.load();
    expect(state.completed, isFalse);
    expect(state.page, 1);
    await store.savePage(2);
    await store.complete();
    expect(calls.map((call) => call.method), ['read', 'savePage', 'complete']);
    expect(calls[1].arguments, 2);
  });
}
