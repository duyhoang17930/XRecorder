import 'dart:convert';
import 'dart:io';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xrecorder/app/app.dart';
import 'package:xrecorder/core/persistence/settings_store.dart';
import 'package:xrecorder/features/editor/project_repository.dart';
import 'package:xrecorder/features/recording/recording_service.dart';
import 'package:xrecorder/features/settings/help_screen.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';

import 'fixtures/catalog.dart';
import 'fixtures/interaction_probe.dart';

class _Store implements SettingsStore {
  String? document;
  bool failRead = false, failWrite = false;
  int writes = 0;
  @override
  Future<String?> read() async {
    if (failRead) throw const FormatException('QA unreadable preferences');
    return document;
  }

  @override
  Future<void> write(String value) async {
    if (failWrite) throw const FileSystemException('QA storage failure');
    writes++;
    document = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final probe = InteractionProbe('widget / mocked native commands');
  late SettingsController settings;
  late _Store store;
  late GoRouter router;

  setUp(() {
    messenger.setMockMethodCallHandler(
      AndroidRecordingService.commands,
      (call) async =>
          call.method == 'current' ? {'id': '', 'state': 'idle'} : null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.xrecorder/capture/events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      AndroidEditProjectRepository.channel,
      (call) async => switch (call.method) {
        'list' => <String>[],
        'exportList' => '[]',
        _ => null,
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.xrecorder/media'),
      (call) async => call.method == 'listTrash' ? <Object>[] : null,
    );
  });
  tearDown(() {
    for (final channel in [
      AndroidRecordingService.commands,
      const MethodChannel('com.xrecorder/capture/events'),
      const MethodChannel('com.xrecorder/media'),
      const MethodChannel('com.xrecorder/support'),
      AndroidEditProjectRepository.channel,
    ]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });
  tearDownAll(() {
    final path = Platform.environment['TASK09B_WIDGET_EVIDENCE'];
    if (path != null) {
      final output = File(path)..createSync(exclusive: true);
      output.writeAsStringSync(probe.encode(), encoding: utf8, flush: true);
    }
  });

  Future<void> start(WidgetTester tester, {_Store? fixture}) async {
    tester.view.physicalSize = const Size(411, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    store = fixture ?? _Store();
    settings = SettingsController(store: store);
    await settings.restore();
    await tester.pumpWidget(
      XRecorderApp(settings: settings, mediaRepository: TestCatalog()),
    );
    await tester.pumpAndSettle();
    router = GoRouter.of(tester.element(find.text('Video Library')));
    router.go('/settings');
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scroll.position.jumpTo(scroll.position.minScrollExtent);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        target,
        180,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 40,
      );
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    await reveal(tester, target);
    expect(target.hitTestable(), findsOneWidget);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Settings About rapid taps open one dialog and one close returns',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await start(tester);
        final about = find.text('About & licenses');
        await reveal(tester, about);
        await probe.step(
          tester,
          id: 'G1-S-ABOUT-RAPID',
          route: '/settings',
          state: 'about row visible',
          locator: 'text:About & licenses',
          expected: 'One AboutDialog, one Close returns to Settings',
          action: () async {
            final node = tester.getSemantics(about);
            final owner =
                tester.binding.renderViews.first.owner!.semanticsOwner!;
            owner.performAction(node.id, SemanticsAction.tap);
            owner.performAction(node.id, SemanticsAction.tap);
            await tester.pumpAndSettle();
          },
          verify: () => expect(
            find.byType(AboutDialog, skipOffstage: false),
            findsOneWidget,
          ),
        );
        await tap(tester, find.text('Close'));
        expect(find.byType(AboutDialog, skipOffstage: false), findsNothing);
        expect(store.writes, 0);
      } finally {
        await tester.pumpWidget(const SizedBox());
        semantics.dispose();
      }
    },
  );

  testWidgets('rapid Settings Help taps create one destination page', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await start(tester);
      final help = find.text('Help & guides');
      await reveal(tester, help);
      await tester.tap(help);
      await tester.tap(help);
      await tester.pumpAndSettle();
      expect(find.byType(HelpScreen, skipOffstage: false), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(HelpScreen, skipOffstage: false), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    }
  });

  testWidgets(
    'Settings shared rows navigate, details dismiss, and reads do not save',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await start(tester);
        for (final row in [
          ('Media storage', 'Close'),
          ('Privacy', 'Close'),
          ('Trash & restore', 'Trash'),
          ('Export queue', 'Exports'),
          ('Help & guides', 'Help & guides'),
          ('Feedback', 'Feedback & issue report'),
        ]) {
          await probe.step(
            tester,
            id: 'G1-S-ROW-${row.$1}',
            route: '/settings',
            state: 'landing/${row.$1}',
            locator: 'text:${row.$1}',
            expected: 'Opens ${row.$2}; no preferences write',
            action: () => tap(tester, find.text(row.$1)),
            verify: () {
              expect(find.text(row.$2), findsAtLeastNWidgets(1));
              expect(store.writes, 0);
            },
          );
          if (row.$2 == 'Close') {
            await tap(tester, find.text('Close'));
          } else {
            router.pop();
            await tester.pumpAndSettle();
          }
        }
        expect(store.document, isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'Settings reset Cancel and barrier keep values, explicit Reset persists',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await start(tester);
        await tap(tester, find.text('Light'));
        await settings.flushed;
        final before = store.document;
        for (final dismiss in ['Cancel', 'barrier', 'back']) {
          await tap(tester, find.text('Reset preferences'));
          expect(find.text('Reset preferences?'), findsOneWidget);
          if (dismiss == 'Cancel') {
            await tap(tester, find.text('Cancel'));
          } else if (dismiss == 'barrier') {
            await tester.tapAt(const Offset(5, 5));
            await tester.pumpAndSettle();
          } else {
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
          }
          expect(find.text('Reset preferences?'), findsNothing);
          expect(store.document, before);
        }
        await tap(tester, find.text('Reset preferences'));
        await tap(tester, find.text('Reset'));
        await settings.flushed;
        final restored = SettingsController(store: store);
        await restored.restore();
        expect(restored.themeMode, ThemeMode.dark);
        expect(restored.appLocale, isNull);
        restored.dispose();
        probe.actions.add({
          'id': 'G1-S-RESET',
          'route': '/settings',
          'locator': 'Reset preferences/Cancel/Reset/barrier/Back',
          'expected': 'Cancel keeps document, Reset durable',
          'actual': 'Assertions passed',
          'modality': probe.modality,
          'owner': 'Shared/P2; recording reset semantics excluded',
          'status': 'PASS',
        });
      } finally {
        await tester.pumpWidget(const SizedBox());
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'About licenses returns to one dialog, then barrier dismisses it',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await start(tester);
        await probe.step(
          tester,
          id: 'G1-LICENSES',
          route: '/settings',
          state: 'about',
          locator: 'About & licenses/View licenses/Back/barrier',
          expected: 'LicensePage returns to About; barrier returns to Settings without writes',
          action: () async {
            await tap(tester, find.text('About & licenses'));
            await tap(tester, find.text('View licenses'));
            expect(find.byType(LicensePage), findsOneWidget);
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            expect(find.byType(AboutDialog), findsOneWidget);
            await tester.tapAt(const Offset(5, 5));
            await tester.pumpAndSettle();
          },
          verify: () {
            expect(find.byType(AboutDialog), findsNothing);
            expect(store.writes, 0);
          },
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        semantics.dispose();
      }
    },
  );

  testWidgets('Settings language search selection and all themes persist', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await start(tester);
      for (final mode in ['Light', 'System', 'Dark']) {
        await probe.step(
          tester,
          id: 'G1-THEME-$mode',
          route: '/settings',
          state: mode,
          locator: 'text:$mode',
          expected: 'Theme persists after fresh controller restore',
          action: () async {
            await tap(tester, find.text(mode));
            await settings.flushed;
          },
          verify: () => expect(settings.themeMode.name, mode.toLowerCase()),
        );
        final restored = SettingsController(store: store);
        await restored.restore();
        expect(restored.themeMode, settings.themeMode);
        restored.dispose();
      }
      await probe.step(
        tester,
        id: 'G1-LANGUAGE',
        route: '/settings',
        state: 'system',
        locator: 'App language/Search languages/fr',
        expected: 'Search filters, French saved and localized Settings renders',
        action: () async {
          await tap(tester, find.text('App language'));
          await tester.enterText(find.byType(TextField), 'fr');
          await tester.pumpAndSettle();
          expect(find.text('English'), findsNothing);
          await tap(tester, find.text('Français'));
          await settings.flushed;
        },
        verify: () => expect(settings.appLocale?.languageCode, 'fr'),
      );
      final restored = SettingsController(store: store);
      await restored.restore();
      expect(restored.appLocale, const Locale('fr'));
      restored.dispose();
    } finally {
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    }
  });

  testWidgets(
    'Settings read failure never overwrites and retries, save failure retries',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final fixture = _Store()..failRead = true;
        await start(tester, fixture: fixture);
        expect(settings.canSave, isFalse);
        await tap(tester, find.text('Light'));
        await settings.flushed;
        expect(store.writes, 0);
        fixture.failRead = false;
        await probe.step(
          tester,
          id: 'G1-RETRY-LOAD',
          route: '/settings',
          state: 'read failure injected',
          locator: 'Retry loading',
          expected: 'Retry clears error and enables persistence without replacing old document',
          action: () => tap(tester, find.text('Retry loading')),
          verify: () {
            expect(settings.persistenceError, isNull);
            expect(settings.canSave, isTrue);
          },
        );
        fixture.failWrite = true;
        await tap(tester, find.text('Dark'));
        await settings.flushed;
        await tester.pumpAndSettle();
        expect(settings.persistenceError, isNotNull);
        await reveal(tester, find.text('Retry saving'));
        expect(find.text('Retry saving'), findsOneWidget);
        fixture.failWrite = false;
        await probe.step(
          tester,
          id: 'G1-RETRY-SAVE',
          route: '/settings',
          state: 'write failure injected',
          locator: 'Retry saving',
          expected: 'Retry durably saves intended theme and clears warning',
          action: () async {
            await tap(tester, find.text('Retry saving'));
            await settings.flushed;
          },
          verify: () {
            expect(settings.persistenceError, isNull);
            expect(store.document, contains('dark'));
          },
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        semantics.dispose();
      }
    },
  );

  testWidgets('Support attachment cancel replace remove and permission retry', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var picks = 0;
    final replies = <Object?>[
      null,
      'content://qa/first',
      null,
      PlatformException(code: 'permission_denied'),
      'content://qa/replacement',
    ];
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.xrecorder/support'),
      (call) async {
        if (call.method == 'pickAttachment') {
          final reply = replies[picks++];
          if (reply is PlatformException) throw reply;
          return reply;
        }
        return null;
      },
    );
    try {
      await start(tester);
      await tap(tester, find.text('Feedback'));
      for (var i = 0; i < replies.length; i++) {
        await probe.step(
          tester,
          id: 'G1-ATTACH-$i',
          route: '/support',
          state: 'reply $i',
          locator: 'attachment button',
          expected: 'Cancel retains selection; denial permits retry; successful replacement stays removable',
          action: () => tap(
            tester,
            find.text(
              i < 2
                  ? 'Attach image or video (up to 25 MB)'
                  : 'Replace selected attachment',
            ),
          ),
          verify: () {
            expect(picks, i + 1);
            expect(
              find.text('Remove attachment'),
              i == 0 ? findsNothing : findsOneWidget,
            );
          },
        );
      }
      await tap(tester, find.text('Remove attachment'));
      expect(find.text('Remove attachment'), findsNothing);
      expect(find.text('Attach image or video (up to 25 MB)'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    }
  });
}
