import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xrecorder/app/theme/app_theme.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/core/domain/repositories.dart';
import 'package:xrecorder/features/recording/livestream_page.dart';
import 'package:xrecorder/features/recording/recording_service.dart';
import 'package:xrecorder/features/settings/settings_controller.dart';
import 'package:xrecorder/l10n/localization.dart';

import 'fixtures/recorder.dart';

class LiveRecorder extends TestRecorder implements LivestreamRecordingService {
  final liveEvents = StreamController<Map<String, dynamic>>.broadcast();
  final requests = <(String, String)>[];
  Completer<RecordingSession>? pending;
  int normalStarts = 0;
  Map<String, dynamic> status = {'state': 'idle'};
  @override
  Future<Map<String, dynamic>> currentLive() async => status;
  @override
  Stream<Map<String, dynamic>> get liveStates => liveEvents.stream;
  @override
  Future<RecordingSession> start(RecordingSettings settings) {
    normalStarts++;
    return super.start(settings);
  }

  @override
  Future<RecordingSession> startLive(
    RecordingSettings settings, {
    required String serverUrl,
    required String streamKey,
  }) async {
    requests.add((serverUrl, streamKey));
    status = {'sessionId': 'test', 'state': 'awaitingPermission'};
    final result =
        await (pending?.future ??
            Future<RecordingSession>.value(
              make(RecordingState.awaitingPermission),
            ));
    current = result;
    return result;
  }
}

class SavedLiveRecorder extends LiveRecorder
    implements LivestreamDestinationStore {
  Map<String, String>? saved;
  Future<Map<String, String>?>? pendingLoad;
  Completer<void>? pendingSave;
  bool loadFails = false, saveFails = false;
  int saves = 0, forgets = 0;
  @override
  Future<Map<String, String>?> loadLiveDestination() async {
    if (loadFails) throw StateError('test load failure');
    return pendingLoad == null ? saved : await pendingLoad;
  }

  @override
  Future<void> saveLiveDestination({
    required String name,
    required String serverUrl,
    required String streamKey,
  }) async {
    saves++;
    await pendingSave?.future;
    if (saveFails) throw StateError('test save failure');
    saved = {'name': name, 'serverUrl': serverUrl, 'streamKey': streamKey};
  }

  @override
  Future<void> forgetLiveDestination() async {
    forgets++;
    saved = null;
  }
}

Future<void> showSavedLive(
  WidgetTester tester,
  SavedLiveRecorder service, {
  Locale? locale,
  double scale = 1,
}) async {
  final capture = CaptureController(service, onSaved: () {});
  final settings = SettingsController();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    capture.dispose();
    settings.dispose();
    await service.events.close();
    await service.liveEvents.close();
  });
  await tester.pumpWidget(
    SettingsScope(
      controller: settings,
      child: CaptureScope(
        controller: capture,
        child: MaterialApp(
          theme: AppTheme.dark,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const LivestreamPage(),
        ),
      ),
    ),
  );
  await tester.pump();
}

const destination = {
  'name': 'TASK10 destination',
  'serverUrl': 'rtmps://stream.example/live',
  'streamKey': 'private-key',
};

Future<void> pressVisible(WidgetTester tester, String text) async {
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump();
}

void main() {
  for (final locale in ['vi', 'ar']) {
    testWidgets('saved live destination localized at320dp/200% $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = SavedLiveRecorder()..saved = destination;
      await showSavedLive(tester, service, locale: Locale(locale), scale: 2);
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(LivestreamPage));
      final strings = context.l10n;
      expect(find.text(strings.liveTitle), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('live-name')));
      expect(tester.takeException(), isNull);
      await pressVisible(tester, strings.liveSaveDestination);
      await tester.pumpAndSettle();
      expect(service.saves, 1);
      expect(service.requests, isEmpty);
      expect(find.text(strings.liveSaved), findsOneWidget);
      expect(
        Directionality.of(context),
        locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('revealed livestream key is concealed on background', (
    tester,
  ) async {
    final service = SavedLiveRecorder()..saved = destination;
    await showSavedLive(tester, service);
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byKey(const ValueKey('live-key')),
      matching: find.byType(EditableText),
    );
    await tester.ensureVisible(find.byTooltip('Show stream key'));
    await tester.tap(find.byTooltip('Show stream key'));
    await tester.pump();
    expect(tester.widget<EditableText>(field).obscureText, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(tester.widget<EditableText>(field).obscureText, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(field).obscureText, isTrue);
  });

  testWidgets(
    'saved destination waits for load, stays concealed and never auto-starts',
    (tester) async {
      final load = Completer<Map<String, String>?>();
      final service = SavedLiveRecorder()..pendingLoad = load.future;
      await showSavedLive(tester, service);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('live-server')))
            .enabled,
        isFalse,
      );
      await tester.tap(find.text('Start livestream'));
      expect(service.requests, isEmpty);
      load.complete(destination);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('live-name')))
            .controller!
            .text,
        destination['name'],
      );
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byKey(const ValueKey('live-key')),
                matching: find.byType(EditableText),
              ),
            )
            .obscureText,
        isTrue,
      );
      expect(service.requests, isEmpty);
      expect(service.saves, 0);
    },
  );

  testWidgets(
    'saved destination Save is explicit and blocks duplicate writes',
    (tester) async {
      final service = SavedLiveRecorder()
        ..saved = destination
        ..pendingSave = Completer<void>();
      await showSavedLive(tester, service);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('live-name')));
      await tester.enterText(
        find.byKey(const ValueKey('live-name')),
        'Changed',
      );
      expect(service.saves, 0);
      await pressVisible(tester, 'Save destination');
      await tester.tap(find.text('Save destination'));
      await tester.pump();
      expect(service.saves, 1);
      expect(service.saved, destination);
      service.pendingSave!.complete();
      await tester.pumpAndSettle();
      expect(service.saved!['name'], 'Changed');
      expect(find.text('Destination saved on this device.'), findsOneWidget);
      expect(service.requests, isEmpty);
    },
  );

  testWidgets(
    'failed load preserves store and allows manual start; Forget requires confirmation',
    (tester) async {
      final service = SavedLiveRecorder()
        ..saved = destination
        ..loadFails = true;
      await showSavedLive(tester, service);
      await tester.pumpAndSettle();
      expect(service.saved, destination);
      final save = find.widgetWithText(OutlinedButton, 'Save destination');
      expect(tester.widget<OutlinedButton>(save).onPressed, isNull);
      for (final pair in [
        ('live-server', 'rtmps://other.example/live'),
        ('live-key', 'new-key'),
      ]) {
        final field = find.byKey(ValueKey(pair.$1));
        await tester.ensureVisible(field);
        await tester.enterText(field, pair.$2);
      }
      await pressVisible(tester, 'Forget destination');
      // The pending confirmation intentionally holds the operation lock and
      // its progress indicator; wait for the route transition, not global idle.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.forgets, 0);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('live-key')))
            .controller!
            .text,
        'new-key',
      );
      await tester.tap(find.text('Start livestream'));
      await tester.pumpAndSettle();
      expect(service.requests, [('rtmps://other.example/live', 'new-key')]);
      expect(service.saved, destination);
    },
  );

  testWidgets(
    'confirmed Forget clears only the destination; save failure keeps old values',
    (tester) async {
      final service = SavedLiveRecorder()
        ..saved = destination
        ..saveFails = true;
      await showSavedLive(tester, service);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('live-name')));
      await tester.enterText(
        find.byKey(const ValueKey('live-name')),
        'Replacement',
      );
      await pressVisible(tester, 'Save destination');
      await tester.pumpAndSettle();
      expect(service.saved, destination);
      expect(
        find.text(
          'Could not save the destination. The previous saved destination was kept.',
        ),
        findsOneWidget,
      );
      await pressVisible(tester, 'Forget destination');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(
        find.widgetWithText(TextButton, 'Forget destination').last,
      );
      await tester.pumpAndSettle();
      expect(service.forgets, 1);
      expect(service.saved, isNull);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('live-key')))
            .controller!
            .text,
        isEmpty,
      );
      expect(service.requests, isEmpty);
    },
  );

  test(
    'live start shares the recording lock across pending capture requests',
    () async {
      final service = LiveRecorder()..pending = Completer<RecordingSession>();
      final capture = CaptureController(service, onSaved: () {});
      final first = capture.startLive(
        const RecordingSettings(),
        serverUrl: 'rtmp://localhost/live',
        streamKey: 'private-key',
      );
      await capture.startLive(
        const RecordingSettings(),
        serverUrl: 'rtmp://localhost/live',
        streamKey: 'second-key',
      );
      await capture.start(const RecordingSettings());
      expect(service.requests, [('rtmp://localhost/live', 'private-key')]);
      expect(service.normalStarts, 0);
      expect(capture.busy, isTrue);
      service.pending!.complete(
        service.make(RecordingState.awaitingPermission),
      );
      await first;
      capture.dispose();
      await service.events.close();
      await service.liveEvents.close();
    },
  );

  for (final width in [320.0, 411.0]) {
    testWidgets(
      'live form validates, conceals secrets and locks duplicate starts at $width/200%',
      (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = LiveRecorder()..pending = Completer<RecordingSession>();
        final capture = CaptureController(service, onSaved: () {});
        final settings = SettingsController();
        await tester.pumpWidget(
          SettingsScope(
            controller: settings,
            child: CaptureScope(
              controller: capture,
              child: MaterialApp(
                theme: AppTheme.dark,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: const LivestreamPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start livestream'));
        await tester.pumpAndSettle();
        expect(service.requests, isEmpty);
        expect(find.text('Enter a stream key without spaces.'), findsOneWidget);
        final fields = find.byType(TextFormField);
        await tester.ensureVisible(fields.at(0));
        await tester.enterText(fields.at(0), 'rtmp://10.0.2.2:19350/live');
        await tester.ensureVisible(fields.at(1));
        await tester.enterText(fields.at(1), 'private-key');
        bool obscured() => tester
            .widget<EditableText>(
              find.descendant(
                of: fields.at(1),
                matching: find.byType(EditableText),
              ),
            )
            .obscureText;
        expect(obscured(), isTrue);
        await tester.tap(find.byTooltip('Show stream key'));
        await tester.pump();
        expect(obscured(), isFalse);
        await tester.tap(find.text('Start livestream'));
        await tester.pump();
        expect(obscured(), isTrue);
        expect(service.requests.length, 1);
        expect(
          tester
              .widget<FilledButton>(
                find.byWidgetPredicate((widget) => widget is FilledButton),
              )
              .onPressed,
          isNull,
        );
        service.pending!.complete(
          service.make(RecordingState.awaitingPermission),
        );
        await tester.pumpAndSettle();
        expect(find.text('End livestream'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        capture.dispose();
        settings.dispose();
        await service.events.close();
        await service.liveEvents.close();
      },
    );
  }
}
