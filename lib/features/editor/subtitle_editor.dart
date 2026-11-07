import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/studio_widgets.dart';
import 'subtitles.dart';
import '../../core/domain/models.dart';
import 'transcription_dialog.dart';

Future<SubtitleTrack?> editSubtitles(
  BuildContext context,
  SubtitleTrack track, {
  EditProject? project,
}) => showStudioDialog<SubtitleTrack>(
  context: context,
  builder: (_) => _SubtitleEditor(track: track, project: project),
);

class _SubtitleEditor extends StatefulWidget {
  const _SubtitleEditor({required this.track, this.project});
  final SubtitleTrack track;
  final EditProject? project;
  @override
  State<_SubtitleEditor> createState() => _SubtitleEditorState();
}

class _SubtitleEditorState extends State<_SubtitleEditor> {
  late var cues = widget.track.cues.toList();
  final text = TextEditingController(),
      start = TextEditingController(text: '0'),
      end = TextEditingController(text: '1');
  int? selected;
  String? error;
  @override
  void dispose() {
    text.dispose();
    start.dispose();
    end.dispose();
    super.dispose();
  }

  SubtitleTrack get track =>
      SubtitleTrack(cues, durationMs: widget.track.durationMs);
  void apply(VoidCallback action) {
    try {
      action();
      setState(() => error = null);
    } on FormatException catch (e) {
      setState(() => error = e.message.toString());
    }
  }

  @override
  Widget build(BuildContext context) => StudioDialog(
    title: const Text('Subtitles'),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Edit timed subtitles on this device. Automatic recognition uses a downloaded offline model.',
          ),
          if (widget.project != null)
            TextButton(
              onPressed: () async {
                final generated = await generateSubtitles(
                  context,
                  widget.project!,
                );
                if (mounted && generated != null) {
                  setState(() {
                    cues = generated.cues.toList();
                    selected = null;
                  });
                }
              },
              child: const Text('Generate offline subtitles'),
            ),
          for (var i = 0; i < cues.length; i++)
            ListTile(
              title: Text(cues[i].text),
              subtitle: Text(
                '${cues[i].startMs / 1000}–${cues[i].endMs / 1000}s',
              ),
              selected: selected == i,
              onTap: () => setState(() {
                selected = i;
                text.text = cues[i].text;
                start.text = '${cues[i].startMs / 1000}';
                end.text = '${cues[i].endMs / 1000}';
              }),
              trailing: IconButton(
                tooltip: 'Delete subtitle',
                icon: const Icon(AppIcons.trash),
                onPressed: () => setState(() {
                  cues.removeAt(i);
                  selected = null;
                }),
              ),
            ),
          TextField(
            controller: text,
            maxLength: 2000,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Subtitle text'),
          ),
          TextField(
            controller: start,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Start (seconds)'),
          ),
          TextField(
            controller: end,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'End (seconds)'),
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Wrap(
            children: [
              TextButton(
                onPressed: cues.isEmpty
                    ? null
                    : () async {
                        try {
                          await const MethodChannel('com.xrecorder/media')
                              .invokeMethod<String>('exportSrt', track.toSrt());
                        } catch (e) {
                          if (context.mounted) {
                            showFailure(
                              context,
                              e,
                              operation: UserOperation.savePhoto,
                            );
                          }
                        }
                      },
                child: const Text('Save SRT file'),
              ),
              TextButton(
                onPressed: () => apply(() {
                  final a = double.tryParse(start.text),
                      b = double.tryParse(end.text);
                  if (a == null ||
                      b == null ||
                      !a.isFinite ||
                      !b.isFinite ||
                      a < 0 ||
                      b <= a ||
                      b > widget.track.durationMs / 1000) {
                    throw const FormatException(
                      'Enter valid times within the video.',
                    );
                  }
                  final cue = SubtitleCue(
                    startMs: (a * 1000).round(),
                    endMs: (b * 1000).round(),
                    text: text.text.trim(),
                  );
                  final next = cues.toList();
                  if (selected == null) {
                    next.add(cue);
                  } else {
                    next[selected!] = cue;
                  }
                  cues = SubtitleTrack(
                    next,
                    durationMs: widget.track.durationMs,
                  ).cues.toList();
                  selected = null;
                  text.clear();
                }),
                child: Text(
                  selected == null ? 'Add subtitle' : 'Update subtitle',
                ),
              ),
              TextButton(
                onPressed: selected == null
                    ? null
                    : () => apply(() {
                        cues = track.split(selected!).cues.toList();
                        selected = null;
                      }),
                child: const Text('Split'),
              ),
              TextButton(
                onPressed: selected == null || selected! >= cues.length - 1
                    ? null
                    : () => apply(() {
                        cues = track.merge(selected!).cues.toList();
                        selected = null;
                      }),
                child: const Text('Merge next'),
              ),
              TextButton(
                onPressed: cues.isEmpty
                    ? null
                    : () => apply(() {
                        Clipboard.setData(ClipboardData(text: track.toSrt()));
                      }),
                child: const Text('Copy SRT'),
              ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => apply(() => Navigator.pop(context, track)),
        child: const Text('Apply subtitles'),
      ),
    ],
  );
}
