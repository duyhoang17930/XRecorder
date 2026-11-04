import 'package:flutter/material.dart';

import '../../core/domain/models.dart';
import '../../core/widgets/studio_widgets.dart';
import '../recording/recording_service.dart';
import 'settings_controller.dart';

class RecordingSettingsForm extends StatefulWidget {
  const RecordingSettingsForm({super.key});
  @override
  State<RecordingSettingsForm> createState() => _RecordingSettingsFormState();
}

class _RecordingSettingsFormState extends State<RecordingSettingsForm> {
  Future<RecordingCapabilities>? _capabilities;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _capabilities ??= CaptureScope.of(context).service.capabilities();
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
        bool supports(String resolution, int fps) {
          if (caps == null) return true;
          final size = resolutions[resolution]!;
          final codec = s.codec == 'H.265 / HEVC'
              ? VideoCodec.hevc
              : VideoCodec.avc;
          if (codec == VideoCodec.hevc) {
            return caps
                .hevc; // Native preflight validates the exact HEVC tuple.
          }
          return caps.configurations.any(
            (c) => c.width == size.$1 && c.height == size.$2 && c.fps == fps,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (snapshot.hasError)
              const Text(
                'Device capability information is unavailable. Preferences are checked again before capture.',
              ),
            const Text(
              'Settings apply to the next session. Target FPS may vary with device load and static screen content.',
            ),
            const SizedBox(height: 16),
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
                child: Text(
                  'Performance mode limits output to 720p, 30 FPS and 8 Mbps.',
                ),
              ),
            ChoiceGroup(
              label: 'Resolution',
              options: resolutions.keys.toList(),
              value: s.resolution,
              disabledOptions: resolutions.keys
                  .where(
                    (r) =>
                        (s.mode == 'Performance' && r != '720p HD') ||
                        !supports(r, int.parse(s.fps)),
                  )
                  .toSet(),
              onChanged: (v) => s.update(() => s.resolution = v),
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
                  : const {},
              onChanged: (v) => s.update(() => s.codec = v),
            ),
            ChoiceGroup(
              label: 'Orientation',
              options: const ['Auto Sensor', 'Landscape', 'Portrait'],
              value: s.orientation,
              onChanged: (v) => s.update(() => s.orientation = v),
            ),
            ChoiceGroup(
              label: 'Audio source',
              options: const [
                'Mute',
                'Microphone',
                'Internal Audio',
                'Mixed Stream',
              ],
              value: s.audio,
              disabledOptions:
                  caps != null &&
                      !caps.audioSources.contains(AudioSource.internal)
                  ? {'Internal Audio', 'Mixed Stream'}
                  : const {},
              onChanged: (v) => s.update(() => s.audio = v),
            ),
            if (s.audio == 'Internal Audio' || s.audio == 'Mixed Stream') ...[
              const Text(
                'Only playback allowed by the source app can be captured. Protected content may be silent. Audio permission is required by Android.',
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
                subtitle: Text(
                  caps?.noiseReduction == false
                      ? 'Not supported by this device'
                      : 'Uses the device audio processor',
                ),
                value: caps?.noiseReduction == false ? false : s.noise,
                onChanged: caps?.noiseReduction == false
                    ? null
                    : (v) => s.update(() => s.noise = v),
              ),
            ],
            ChoiceGroup(
              label: 'Pre-start countdown',
              options: const ['Off', '3s', '5s', '10s'],
              value: s.countdown,
              onChanged: (v) => s.update(() => s.countdown = v),
            ),
            SwitchListTile(
              title: const Text('Facecam'),
              subtitle: Text(
                caps?.facecam == true
                    ? 'Floating front camera appears in full-screen recordings. Requires camera and display-over-other-apps access. Turn off for camera-free capture.'
                    : 'No front camera available. Turn facecam off to record without it.',
              ),
              value: s.facecam,
              onChanged: caps?.facecam != true && !s.facecam
                  ? null
                  : (v) => s.update(() => s.facecam = v),
            ),
            TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Show touches'),
                  content: const Text(
                    'Android can draw touch indicators when Show taps is enabled in Developer options. Enable it manually in system Settings if available. XRecorder cannot observe arbitrary touches in other apps. The system indicator may appear in full-screen recordings; turn it off afterward if you do not want it.',
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
              title: const Text('Recording duration / auto-stop'),
              subtitle: Text(
                s.durationSeconds == 0
                    ? 'No duration limit'
                    : '${s.durationSeconds} seconds',
              ),
              trailing: const Icon(Icons.timer_outlined),
              onTap: () => _duration(context, s),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _gain(String label, double value, ValueChanged<double> change) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ${value.round()}%'),
          Slider(
            value: value,
            min: 0,
            max: 200,
            divisions: 40,
            label: '${value.round()}%',
            onChanged: change,
          ),
        ],
      );
  Future<void> _duration(BuildContext context, SettingsController s) async {
    final field = TextEditingController(text: s.durationSeconds.toString());
    String? error;
    final result = await showStudioDialog<int>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => StudioDialog(
          title: const Text('Auto-stop duration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter seconds from 1 to 86400, or 0 for no limit. This limits recording time; it is separate from the countdown.',
              ),
              TextField(
                controller: field,
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
                final value = int.tryParse(field.text);
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
    field.dispose();
    if (result != null) s.update(() => s.durationSeconds = result);
  }
}
