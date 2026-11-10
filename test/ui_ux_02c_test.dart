import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/core/ui/components/bottom_sheets/studio_bottom_sheet.dart';
import 'package:xrecorder/core/widgets/studio_shell.dart';
import 'package:xrecorder/features/recording/recording_service.dart';
import 'package:xrecorder/features/onboarding/onboarding_screen.dart';
import 'package:xrecorder/features/onboarding/onboarding_store.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';
import 'package:xrecorder/features/settings/studio_identity.dart';
import 'package:xrecorder/features/settings/support_screen.dart';

import 'fixtures/catalog.dart';

void main() {
  testWidgets('capture footer controls stay above floating navigation', (
    tester,
  ) async {
    Map<String, Object?> snapshot = {'id': 'host-only-idle', 'state': 'idle'};
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      AndroidRecordingService.commands,
      (call) async => call.method == 'current' ? snapshot : null,
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        AndroidRecordingService.commands,
        null,
      ),
    );
    await tester.pumpWidget(
      XRecorderApp(
        settings: SettingsController(),
        mediaRepository: TestCatalog(),
      ),
    );
    await tester.pumpAndSettle();
    final shell = find.byType(StudioShell);
    final scaffold = find
        .descendant(of: shell, matching: find.byType(Scaffold))
        .first;
    expect(tester.widget<Scaffold>(scaffold).extendBody, isTrue);
    snapshot = {
      'id': 'host-only-paused-session',
      'state': 'paused',
      'width': 1280,
      'height': 720,
    };
    await CaptureScope.of(tester.element(shell)).refresh();
    await tester.pumpAndSettle();
    expect(tester.widget<Scaffold>(scaffold).extendBody, isFalse);
    final stop = find.descendant(
      of: find.byType(CaptureStatusBar),
      matching: find.text('Stop'),
    );
    expect(stop, findsOneWidget);
    expect(
      tester.getBottomRight(stop).dy,
      lessThan(tester.getTopLeft(find.byType(StudioBottomNavigation)).dy),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('missing email app offers localized failure and copy fallback', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      StudioIdentity.channel,
      (_) async => throw PlatformException(
        code: 'unavailable',
        message: '/private/raw-error',
      ),
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(StudioIdentity.channel, null),
    );
    await tester.pumpWidget(const MaterialApp(home: SupportScreen()));
    await tester.ensureVisible(find.text('Send feedback by email'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send feedback by email'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Could not open an app. Check your browser or email app and try again.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('/private/raw-error'), findsNothing);
    await tester.ensureVisible(find.text('Copy email address'));
    await tester.pumpAndSettle();
    expect(find.text('Copy email address').hitTestable(), findsOneWidget);
  });
  testWidgets('missing browser gives localized feedback', (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      StudioIdentity.channel,
      (_) async => throw PlatformException(code: 'unavailable'),
    );
    addTearDown(
      () => messenger.setMockMethodCallHandler(StudioIdentity.channel, null),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openStudioLink(context, StudioIdentity.privacy),
              child: const Text('Open policy'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open policy'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Could not open an app. Check your browser or email app and try again.',
      ),
      findsOneWidget,
    );
  });
  testWidgets(
    'Settings replays introduction without accessing completion preferences',
    (tester) async {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(AndroidOnboardingStore.channel, (
        call,
      ) async {
        calls.add(call);
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          AndroidOnboardingStore.channel,
          null,
        ),
      );
      final settings = SettingsController();
      final mode = settings.themeMode;
      await tester.pumpWidget(
        XRecorderApp(settings: settings, mediaRepository: TestCatalog()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('View introduction'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('View introduction'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(settings.themeMode, mode);
      expect(calls, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'feedback composes reviewed text without collecting diagnostics or media',
    (tester) async {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(StudioIdentity.channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(StudioIdentity.channel, null),
      );
      await tester.pumpWidget(const MaterialApp(home: SupportScreen()));
      await tester.enterText(find.byType(TextField), 'My reviewed feedback');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send feedback by email'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send feedback by email'));
      await tester.pumpAndSettle();
      expect(calls.map((call) => call.method), ['composeEmail']);
      expect(calls.single.arguments, {'text': 'My reviewed feedback'});
      await tester.drag(find.byType(ListView), const Offset(0, 800));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SelectableText && widget.data == StudioIdentity.email,
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Copy email address'));
      await tester.pumpAndSettle();
      expect(find.text('Copy email address'), findsOneWidget);
    },
  );

  testWidgets('modal uses root navigator above nested navigation', (
    tester,
  ) async {
    final root = GlobalKey<NavigatorState>();
    NavigatorState? modalNavigator;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: root,
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showStudioBottomSheet<void>(
                  context: context,
                  builder: (sheet) {
                    modalNavigator = Navigator.of(sheet);
                    return const SizedBox(
                      height: 150,
                      child: Text('Modal content'),
                    );
                  },
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(modalNavigator, same(root.currentState));
    expect(find.byType(ModalBarrier), findsWidgets);
    root.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Modal content'), findsNothing);
  });
}
