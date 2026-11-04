import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/domain/models.dart';
import '../../core/domain/repositories.dart';

class AndroidRecordingService implements RecordingService {
  static const commands = MethodChannel('com.xrecorder/capture');
  static const events = EventChannel('com.xrecorder/capture/events');
  static RecordingSession decode(Map<Object?, Object?> data) =>
      RecordingSession(
        id: data['id'] as String? ?? '',
        state: RecordingState.values.firstWhere(
          (s) => s.name == data['state'],
          orElse: () => RecordingState.failed,
        ),
        configSnapshot: RecordingSettings(
          audioSource: AudioSource.mute,
          width: (data['width'] as num?)?.toInt() ?? 0,
          height: (data['height'] as num?)?.toInt() ?? 0,
          fps: (data['fps'] as num?)?.toInt() ?? 30,
          bitrate: (data['bitrate'] as num?)?.toInt() ?? 8000000,
        ),
        startedAt: data['startedAt'] is num && (data['startedAt'] as num) > 0
            ? DateTime.fromMillisecondsSinceEpoch(
                (data['startedAt'] as num).toInt(),
              )
            : null,
        elapsedActive: Duration(
          milliseconds: (data['elapsedMs'] as num?)?.toInt() ?? 0,
        ),
        outputUri: data['outputUri'] is String
            ? Uri.parse(data['outputUri'] as String)
            : null,
        error: data['error'] is String
            ? DomainFailure(FailureCode.io, data['error'] as String)
            : null,
      );
  Future<RecordingSession> _call(String method, [Object? arguments]) async {
    try {
      return decode(
        await commands.invokeMapMethod<Object?, Object?>(method, arguments) ??
            {},
      );
    } on PlatformException catch (e) {
      throw DomainFailure(
        FailureCode.io,
        e.message ?? 'Recording command failed.',
      );
    } on MissingPluginException {
      throw const DomainFailure(
        FailureCode.unavailable,
        'Screen recording requires Android.',
      );
    }
  }

  @override
  Stream<RecordingSession> get sessions => events.receiveBroadcastStream().map(
    (value) => decode(value as Map<Object?, Object?>),
  );
  @override
  Future<RecordingSession?> currentSession() async => _call('current');
  @override
  Future<RecordingSession> start(RecordingSettings settings) => _call('start');
  @override
  Future<void> stop(String sessionId) async {
    await _call('stop', {'sessionId': sessionId});
  }

  @override
  Future<void> cancel(String sessionId) async {
    await _call('cancel', {'sessionId': sessionId});
  }

  @override
  Future<void> pause(String sessionId) => Future.error(
    const DomainFailure(FailureCode.unavailable, 'Pause is not enabled yet.'),
  );
  @override
  Future<void> resume(String sessionId) => Future.error(
    const DomainFailure(FailureCode.unavailable, 'Resume is not enabled yet.'),
  );
}

class CaptureController extends ChangeNotifier with WidgetsBindingObserver {
  CaptureController(this.service, {required this.onSaved}) {
    WidgetsBinding.instance.addObserver(this);
    subscription = service.sessions.listen(
      _receive,
      onError: (Object e) {
        error = 'Recording service is unavailable.';
        _notify();
      },
    );
    refresh();
  }
  final RecordingService service;
  final VoidCallback onSaved;
  late final StreamSubscription<RecordingSession> subscription;
  RecordingSession? session;
  String? error;
  String? _savedId;
  String? dismissedId;
  bool _disposed = false;
  bool get busy =>
      session != null &&
      ![
        RecordingState.idle,
        RecordingState.completed,
        RecordingState.failed,
      ].contains(session!.state);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _receive(RecordingSession value) {
    session = value;
    error = value.error?.message;
    if (value.state == RecordingState.completed &&
        value.outputUri != null &&
        value.id != _savedId) {
      _savedId = value.id;
      onSaved();
    }
    _notify();
  }

  Future<void> refresh() async {
    try {
      final value = await service.currentSession();
      if (value != null && !_disposed) _receive(value);
    } catch (_) {}
  }

  Future<void> start(RecordingSettings settings) async {
    if (busy) return;
    error = null;
    dismissedId = null;
    try {
      _receive(await service.start(settings));
    } catch (e) {
      error = e.toString();
      _notify();
      rethrow;
    }
  }

  Future<void> stop() async {
    final value = session;
    if (value == null) return;
    try {
      await service.stop(value.id);
      await refresh();
    } catch (e) {
      error = e.toString();
      _notify();
    }
  }

  void dismiss() {
    dismissedId = session?.id;
    _notify();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    subscription.cancel();
    super.dispose();
  }
}

class CaptureScope extends InheritedNotifier<CaptureController> {
  const CaptureScope({
    super.key,
    required CaptureController controller,
    required super.child,
  }) : super(notifier: controller);
  static CaptureController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CaptureScope>()!.notifier!;
}

class CaptureStatusBar extends StatelessWidget {
  const CaptureStatusBar({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = CaptureScope.of(context);
    final session = controller.session;
    if (session == null ||
        session.state == RecordingState.idle ||
        controller.dismissedId == session.id) {
      return const SizedBox.shrink();
    }
    final active = controller.busy;
    final completed = session.state == RecordingState.completed;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                controller.error ??
                    (completed
                        ? 'Recording saved'
                        : '${session.state.name} · ${session.elapsedActive.inSeconds}s'),
              ),
            ),
            if (active)
              TextButton(onPressed: controller.stop, child: const Text('Stop')),
            if (completed && session.outputUri != null)
              TextButton(
                onPressed: () => context.push(
                  '/media/${Uri.encodeComponent(session.outputUri.toString())}',
                ),
                child: const Text('View'),
              ),
            if (!active)
              IconButton(
                tooltip: 'Dismiss recording status',
                onPressed: controller.dismiss,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ),
    );
  }
}
