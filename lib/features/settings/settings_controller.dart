import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/persistence/settings_store.dart';
import '../../core/domain/models.dart';

/// Preferences for future capture sessions; not a claim of device capability.
class SettingsController extends ChangeNotifier {
  SettingsController({this.store});
  final SettingsStore? store;
  Future<void> _pending = Future.value();
  bool _disposed = false;
  bool _writable = true;
  String? persistenceError;
  bool get canSave => _writable;
  Future<void> get flushed => _pending;

  Future<void> restore() async {
    final store = this.store;
    if (store == null) return;
    try {
      final document = await store.read();
      if (document != null) {
        final decoded = jsonDecode(document);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Invalid preferences');
        }
        final version = decoded['version'] ?? 0;
        if (version != 0 && version != 1 && version != 2) {
          throw const FormatException('Unsupported preferences version');
        }
        // Version 0 was an unwrapped map. Preserve its recognized values.
        final values = version == 0 ? decoded : decoded['values'];
        if (values is! Map<String, dynamic>) {
          throw const FormatException('Invalid preference values');
        }
        _apply(values);
        if (version != 2) {
          await store.write(jsonEncode(_document()));
        }
      }
    } catch (_) {
      _writable = false; // Do not overwrite corrupt/newer data implicitly.
      persistenceError = 'Saved preferences could not be loaded. Changes are temporary. Retry loading or reset preferences.';
    }
  }

  Future<void> retryRestore() async {
    await _pending;
    _writable = true;
    persistenceError = null;
    await restore();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _save() {
    final store = this.store;
    if (store == null || !_writable) return;
    final document = jsonEncode(_document());
    _pending = _pending.then((_) async {
      try {
        await store.write(document);
        if (persistenceError != null) {
          persistenceError = null;
          _notify();
        }
      } catch (_) {
        persistenceError = 'Preferences could not be saved. Your changes are temporary. Retry saving.';
        _notify();
      }
    });
  }

  void retrySave() => _save();

  Map<String, Object> _document() => {
    'version': 2,
    'values': {
      'resolution': resolution,
      'fps': fps,
      'bitrate': bitrate,
      'codec': codec,
      'orientation': orientation,
      'audio': audio,
      'countdown': countdown,
      'gain': gain,
      'cfr': cfr,
      'hardware': hardware,
      'noise': noise,
      'shake': shake,
      'screenOff': screenOff,
      'touches': touches,
      'cache': cache,
      'internalGain': internalGain,
      'durationSeconds': durationSeconds,
      'mode': mode,
    },
  };

  void _apply(Map<String, dynamic> values) {
    String choice(String key, String fallback, List<String> allowed) =>
        allowed.contains(values[key]) ? values[key] as String : fallback;
    bool flag(String key, bool fallback) =>
        values[key] is bool ? values[key] as bool : fallback;
    resolution = choice('resolution', resolution, [
      '720p HD',
      '1080p FHD',
      '2K QHD',
      '4K UHD',
    ]);
    fps = choice('fps', fps, ['24', '30', '60', '90', '120']);
    bitrate = choice('bitrate', bitrate, [
      'Auto',
      '8 Mbps',
      '12 Mbps',
      '16 Mbps',
      '24 Mbps',
    ]);
    codec = choice('codec', codec, ['H.264 / AVC', 'H.265 / HEVC']);
    orientation = choice('orientation', orientation, [
      'Auto Sensor',
      'Landscape',
      'Portrait',
    ]);
    audio = choice('audio', audio, [
      'Mixed Stream',
      'Internal Audio',
      'Microphone',
      'Mute',
    ]);
    countdown = choice('countdown', countdown, ['Off', '3s', '5s', '10s']);
    final savedGain = values['gain'];
    if (savedGain is num && savedGain.isFinite) {
      gain = savedGain.toDouble().clamp(0, 200);
    }
    final internal = values['internalGain'];
    if (internal is num && internal.isFinite) {
      internalGain = internal.toDouble().clamp(0, 200);
    }
    final duration = values['durationSeconds'];
    if (duration is int && duration >= 0 && duration <= 86400) {
      durationSeconds = duration;
    }
    mode = choice('mode', mode, ['Normal', 'Performance']);
    cfr = flag('cfr', cfr);
    hardware = flag('hardware', hardware);
    noise = flag('noise', noise);
    shake = flag('shake', shake);
    screenOff = flag('screenOff', screenOff);
    touches = flag('touches', touches);
    cache = flag('cache', cache);
  }

  String resolution = '1080p FHD';
  String fps = '60';
  String bitrate = '16 Mbps';
  String codec = 'H.264 / AVC';
  String orientation = 'Auto Sensor';
  String audio = 'Mixed Stream';
  String countdown = '3s';
  double gain = 100;
  double internalGain = 100;
  int durationSeconds = 0;
  String mode = 'Normal';
  bool cfr = true;
  bool hardware = true;
  bool noise = false;
  bool shake = true;
  bool screenOff = false;
  bool touches = false;
  bool cache = true;

  RecordingSettings get recordingSnapshot {
    final dimensions = switch (resolution) {
      '720p HD' => (1280, 720),
      '2K QHD' => (2560, 1440),
      '4K UHD' => (3840, 2160),
      _ => (1920, 1080),
    };
    return RecordingSettings(
      mode: mode == 'Performance'
          ? RecordingMode.performance
          : RecordingMode.normal,
      durationLimit: durationSeconds == 0
          ? null
          : Duration(seconds: durationSeconds),
      width: dimensions.$1,
      height: dimensions.$2,
      fps: int.parse(fps),
      bitrate: bitrate == 'Auto'
          ? null
          : int.parse(bitrate.split(' ').first) * 1000000,
      codec: codec == 'H.265 / HEVC' ? VideoCodec.hevc : VideoCodec.avc,
      audioSource: switch (audio) {
        'Microphone' => AudioSource.microphone,
        'Internal Audio' => AudioSource.internal,
        'Mixed Stream' => AudioSource.mixed,
        _ => AudioSource.mute,
      },
      orientation: switch (orientation) {
        'Portrait' => CaptureOrientation.portrait,
        'Landscape' => CaptureOrientation.landscape,
        _ => CaptureOrientation.automatic,
      },
      countdown: Duration(
        seconds: countdown == 'Off'
            ? 0
            : int.parse(countdown.replaceAll('s', '')),
      ),
      micGain: gain / 100,
      internalGain: internalGain / 100,
      noiseReduction: noise,
      constantFrameRate: cfr,
      hardwareEncoding: hardware,
      shakeToStop: shake,
      allowScreenOff: screenOff,
      showTouches: touches,
      recoveryCache: cache,
    );
  }

  void update(VoidCallback change) {
    change();
    notifyListeners();
    _save();
  }

  void reset() {
    _writable = true;
    update(() {
      resolution = '1080p FHD';
      fps = '60';
      bitrate = '16 Mbps';
      codec = 'H.264 / AVC';
      orientation = 'Auto Sensor';
      audio = 'Mixed Stream';
      countdown = '3s';
      gain = 100;
      internalGain = 100;
      durationSeconds = 0;
      mode = 'Normal';
      cfr = true;
      hardware = true;
      noise = false;
      shake = true;
      screenOff = false;
      touches = false;
      cache = true;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({
    super.key,
    required SettingsController controller,
    required super.child,
  }) : super(notifier: controller);
  static SettingsController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;
}
