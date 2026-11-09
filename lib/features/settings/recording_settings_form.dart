import 'package:flutter/material.dart';

import '../../core/domain/models.dart';
import '../../core/widgets/studio_widgets.dart';
import '../recording/recording_service.dart';
import 'settings_controller.dart';

class RecordingSettingsForm extends StatefulWidget {
  const RecordingSettingsForm({super.key, this.advanced});

  // Null preserves the full form used by the Audio & Video settings screen.
  final bool? advanced;
  @override
  State<RecordingSettingsForm> createState() => _RecordingSettingsFormState();
}

class _RecordingSettingsFormState extends State<RecordingSettingsForm> {
  Future<RecordingCapabilities>? _capabilities;
  bool _selectionNormalized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _capabilities ??= CaptureScope.of(context).service.capabilities()
      ..then((capabilities) {
        if (!mounted || _selectionNormalized) return;
        _selectionNormalized = true;
        _normalizeSelection(SettingsScope.of(context), capabilities);
      });
  }

  void _normalizeSelection(
    SettingsController settings,
    RecordingCapabilities capabilities,
  ) {
    final portrait = switch (settings.orientation) {
      'Portrait' => true,
      'Landscape' => false,
      _ =>
        MediaQuery.sizeOf(context).height >= MediaQuery.sizeOf(context).width,
    };
    const sizes = {
      '4K UHD': (3840, 2160),
      '2K QHD': (2560, 1440),
      '1080p FHD': (1920, 1080),
      '720p HD': (1280, 720),
    };
    bool supported(String resolution, int fps, String codec) {
      final size = sizes[resolution]!;
      final expectedWidth = portrait ? size.$2 : size.$1;
      final expectedHeight = portrait ? size.$1 : size.$2;
      final targetCodec = codec == 'H.265 / HEVC'
          ? VideoCodec.hevc
          : VideoCodec.avc;
      return capabilities.configurations.any(
        (configuration) =>
            configuration.width == expectedWidth &&
            configuration.height == expectedHeight &&
            configuration.fps == fps &&
            configuration.codec == targetCodec,
      );
    }

    final currentFps = int.tryParse(settings.fps) ?? 30;
    if (supported(settings.resolution, currentFps, settings.codec)) return;
    for (final resolution in sizes.keys) {
      for (final fps in const [120, 90, 60, 30, 24]) {
        if (supported(resolution, fps, 'H.264 / AVC')) {
          settings.update(() {
            settings.resolution = resolution;
            settings.fps = '$fps';
            settings.codec = 'H.264 / AVC';
            settings.bitrate = 'Auto';
          });
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return FutureBuilder<RecordingCapabilities>(
      future: _capabilities,
      builder: (context, snapshot) {
        final caps = snapshot.data;
        const resolutions = {
          '720p HD': (1280, 720),
          '1080p FHD': (1920, 1080),
          '2K QHD': (2560, 1440),
          '4K UHD': (3840, 2160),
        };
        bool supports(String resolution, int fps, {String? codecName}) {
          if (s.mode == 'Performance' && fps > 30) return false;
          if (caps == null) return true;
          final size = resolutions[resolution]!;
          final portrait = switch (s.orientation) {
            'Portrait' => true,
            'Landscape' => false,
            _ =>
              MediaQuery.sizeOf(context).height >=
                  MediaQuery.sizeOf(context).width,
          };
          final codec = (codecName ?? s.codec) == 'H.265 / HEVC'
              ? VideoCodec.hevc
              : VideoCodec.avc;
          return caps.configurations.any(
            (c) =>
                c.width == (portrait ? size.$2 : size.$1) &&
                c.height == (portrait ? size.$1 : size.$2) &&
                c.fps == fps &&
                c.codec == codec,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (snapshot.hasError)
              const Text(
                'Device capabilities unavailable. Checked again before recording.',
              ),
            if (widget.advanced != false) ...[
              ChoiceGroup(
                label: 'Recording mode',
                options: const ['Normal', 'Performance'],
                value: s.mode,
                onChanged: (v) => s.update(() {
                  s.mode = v;
                  if (v == 'Performance') {
                    s.resolution = '720p HD';
                    s.fps = '30';
                    s.bitrate = '8 Mbps';
                  }
                }),
              ),
              if (s.mode == 'Performance')
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text('Up to 720p · 30 FPS · 8 Mbps'),
                ),
            ],
            if (widget.advanced != true) ...[
              ChoiceGroup(
                label: 'Resolution',
                options: resolutions.keys.toList(),
                value: s.resolution,
                disabledOptions: resolutions.keys
                    .where(
                      (r) =>
                          (s.mode == 'Performance' && r != '720p HD') ||
                          ![24, 30, 60, 90, 120].any((fps) => supports(r, fps)),
                    )
                    .toSet(),
                onChanged: (v) => s.update(() {
                  s.resolution = v;
                  if (!supports(v, int.parse(s.fps))) {
                    s.fps = [
                      30,
                      24,
                      60,
                      90,
                      120,
                    ].firstWhere((fps) => supports(v, fps)).toString();
                  }
                }),
              ),
              ChoiceGroup(
                label: 'Target FPS',
                options: const ['24', '30', '60', '90', '120'],
                value: s.fps,
                disabledOptions: ['24', '30', '60', '90', '120']
                    .where(
                      (f) =>
                          (s.mode == 'Performance' && int.parse(f) > 30) ||
                          !supports(s.resolution, int.parse(f)),
                    )
                    .toSet(),
                onChanged: (v) => s.update(() => s.fps = v),
              ),
            ],
            if (widget.advanced != false) ...[
              ChoiceGroup(
                label: 'Bitrate',
                options: const [
                  'Auto',
                  '8 Mbps',
                  '12 Mbps',
                  '16 Mbps',
                  '24 Mbps',
                ],
                value: s.bitrate,
                disabledOptions: s.mode == 'Performance'
                    ? {'12 Mbps', '16 Mbps', '24 Mbps'}
                    : const {},
                onChanged: (v) => s.update(() => s.bitrate = v),
              ),
              ChoiceGroup(
                label: 'Video codec',
                options: const ['H.264 / AVC', 'H.265 / HEVC'],
                value: s.codec,
                disabledOptions: caps?.hevc == false
                    ? {'H.265 / HEVC'}
                    : !supports(
                        s.resolution,
                        int.parse(s.fps),
                        codecName: 'H.265 / HEVC',
                      )
                    ? {'H.265 / HEVC'}
                    : const {},
                onChanged: (v) => s.update(() => s.codec = v),
              ),
              ChoiceGroup(
                label: 'Orientation',
                options: const ['Auto Sensor', 'Landscape', 'Portrait'],
                value: s.orientation,
                onChanged: (v) => s.update(() => s.orientation = v),
              ),
            ],
            if (widget.advanced != true) ...[
              ChoiceGroup(
                label: 'Audio source',
                options: const [
                  'Mute',
                  'Microphone',
                  'Internal Audio',
                  'Mixed Stream',
                ],
                value: s.audio,
                disabledOptions: widget.advanced == null
                    ? (caps != null &&
                              !caps.audioSources.contains(AudioSource.internal)
                          ? {'Internal Audio', 'Mixed Stream'}
                          : const {})
                    : {
                        for (final entry in const {
                          'Mute': AudioSource.mute,
                          'Microphone': AudioSource.microphone,
                          'Internal Audio': AudioSource.internal,
                          'Mixed Stream': AudioSource.mixed,
                        }.entries)
                          if (caps != null &&
                              !caps.audioSources.contains(entry.value))
                            entry.key,
                      },
                onChanged: (v) => s.update(() => s.audio = v),
              ),
            ],
            if (widget.advanced != false) ...[
              if (s.audio == 'Internal Audio' || s.audio == 'Mixed Stream') ...[
                const Text(
                  'Protected audio may be silent. Android may ask for audio access.',
                ),
                const SizedBox(height: 8),
                _gain(
                  'Internal audio volume',
                  s.internalGain,
                  (v) => s.update(() => s.internalGain = v),
                ),
              ],
              if (s.audio == 'Microphone' || s.audio == 'Mixed Stream') ...[
                _gain(
                  'Microphone volume',
                  s.gain,
                  (v) => s.update(() => s.gain = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Microphone noise reduction'),
                  subtitle: caps?.noiseReduction == false
                      ? const Text('Not supported by this device')
                      : null,
                  value: caps?.noiseReduction == false ? false : s.noise,
                  onChanged: caps?.noiseReduction == false
                      ? null
                      : (v) => s.update(() => s.noise = v),
                ),
              ],
            ],
            if (widget.advanced != true) ...[
              ChoiceGroup(
                label: 'Pre-start countdown',
                options: const ['Off', '3s', '5s', '10s'],
                value: s.countdown,
                onChanged: (v) => s.update(() => s.countdown = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Facecam'),
                subtitle: caps?.facecam == false
                    ? const Text('No front camera available')
                    : null,
                value: s.facecam,
                onChanged: caps?.facecam != true && !s.facecam
                    ? null
                    : (v) => s.update(() => s.facecam = v),
              ),
            ],
            if (widget.advanced != false) ...[
              if (widget.advanced == null) ...[
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Show touches'),
                      content: const Text(
                        'Android can draw touch indicators when Show taps is enabled in Developer options. Enable it manually in system Settings if available. 3HRecorder cannot observe arbitrary touches in other apps. The system indicator may appear in full-screen recordings; turn it off afterward if you do not want it.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('Touch-indicator guidance'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-stop'),
                  subtitle: Text(
                    s.durationSeconds == 0
                        ? 'No limit'
                        : '${s.durationSeconds} seconds',
                  ),
                  trailing: const Icon(AppIcons.countdown),
                  onTap: () => _duration(context, s),
                ),
              ] else
                _autoStop(s),
            ],
            if (widget.advanced == null) const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _autoStop(SettingsController s) {
    final durations = {
      '5m': 300,
      '10m': 600,
      '30m': 1800,
      '60m': 3600,
      if (s.durationSeconds > 0 &&
          !const [300, 600, 1800, 3600].contains(s.durationSeconds))
        '${s.durationSeconds}s': s.durationSeconds,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Auto-stop'),
          value: s.durationSeconds > 0,
          onChanged: (enabled) => s.update(() {
            s.durationSeconds = enabled
                ? (s.durationSeconds > 0 ? s.durationSeconds : 300)
                : 0;
          }),
        ),
        if (s.durationSeconds > 0)
          ChoiceGroup(
            label: 'Duration',
            options: durations.keys.toList(),
            value: durations.entries
                .firstWhere((entry) => entry.value == s.durationSeconds)
                .key,
            onChanged: (value) =>
                s.update(() => s.durationSeconds = durations[value]!),
          ),
      ],
    );
  }

  Widget _gain(String label, double value, ValueChanged<double> change) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ${value.round()}%'),
          Semantics(
            label: label,
            child: Slider(
              value: value,
              min: 0,
              max: 200,
              divisions: 40,
              label: '${value.round()}%',
              onChanged: change,
              semanticFormatterCallback: (v) => '${v.round()} percent',
            ),
          ),
        ],
      );
  Future<void> _duration(BuildContext context, SettingsController s) async {
    var seconds = s.durationSeconds.toString();
    String? error;
    final result = await showStudioDialog<int>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => StudioDialog(
          title: const Text('Auto-stop duration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('1–86400 seconds, or 0 for no limit.'),
              TextFormField(
                initialValue: seconds,
                onChanged: (value) => seconds = value,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Seconds',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final value = int.tryParse(seconds);
                if (value == null || value < 0 || value > 86400) {
                  update(() => error = 'Enter 0–86400 seconds');
                  return;
                }
                Navigator.pop(dialog, value);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result != null) s.update(() => s.durationSeconds = result);
  }
}
