import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<Map<String, Object>?> editProjectEffects(
  BuildContext context,
  Map<String, Object> current,
) => showDialog<Map<String, Object>>(
  context: context,
  builder: (_) => _EffectsDialog(current: current),
);

class _EffectsDialog extends StatefulWidget {
  const _EffectsDialog({required this.current});
  final Map<String, Object> current;
  @override
  State<_EffectsDialog> createState() => _EffectsDialogState();
}

class _EffectsDialogState extends State<_EffectsDialog> {
  late final values = <String, Object>{
    'speed': 1.0,
    'volume': 1.0,
    'pitch': 1.0,
    'height': 0,
    'fps': 30,
    'filter': 'none',
    'aspect': 0.0,
    'musicVolume': .5,
    'format': 'mp4',
    ...widget.current,
  };
  late final text = TextEditingController(
    text: widget.current['text'] as String? ?? '',
  );
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Widget choice(String key, String label, List<Object> options) =>
      DropdownButtonFormField<Object>(
        isExpanded: true,
        initialValue: values[key],
        decoration: InputDecoration(labelText: label),
        items: options
            .map(
              (v) => DropdownMenuItem(
                value: v,
                child: Text(
                  v == 0 && (key == 'height' || key == 'aspect')
                      ? 'Original dimensions'
                      : v.toString(),
                ),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => values[key] = v!),
      );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Video & audio effects'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            choice('speed', 'Playback speed (audio pitch also changes)', [
              .5,
              1.0,
              1.5,
              2.0,
            ]),
            choice('volume', 'Original audio gain (0 mutes)', [
              0.0,
              .5,
              1.0,
              1.5,
              2.0,
            ]),
            choice('pitch', 'Audio pitch (applies to all clip audio)', [
              .75,
              1.0,
              1.25,
            ]),
            choice('height', 'Output height / compression', [
              0,
              480,
              720,
              1080,
            ]),
            choice('fps', 'Target output FPS (variable)', [24, 30, 60]),
            choice('filter', 'Color filter', ['none', 'grayscale', 'invert']),
            choice('format', 'Export format', ['mp4', 'gif']),
            const Text(
              'GIF: no audio, up to 15 seconds, 10 FPS, 320 px longest edge. Colors are reduced to 256.',
            ),
            choice('aspect', 'Black background / aspect ratio', [
              0.0,
              1.0,
              16 / 9,
              9 / 16,
            ]),
            TextButton(
              onPressed: () async {
                try {
                  final uri = await const MethodChannel('com.xrecorder/media')
                      .invokeMethod<String>('selectAudio');
                  if (uri != null && mounted) {
                    setState(() => values['music'] = uri);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              child: Text(
                values['music'] == null
                    ? 'Add background music'
                    : 'Replace background music',
              ),
            ),
            if (values['music'] != null) ...[
              const Text('Music loops to the video duration.'),
              choice('musicVolume', 'Music gain', [0.0, .25, .5, .75, 1.0]),
              TextButton(
                onPressed: () => setState(() => values.remove('music')),
                child: const Text('Remove music'),
              ),
            ],
            TextField(
              controller: text,
              maxLength: 120,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Centered text throughout video',
              ),
            ),
            const Text(
              'Smaller dimensions can reduce file size; the final size depends on your media and device encoder.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, {...values, 'text': text.text}),
        child: const Text('Apply to project'),
      ),
    ],
  );
}
