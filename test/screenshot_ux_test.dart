import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xrecorder/app/theme/app_theme.dart';
import 'package:xrecorder/core/domain/models.dart';
import 'package:xrecorder/features/recording/recording_service.dart';

import 'fixtures/recorder.dart';

class ScreenshotRecorder extends TestRecorder {
  int shots = 0;
  Object? failure;
  Completer<RecordingSession>? pending;
  RecordingSession shot(
    RecordingState state, {
    Uri? output,
    String id = 'shot',
    String? error,
  }) => RecordingSession(
    id: id,
    state: state,
    screenshot: true,
    configSnapshot: const RecordingSettings(),
    elapsedActive: Duration.zero,
    countdownRemaining: const Duration(seconds: 3),
    outputUri: output,
    error: error == null ? null : DomainFailure(FailureCode.io, error),
  );
  void emit(
    RecordingState state, {
    Uri? output,
    String id = 'shot',
    String? error,
  }) {
    current = shot(state, output: output, id: id, error: error);
    events.add(current!);
  }

  @override
  Future<RecordingSession> screenshot() async {
    shots++;
    if (failure case final Object error) throw error;
    return pending?.future ??
        (current = shot(RecordingState.awaitingPermission));
  }

  @override
  Future<void> cancel(String id) async => emit(RecordingState.idle);
}

class _TestLifetime extends StatefulWidget {
  const _TestLifetime({
    required this.capture,
    required this.router,
    required this.service,
    required this.child,
  });
  final CaptureController capture;
  final GoRouter router;
  final ScreenshotRecorder service;
  final Widget child;
  @override
  State<_TestLifetime> createState() => _TestLifetimeState();
}

class _TestLifetimeState extends State<_TestLifetime> {
  @override
  Widget build(BuildContext context) => widget.child;
  @override
  void dispose() {
    widget.capture.dispose();
    widget.router.dispose();
    unawaited(widget.service.events.close());
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
  });
  Future<(ScreenshotRecorder, CaptureController, GoRouter)> start(
    WidgetTester tester, {
    double width = 411,
    double scale = 1,
    bool dark = false,
  }) async {
    tester.view.physicalSize = Size(width, 850);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final service = ScreenshotRecorder()
      ..current = const RecordingSession(
        id: '',
        state: RecordingState.idle,
        configSnapshot: RecordingSettings(),
        elapsedActive: Duration.zero,
      );
    final capture = CaptureController(service, onSaved: () {});
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: CaptureStatusBar(),
            ),
            bottomNavigationBar: SizedBox(
              height: 80,
              child: Text('Navigation'),
            ),
          ),
        ),
        GoRoute(
          path: '/photo-preview/:uri',
          builder: (_, state) =>
              Scaffold(body: Text(state.pathParameters['uri']!)),
        ),
      ],
    );
    await tester.pumpWidget(
      _TestLifetime(
        capture: capture,
        router: router,
        service: service,
        child: CaptureScope(
          controller: capture,
          child: MaterialApp.router(
            theme: dark ? AppTheme.dark : AppTheme.light,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
    });
    return (service, capture, router);
  }

  final uri = Uri.parse('content://media/external/images/media/321');
  testWidgets(
    'native capture stream shares one subscription across observers',
    (tester) async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.xrecorder/capture/events'),
            (call) async {
              calls.add(call.method);
              return null;
            },
          );
      final a = <RecordingSession>[], b = <RecordingSession>[];
      final one = AndroidRecordingService().sessions.listen(a.add);
      final two = AndroidRecordingService().sessions.listen(b.add);
      await tester.pump();
      tester.binding.channelBuffers.push(
        AndroidRecordingService.events.name,
        const StandardMethodCodec().encodeSuccessEnvelope({
          'id': 'broadcast',
          'state': 'countdown',
          'screenshot': true,
          'countdownRemaining': 3,
        }),
        (_) {},
      );
      await tester.pump();
      expect(a.single.state, RecordingState.countdown);
      expect(b.single.state, RecordingState.countdown);
      expect(calls.where((v) => v == 'listen'), hasLength(1));
      await tester.runAsync(() => one.cancel());
      expect(calls.where((v) => v == 'cancel'), isEmpty);
      await tester.runAsync(() => two.cancel());
      expect(calls.where((v) => v == 'cancel'), hasLength(1));
    },
  );
  for (final width in [320.0, 411.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets(
          'compact notice fits $width scale=$scale dark=$dark with accessible controls',
          (tester) async {
            final (service, _, _) = await start(
              tester,
              width: width,
              scale: scale,
              dark: dark,
            );
            service.emit(RecordingState.completed, output: uri);
            await tester.pumpAndSettle();
            expect(find.text('Screenshot saved'), findsOneWidget);
            expect(find.text('Stop'), findsNothing);
            final card = tester.getRect(find.byType(CaptureFeedbackCard));
            final nav = tester.getRect(find.text('Navigation'));
            expect(card.bottom, lessThanOrEqualTo(nav.top));
            expect(card.right, lessThanOrEqualTo(width));
            for (final control in [
              find.text('View'),
              find.byTooltip('Dismiss capture notification'),
            ]) {
              expect(
                tester.getRect(control).right,
                lessThanOrEqualTo(width - 16),
              );
            }
            if (scale == 1) expect(card.height, lessThanOrEqualTo(80));
            final semantics = tester.ensureSemantics();
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            semantics.dispose();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
  testWidgets(
    'saved notice expires after 5 seconds and duplicate events cannot resurrect it',
    (tester) async {
      final (service, capture, _) = await start(tester);
      service.emit(RecordingState.completed, output: uri);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 4999));
      expect(find.text('Screenshot saved'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Screenshot saved'), findsNothing);
      service.emit(RecordingState.completed, output: uri);
      await capture.refresh();
      await tester.pump();
      expect(capture.feedback, isNull);
      expect(capture.busy, isFalse);
    },
  );
  testWidgets(
    'View opens the exact saved image and closes feedback immediately',
    (tester) async {
      final (service, capture, _) = await start(tester);
      service.emit(RecordingState.completed, output: uri);
      await tester.pumpAndSettle();
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.text(uri.toString()), findsOneWidget);
      expect(capture.feedback, isNull);
    },
  );
  testWidgets(
    'close dismisses immediately without opening or replaying feedback',
    (tester) async {
      final (service, capture, router) = await start(tester);
      service.emit(RecordingState.completed, output: uri);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Dismiss capture notification'));
      await tester.pump();
      expect(capture.feedback, isNull);
      expect(router.canPop(), isFalse);
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('Screenshot saved'), findsNothing);
    },
  );
  testWidgets(
    'screenshot phases never expose recording controls and countdown can cancel',
    (tester) async {
      final (service, capture, _) = await start(tester);
      await capture.screenshot();
      await tester.pump();
      for (final state in [
        RecordingState.awaitingPermission,
        RecordingState.countdown,
        RecordingState.starting,
        RecordingState.finalizing,
      ]) {
        service.emit(state);
        await tester.pumpAndSettle();
        for (final label in [
          'Stop',
          'Pause',
          'Resume',
          'Processing',
          '00:00',
        ]) {
          expect(find.text(label), findsNothing);
        }
        expect(
          find.text('Cancel'),
          state == RecordingState.countdown ? findsOneWidget : findsNothing,
        );
      }
      service.emit(RecordingState.countdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(capture.busy, isFalse);
      expect(find.text('Screenshot cancelled.'), findsOneWidget);
      expect(find.text('Screenshot saved'), findsNothing);
    },
  );
  testWidgets(
    'denied consent has no output; failures are friendly; a second capture still works',
    (tester) async {
      final (service, capture, _) = await start(tester);
      await capture.screenshot();
      service.emit(RecordingState.idle);
      await tester.pumpAndSettle();
      expect(capture.session!.outputUri, isNull);
      expect(find.text('Screenshot cancelled.'), findsOneWidget);
      service.emit(
        RecordingState.failed,
        id: 'storage-shot',
        error: 'Storage full PlatformException secret_method',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Free some storage'), findsOneWidget);
      expect(find.textContaining('PlatformException'), findsNothing);
      expect(find.text('Stop'), findsNothing);
      service.emit(RecordingState.awaitingPermission, id: 'second-shot');
      service.emit(RecordingState.completed, id: 'second-shot', output: uri);
      await tester.pumpAndSettle();
      expect(find.text('Screenshot saved'), findsOneWidget);
    },
  );
  testWidgets(
    'background completion gets five visible seconds on return, then expires',
    (tester) async {
      final (service, capture, _) = await start(tester);
      capture.didChangeAppLifecycleState(AppLifecycleState.paused);
      service.emit(RecordingState.completed, output: uri);
      await tester.pump(const Duration(seconds: 8));
      expect(capture.feedback, isNotNull);
      capture.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(capture.feedback, isNull);
    },
  );
  testWidgets(
    'pending request blocks repeated taps; late acknowledgement cannot restart a completed shot',
    (tester) async {
      final (service, capture, _) = await start(tester);
      final pending = service.pending = Completer<RecordingSession>();
      final first = capture.screenshot();
      await capture.screenshot();
      expect(service.shots, 1);
      expect(capture.busy, isTrue);
      service.emit(RecordingState.completed, output: uri);
      await tester.pump();
      pending.complete(service.shot(RecordingState.awaitingPermission));
      await first;
      expect(capture.session!.state, RecordingState.completed);
      expect(capture.busy, isFalse);
    },
  );
  testWidgets(
    'command failure has one friendly feedback owner without false success',
    (tester) async {
      final (service, capture, _) = await start(tester);
      service.failure = const DomainFailure(
        FailureCode.io,
        'NativeCaptureException private_method',
      );
      await capture.screenshot();
      await tester.pumpAndSettle();
      expect(capture.busy, isFalse);
      expect(find.byType(CaptureFeedbackCard), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.textContaining('private_method'), findsNothing);
      expect(find.text('Screenshot saved'), findsNothing);
    },
  );

  testWidgets('historical saved session is not reannounced on app startup', (
    tester,
  ) async {
    final service = ScreenshotRecorder();
    service.current = service.shot(RecordingState.completed, output: uri);
    final capture = CaptureController(service, onSaved: () {});
    await tester.pump();
    expect(capture.feedback, isNull);
    expect(capture.busy, isFalse);
    capture.dispose();
    await service.events.close();
  });
}
