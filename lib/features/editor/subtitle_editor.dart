import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../l10n/editor_numbers.dart';

import 'package:xrecorder/l10n/localization.dart';
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
    title: Text(context.l10n.subtitles),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          Text(context.l10n.editTimedSubtitlesOnThisDeviceAutomatic),
          if (widget.project != null)
            OutlinedButton.icon(
              icon: const Icon(AppIcons.captions, size: AppIconSize.medium),
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
              label: Text(context.l10n.generateOfflineSubtitles),
            ),
          for (var i = 0; i < cues.length; i++)
            ListTile(
              tileColor: context.studioColors.surface,
              selectedTileColor: context.studioColors.primary.withValues(
                alpha: .12,
              ),
              contentPadding: const EdgeInsetsDirectional.only(
                start: AppSpacing.md,
                end: AppSpacing.xxs,
              ),
              title: Text(
                cues[i].text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                context.l10n.timeRangeSeconds(
                  context.displayValue(cues[i].startMs / 1000),
                  context.displayValue(cues[i].endMs / 1000),
                ),
              ),
              selected: selected == i,
              onTap: () => setState(() {
                selected = i;
                text.text = cues[i].text;
                start.text = '${cues[i].startMs / 1000}';
                end.text = '${cues[i].endMs / 1000}';
              }),
              trailing: IconButton(
                tooltip: context.l10n.deleteSubtitle,
                icon: const Icon(AppIcons.trash),
                onPressed: () => setState(() {
                  cues.removeAt(i);
                  selected = null;
                }),
              ),
            ),
          const SizedBox(height: AppSpacing.xxs),
          TextField(
            controller: text,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(labelText: context.l10n.subtitleText),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            spacing: AppSpacing.sm,
            children: [
              Expanded(
                child: TextField(
                  controller: start,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: context.l10n.startSeconds,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: end,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: context.l10n.endSeconds,
                  ),
                ),
              ),
            ],
          ),
          if (error != null)
            Text(
              context.message(error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton(
                onPressed: cues.isEmpty
                    ? null
                    : () async {
                        try {
                          final body = track.toSrt();
                          const media = MethodChannel('com.xrecorder/media');
                          final uri = await media.invokeMethod<String>(
                            'exportSrt',
                            {
                              'text': body,
                              'fileName':
                                  '${context.l10n.subtitles}_${DateTime.now().millisecondsSinceEpoch}.srt',
                            },
                          );
                          if (uri == null || !context.mounted) return;
                          var verified = false;
                          try {
                            final read = await media
                                .invokeMapMethod<String, dynamic>(
                                  'readSubtitleDocument',
                                  {'uri': uri},
                                );
                            verified = listEquals(
                              read?['bytes'] as Uint8List?,
                              utf8.encode(body),
                            );
                          } catch (_) {
                            /* Some providers grant write-only access. */
                          }
                          if (!context.mounted) return;
                          showNotice(
                            context,
                            verified
                                ? context.l10n.subtitleSaved
                                : context.l10n.subtitleSavedUnverified,
                            kind: verified
                                ? NoticeKind.success
                                : NoticeKind.warning,
                          );
                        } on FormatException catch (e) {
                          if (context.mounted) {
                            showNotice(
                              context,
                              context.message(e.message.toString()),
                              kind: NoticeKind.warning,
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showFailure(
                              context,
                              e,
                              operation: UserOperation.saveSubtitles,
                            );
                          }
                        }
                      },
                child: Text(context.l10n.saveSrtFile),
              ),
              FilledButton.tonal(
                onPressed: () => apply(() {
                  final a = parseEditorDecimal(start.text),
                      b = parseEditorDecimal(end.text);
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
                    text: text.text,
                    joinerBefore: selected == null
                        ? ' '
                        : cues[selected!].joinerBefore,
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
                  selected == null
                      ? context.l10n.addSubtitle
                      : context.l10n.updateSubtitle,
                ),
              ),
              OutlinedButton(
                onPressed: selected == null
                    ? null
                    : () => apply(() {
                        cues = track.split(selected!).cues.toList();
                        selected = null;
                      }),
                child: Text(context.l10n.split),
              ),
              OutlinedButton(
                onPressed: selected == null || selected! >= cues.length - 1
                    ? null
                    : () => apply(() {
                        cues = track.merge(selected!).cues.toList();
                        selected = null;
                      }),
                child: Text(context.l10n.mergeNext),
              ),
              OutlinedButton(
                onPressed: cues.isEmpty
                    ? null
                    : () => apply(() {
                        Clipboard.setData(ClipboardData(text: track.toSrt()));
                      }),
                child: Text(context.l10n.copySrt),
              ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        onPressed: () => apply(() => Navigator.pop(context, track)),
        child: Text(context.l10n.applySubtitles),
      ),
    ],
  );
}
