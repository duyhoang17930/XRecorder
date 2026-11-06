import '../../core/widgets/studio_widgets.dart';
import 'capture_status_presentation.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/domain/models.dart';
import '../../core/domain/repositories.dart';

class AndroidRecordingService implements RecordingService {
  static const commands = MethodChannel('com.xrecorder/capture');
  static const events = EventChannel('com.xrecorder/capture/events');
  // One native subscription, shared by every observer/service instance.
  static final Stream<RecordingSession> _sessions = events
      .receiveBroadcastStream()
      .map((value) => decode(value as Map<Object?, Object?>));
  static RecordingSession decode(Map<Object?, Object?> data) {
    final config = (data['config'] as Map<Object?, Object?>?) ?? data;
    return RecordingSession(
      id: data['id'] as String? ?? '',
      screenshot: data['screenshot'] == true,
      state: RecordingState.values.firstWhere(
        (s) => s.name == data['state'],
        orElse: () => RecordingState.failed,
      ),
      configSnapshot: RecordingSettings(
        audioSource: AudioSource.values.firstWhere(
          (a) => a.name == config['audio'],
          orElse: () => AudioSource.mute,
        ),
        width: (config['width'] as num?)?.toInt() ?? 0,
        height: (config['height'] as num?)?.toInt() ?? 0,
        fps: (config['fps'] as num?)?.toInt() ?? 30,
        bitrate: (config['bitrate'] as num?)?.toInt() ?? 8000000,
        codec: config['codec'] == 'hevc' ? VideoCodec.hevc : VideoCodec.avc,
        orientation: CaptureOrientation.values.firstWhere(
          (o) => o.name == config['orientation'],
          orElse: () => CaptureOrientation.automatic,
        ),
        mode: config['mode'] == 'performance'
            ? RecordingMode.performance
            : RecordingMode.normal,
        countdown: Duration(
          seconds: (config['countdown'] as num?)?.toInt() ?? 0,
        ),
        durationLimit: (config['durationSeconds'] as num?) == 0
            ? null
            : Duration(
                seconds: (config['durationSeconds'] as num?)?.toInt() ?? 0,
              ),
        micGain: (config['micGain'] as num?)?.toDouble() ?? 1,
        internalGain: (config['internalGain'] as num?)?.toDouble() ?? 1,
        noiseReduction: config['noiseReduction'] == true,
        facecam: config['facecam'] == true,
      ),
      startedAt: data['startedAt'] is num && (data['startedAt'] as num) > 0
          ? DateTime.fromMillisecondsSinceEpoch(
              (data['startedAt'] as num).toInt(),
            )
          : null,
      elapsedActive: Duration(
        milliseconds: (data['elapsedMs'] as num?)?.toInt() ?? 0,
      ),
      countdownRemaining: Duration(
        seconds: (data['countdownRemaining'] as num?)?.toInt() ?? 0,
      ),
      outputUri: data['outputUri'] is String
          ? Uri.parse(data['outputUri'] as String)
          : null,
      error: data['error'] is String
          ? DomainFailure(FailureCode.io, data['error'] as String)
          : null,
    );
  }

  @override
  Future<RecordingCapabilities> capabilities() async {
    try {
      final data =
          await commands.invokeMapMethod<Object?, Object?>('capabilities') ??
          {};
      return RecordingCapabilities(
        audioSources: ((data['audioSources'] as List<Object?>?) ?? [])
            .map((value) => AudioSource.values.byName(value as String))
            .toSet(),
        configurations: ((data['presets'] as List<Object?>?) ?? []).map((
          value,
        ) {
          final p = value as Map<Object?, Object?>;
          return VideoConfiguration(
            width: (p['width'] as num).toInt(),
            height: (p['height'] as num).toInt(),
            fps: (p['fps'] as num).toInt(),
            codec: p['codec'] == 'hevc' ? VideoCodec.hevc : VideoCodec.avc,
          );
        }).toList(),
        noiseReduction: data['noiseReduction'] == true,
        hevc: data['hevc'] == true,
        facecam: data['facecam'] == true,
      );
    } on MissingPluginException {
      throw const DomainFailure(
        FailureCode.unavailable,
        'Recording capabilities require Android.',
      );
    }
  }

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
  Stream<RecordingSession> get sessions => _sessions;
  @override
  Future<RecordingSession?> currentSession() async => _call('current');
  @override
  Future<RecordingSession> screenshot() => _call('screenshot');
  @override
  Future<RecordingSession> start(RecordingSettings settings) async {
    final supported = await capabilities();
    return _call('start', {
      'width': settings.width,
      'height': settings.height,
      'fps': settings.fps,
      'bitrate': settings.bitrate,
      'codec': settings.codec.name,
      'audio': settings.audioSource.name,
      'micGain': settings.micGain,
      'internalGain': settings.internalGain,
      'noiseReduction': settings.noiseReduction && supported.noiseReduction,
      'facecam': settings.facecam,
      'countdown': settings.countdown.inSeconds,
      'durationSeconds': settings.durationLimit?.inSeconds ?? 0,
      'orientation': settings.orientation.name,
      'mode': settings.mode.name,
    });
  }

  @override
  Future<void> stop(String sessionId) async {
    await _call('stop', {'sessionId': sessionId});
  }

  @override
  Future<void> cancel(String sessionId) async {
    await _call('cancel', {'sessionId': sessionId});
  }

  @override
  Future<void> pause(String sessionId) async {
    await _call('pause', {'sessionId': sessionId});
  }

  @override
  Future<void> resume(String sessionId) async {
    await _call('resume', {'sessionId': sessionId});
  }
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
  bool _requesting = false;
  bool _receivedSession = false;
  bool _foreground = true;
  Timer? _feedbackTimer;
  CaptureFeedback? feedback;
  String? _terminalId;
  bool get busy =>
      _requesting ||
      (session != null &&
          ![
            RecordingState.idle,
            RecordingState.completed,
            RecordingState.failed,
          ].contains(session!.state));
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _receive(RecordingSession value) {
    if (_disposed) return;
    final previous = session;
    final announce = _receivedSession || _requesting;
    _receivedSession = true;
    if (previous?.id == value.id &&
        previous?.screenshot == true &&
        previous?.state == RecordingState.completed &&
        ![
          RecordingState.completed,
          RecordingState.idle,
        ].contains(value.state)) {
      return; // A late command acknowledgement cannot resurrect a finished shot.
    }
    session = value;
    error = value.error?.message;
    if (![
      RecordingState.idle,
      RecordingState.completed,
      RecordingState.failed,
    ].contains(value.state)) {
      _clearFeedback();
    }
    if (value.state == RecordingState.completed &&
        value.outputUri != null &&
        value.id != _savedId) {
      _savedId = value.id;
      onSaved();
      if (announce) {
        _showFeedback(
          CaptureFeedback(
            id: value.id,
            notice: UserNotice(
              value.screenshot ? 'Screenshot saved' : 'Video saved',
              kind: NoticeKind.success,
            ),
            output: value.outputUri,
            screenshot: value.screenshot,
          ),
        );
      }
    } else if (value.screenshot &&
        announce &&
        _terminalId != value.id &&
        (value.state == RecordingState.failed ||
            (value.state == RecordingState.idle &&
                previous?.id == value.id &&
                previous?.screenshot == true &&
                previous?.state != RecordingState.idle))) {
      _showFeedback(
        CaptureFeedback(
          id: value.id,
          notice: value.state == RecordingState.failed
              ? UserMessages.failure(
                  value.error,
                  operation: UserOperation.screenshot,
                )
              : const UserNotice(
                  'Screenshot cancelled.',
                  kind: NoticeKind.info,
                ),
          screenshot: true,
        ),
      );
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
    _requesting = true;
    _clearFeedback();
    error = null;
    dismissedId = null;
    try {
      _receive(await service.start(settings));
    } catch (e) {
      error = e.toString();
      _notify();
      rethrow;
    } finally {
      _requesting = false;
      _notify();
    }
  }

  Future<void> screenshot() async {
    if (busy) return;
    _requesting = true;
    _clearFeedback();
    error = null;
    dismissedId = null;
    try {
      _receive(await service.screenshot());
    } catch (e) {
      if (e is DomainFailure ||
          e is PlatformException ||
          e is MissingPluginException) {
        if (!_disposed) {
          _showFeedback(
            CaptureFeedback(
              id: session?.id ?? 'screenshot-request',
              notice: UserMessages.failure(
                e,
                operation: UserOperation.screenshot,
              ),
              screenshot: true,
            ),
          );
          _notify();
        }
        return; // One UI owner for operational failures; avoid a second snackbar.
      }
      error = e.toString();
      _notify();
      rethrow;
    } finally {
      _requesting = false;
      _notify();
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
    _clearFeedback();
    _notify();
  }

  void _clearFeedback() {
    _feedbackTimer?.cancel();
    feedback = null;
  }

  void _showFeedback(CaptureFeedback value) {
    _clearFeedback();
    _terminalId = value.id;
    feedback = value;
    _armFeedback();
  }

  void _armFeedback() {
    _feedbackTimer?.cancel();
    if (!_foreground || feedback == null || _disposed) return;
    _feedbackTimer = Timer(
      feedback!.notice.kind == NoticeKind.error
          ? const Duration(seconds: 10)
          : const Duration(seconds: 5),
      () {
        feedback = null;
        _notify();
      },
    );
  }

  Future<void> cancelScreenshot() async {
    final value = session;
    if (value?.screenshot != true || value?.state != RecordingState.countdown) {
      return;
    }
    try {
      await service.cancel(value!.id);
      await refresh();
    } catch (e) {
      if (!_disposed) {
        _showFeedback(
          CaptureFeedback(
            id: value!.id,
            notice: UserMessages.failure(
              e,
              operation: UserOperation.screenshot,
            ),
            screenshot: true,
          ),
        );
        _notify();
      }
    }
  }

  Future<void> togglePause() async {
    final value = session;
    if (value == null) return;
    try {
      if (value.state == RecordingState.paused) {
        await service.resume(value.id);
      } else if (value.state == RecordingState.recording) {
        await service.pause(value.id);
      }
      await refresh();
    } catch (e) {
      error = e.toString();
      _notify();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.resumed) {
      if (!_foreground) _armOnResume();
      refresh();
    } else {
      _foreground = false;
      _feedbackTimer?.cancel();
    }
  }

  void _armOnResume() {
    _foreground = true;
    _armFeedback();
  }

  @override
  void dispose() {
    _disposed = true;
    _feedbackTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    subscription.cancel();
    super.dispose();
  }
}

class CaptureFeedback {
  const CaptureFeedback({
    required this.id,
    required this.notice,
    this.output,
    this.screenshot = false,
  });
  final String id;
  final UserNotice notice;
  final Uri? output;
  final bool screenshot;
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
    if (controller.feedback case final CaptureFeedback feedback) {
      return CaptureFeedbackCard(
        feedback: feedback,
        onDismiss: controller.dismiss,
      );
    }
    if (session == null ||
        session.state == RecordingState.idle ||
        controller.dismissedId == session.id) {
      return const SizedBox.shrink();
    }
    if (session.screenshot) {
      if (session.state != RecordingState.countdown) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: StudioCard(
          padding: const EdgeInsets.only(left: 16, right: 4),
          child: Row(
            children: [
              Text(
                '${session.countdownRemaining.inSeconds}',
                style: AppTypography.headline.copyWith(
                  color: context.studioColors.primary,
                ),
                semanticsLabel:
                    'Screenshot in ${session.countdownRemaining.inSeconds} seconds',
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Switch to the screen you want')),
              TextButton(
                onPressed: controller.cancelScreenshot,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
    }
    if (session.state == RecordingState.completed) {
      return const SizedBox.shrink();
    }
    final active = controller.busy;
    final status = CaptureStatusPresentation.from(
      session,
      error: controller.error,
    );
    final failure = controller.error ?? session.error?.message;
    return Material(
      color: context.studioColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: RecordingStatusIndicator(
                      label: status.label,
                      icon: status.icon,
                      color:
                          failure != null ||
                              session.state == RecordingState.failed
                          ? context.studioColors.warning
                          : ![
                              RecordingState.recording,
                              RecordingState.paused,
                            ].contains(session.state)
                          ? context.studioColors.primary
                          : null,
                      active: active,
                    ),
                  ),
                ),
                if (active)
                  Text(
                    '${session.elapsedActive.inMinutes.toString().padLeft(2, '0')}:${(session.elapsedActive.inSeconds % 60).toString().padLeft(2, '0')}',
                    style: AppTypography.timecode,
                    semanticsLabel:
                        '${session.elapsedActive.inSeconds} seconds elapsed',
                  ),
              ],
            ),
            if (failure != null) ...[
              Text(
                UserMessages.failure(
                  failure,
                  operation: session.screenshot
                      ? UserOperation.screenshot
                      : UserOperation.recording,
                ).text,
              ),
              if (UserMessages.failure(
                    failure,
                    operation: UserOperation.recording,
                  ).helpTopic
                  case final String topic)
                TextButton(
                  onPressed: () => context.push('/help?topic=$topic'),
                  child: const Text('Help'),
                ),
            ],
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.xs,
              children: [
                if (session.state == RecordingState.recording ||
                    session.state == RecordingState.paused)
                  TextButton.icon(
                    onPressed: controller.togglePause,
                    icon: Icon(
                      session.state == RecordingState.paused
                          ? AppIcons.play
                          : AppIcons.pause,
                    ),
                    label: Text(
                      session.state == RecordingState.paused
                          ? 'Resume'
                          : 'Pause',
                    ),
                  ),
                if (active)
                  TextButton.icon(
                    onPressed: controller.stop,
                    icon: const Icon(AppIcons.stop),
                    label: const Text('Stop'),
                  ),
                if (!active)
                  IconButton(
                    tooltip: 'Dismiss recording status',
                    onPressed: controller.dismiss,
                    icon: const Icon(AppIcons.close),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A transient, compact result above navigation. No video controls or timer.
class CaptureFeedbackCard extends StatelessWidget {
  const CaptureFeedbackCard({
    super.key,
    required this.feedback,
    required this.onDismiss,
  });
  final CaptureFeedback feedback;
  final VoidCallback onDismiss;
  @override
  Widget build(BuildContext context) {
    final c = context.studioColors;
    final success = feedback.notice.kind == NoticeKind.success;
    final accent = success
        ? c.cyan
        : feedback.notice.kind == NoticeKind.error
        ? c.warning
        : c.muted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Semantics(
        liveRegion: true,
        child: StudioCard(
          color: Color.alphaBlend(accent.withValues(alpha: .05), c.card),
          borderColor: accent.withValues(alpha: .24),
          padding: const EdgeInsets.only(left: 12, right: 4),
          child: Row(
            children: [
              Icon(
                success
                    ? AppIcons.ready
                    : feedback.notice.kind == NoticeKind.error
                    ? AppIcons.error
                    : AppIcons.info,
                size: 20,
                color: accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    feedback.notice.text,
                    style: AppTypography.bodySmall.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (feedback.output != null)
                TextButton(
                  onPressed: () {
                    final uri = feedback.output.toString();
                    onDismiss();
                    context.push(
                      feedback.screenshot
                          ? '/photo-preview/${Uri.encodeComponent(uri)}'
                          : '/media/${Uri.encodeComponent(uri)}',
                    );
                  },
                  child: const Text('View'),
                ),
              IconButton(
                tooltip: 'Dismiss capture notification',
                onPressed: onDismiss,
                icon: const Icon(AppIcons.close, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
