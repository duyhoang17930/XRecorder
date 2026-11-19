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

/// Edited cues plus the burn-in style chosen beside them.
class SubtitleEditResult {
  const SubtitleEditResult(this.track, this.style);
  final SubtitleTrack track;
  final Map<String, Object> style;
}

Future<SubtitleTrack?> editSubtitles(
  BuildContext context,
  SubtitleTrack track, {
  EditProject? project,
}) async => (await editSubtitlesAndStyle(
  context,
  track,
  project: project,
))?.track;

Future<SubtitleEditResult?> editSubtitlesAndStyle(
  BuildContext context,
  SubtitleTrack track, {
  EditProject? project,
  Map<String, Object> style = subtitleStyleDefaults,
}) => showStudioDialog<SubtitleEditResult>(
  context: context,
  builder: (_) => _SubtitleEditor(track: track, project: project, style: style),
);

const _swatches = <String, Color>{
  'white': Colors.white,
  'yellow': Color(0xFFFFFF00),
  'red': Color(0xFFFF5252),
  'green': Color(0xFF69F0AE),
  'cyan': Color(0xFF18FFFF),
  'blue': Color(0xFF448AFF),
  'black': Colors.black,
};

TextStyle _fontStyle(String font) => switch (font) {
  'serif' => const TextStyle(fontFamily: 'serif'),
  'mono' => const TextStyle(fontFamily: 'monospace'),
  'bold' => const TextStyle(fontWeight: FontWeight.w700),
  _ => const TextStyle(fontFamily: 'sans-serif'),
};

class _SubtitleEditor extends StatefulWidget {
  const _SubtitleEditor({
    required this.track,
    required this.style,
    this.project,
  });
  final SubtitleTrack track;
  final EditProject? project;
  final Map<String, Object> style;
  @override
  State<_SubtitleEditor> createState() => _SubtitleEditorState();
}

class _SubtitleEditorState extends State<_SubtitleEditor> {
  late var cues = widget.track.cues.toList();
  late final style = subtitleStyleOf(widget.style);
  final text = TextEditingController(),
      start = TextEditingController(text: '0'),
      end = TextEditingController(text: '1');
  final textFocus = FocusNode();
  int? selected;
  String? error;

  /// Recognition was sent to the background from this dialog.
  bool recognizingInBackground = false;
  @override
  void dispose() {
    text.dispose();
    start.dispose();
    end.dispose();
    textFocus.dispose();
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

  void select(int i) {
    setState(() {
      selected = i;
      error = null;
      text.text = cues[i].text;
      start.text = '${cues[i].startMs / 1000}';
      end.text = '${cues[i].endMs / 1000}';
    });
    // Bring the text field into view so the line can be edited right away.
    textFocus.requestFocus();
  }

  void newLine() => setState(() {
    selected = null;
    error = null;
    text.clear();
    final last = cues.isEmpty ? 0 : cues.last.endMs;
    final next = (last + 2000).clamp(0, widget.track.durationMs);
    start.text = '${last / 1000}';
    end.text = '${next / 1000}';
  });

  Future<void> saveSrt(BuildContext context) async {
    try {
      final body = track.toSrt();
      const media = MethodChannel('com.xrecorder/media');
      final uri = await media.invokeMethod<String>('exportSrt', {
        'text': body,
        'fileName':
            '${context.l10n.subtitles}_${DateTime.now().millisecondsSinceEpoch}.srt',
      });
      if (uri == null || !context.mounted) return;
      var verified = false;
      try {
        final read = await media.invokeMapMethod<String, dynamic>(
          'readSubtitleDocument',
          {'uri': uri},
        );
        verified = listEquals(read?['bytes'] as Uint8List?, utf8.encode(body));
      } catch (_) {
        /* Some providers grant write-only access. */
      }
      if (!context.mounted) return;
      showNotice(
        context,
        verified
            ? context.l10n.subtitleSaved
            : context.l10n.subtitleSavedUnverified,
        kind: verified ? NoticeKind.success : NoticeKind.warning,
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
        showFailure(context, e, operation: UserOperation.saveSubtitles);
      }
    }
  }

  void commitCue() => apply(() {
    final a = parseEditorDecimal(start.text), b = parseEditorDecimal(end.text);
    if (a == null ||
        b == null ||
        !a.isFinite ||
        !b.isFinite ||
        a < 0 ||
        b <= a ||
        b > widget.track.durationMs / 1000) {
      throw const FormatException('Enter valid times within the video.');
    }
    final cue = SubtitleCue(
      startMs: (a * 1000).round(),
      endMs: (b * 1000).round(),
      text: text.text,
      joinerBefore: selected == null ? ' ' : cues[selected!].joinerBefore,
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
  });

  Widget _sectionLabel(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs),
    child: Text(
      label,
      style: AppTypography.bodyEmphasis.copyWith(
        color: context.studioColors.text,
      ),
    ),
  );

  Widget _cueList(BuildContext context) {
    final c = context.studioColors;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 240),
      child: SingleChildScrollView(
        child: Column(
          spacing: AppSpacing.xxs,
          children: [
            for (var i = 0; i < cues.length; i++)
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  side: selected == i
                      ? BorderSide(color: c.primary, width: 1.5)
                      : BorderSide.none,
                ),
                tileColor: c.surface,
                selectedTileColor: c.primary.withValues(alpha: .14),
                selectedColor: c.text,
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
                  style: AppTypography.bodySmall.copyWith(
                    color: selected == i ? c.primary : c.muted,
                  ),
                ),
                selected: selected == i,
                onTap: () => select(i),
                trailing: IconButton(
                  tooltip: context.l10n.deleteSubtitle,
                  icon: const Icon(AppIcons.trash),
                  onPressed: () => setState(() {
                    cues.removeAt(i);
                    selected = null;
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _styleControls(BuildContext context) {
    final c = context.studioColors;
    final color = style['subtitleColor'] as String,
        size = style['subtitleSize'] as String,
        font = style['subtitleFont'] as String,
        background = style['subtitleBackground'] as String;
    Widget segmented(String key, String label) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.xxs,
      children: [
        Text(label, style: AppTypography.bodySmall.copyWith(color: c.muted)),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final value in subtitleStyleOptions[key]!)
              ButtonSegment(
                value: value,
                label: Text(
                  context.effectValue(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          selected: {style[key] as String},
          onSelectionChanged: (v) => setState(() => style[key] = v.single),
        ),
      ],
    );
    // A fixed sample keeps the look comparable while lines are edited.
    const sample = 'Aa Bb Cc 123';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.sm,
      children: [
        // Live sample of the burn-in look over a video-like backdrop.
        ExcludeSemantics(
          child: Container(
            height: 84,
            decoration: BoxDecoration(
              color: const Color(0xFF3A3F4B),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            padding: const EdgeInsets.all(AppSpacing.sm),
            alignment: style['subtitlePosition'] == 'top'
                ? Alignment.topCenter
                : Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: switch (background) {
                  'dark' => const Color(0xCC000000),
                  'light' => const Color(0xCCFFFFFF),
                  _ => Colors.transparent,
                },
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                sample,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: _fontStyle(font).copyWith(
                  color: _swatches[color],
                  fontSize: switch (size) {
                    'small' => 13,
                    'large' => 21,
                    _ => 16,
                  },
                  shadows: [
                    Shadow(
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                      color: color == 'black' ? Colors.white : Colors.black,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Text(
          context.l10n.subtitleColor,
          style: AppTypography.bodySmall.copyWith(color: c.muted),
        ),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final entry in _swatches.entries)
              Semantics(
                button: true,
                selected: entry.key == color,
                label: context.effectValue(entry.key),
                child: Tooltip(
                  message: context.effectValue(entry.key),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () =>
                        setState(() => style['subtitleColor'] = entry.key),
                    child: AnimatedContainer(
                      duration: context.motion(AppMotion.fast),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: entry.value,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: entry.key == color ? c.primary : c.muted,
                          width: entry.key == color ? 3 : 1,
                        ),
                      ),
                      child: entry.key == color
                          ? Icon(
                              AppIcons.ready,
                              size: AppIconSize.small,
                              color:
                                  entry.value.computeLuminance() > .5
                                  ? Colors.black
                                  : Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
        Text(
          context.l10n.subtitleFont,
          style: AppTypography.bodySmall.copyWith(color: c.muted),
        ),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final value in subtitleStyleOptions['subtitleFont']!)
              ChoiceChip(
                selected: value == font,
                showCheckmark: false,
                onSelected: (_) =>
                    setState(() => style['subtitleFont'] = value),
                label: Text(
                  context.effectValue(value),
                  style: _fontStyle(value),
                ),
              ),
          ],
        ),
        segmented('subtitleSize', context.l10n.subtitleTextSize),
        segmented('subtitleBackground', context.l10n.subtitleBackground),
        segmented('subtitlePosition', context.l10n.subtitlePosition),
      ],
    );
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
            FilledButton.tonalIcon(
              icon: const Icon(AppIcons.captions, size: AppIconSize.medium),
              onPressed: () async {
                setState(() => recognizingInBackground = false);
                final generated = await generateSubtitles(
                  context,
                  widget.project!,
                  onRunInBackground: () {
                    if (mounted) {
                      setState(() => recognizingInBackground = true);
                    }
                  },
                );
                if (mounted && generated != null) {
                  setState(() {
                    cues = generated.cues.toList();
                    selected = null;
                    recognizingInBackground = false;
                  });
                }
              },
              label: Text(context.l10n.generateOfflineSubtitles),
            ),
          if (recognizingInBackground)
            Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xs,
                children: [
                  Icon(
                    AppIcons.processing,
                    size: AppIconSize.small,
                    color: context.studioColors.primary,
                  ),
                  Expanded(
                    child: Text(
                      context.l10n.speechContinuesInBackground,
                      style: AppTypography.bodySmall.copyWith(
                        color: context.studioColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (cues.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.subtitleTapToEdit,
                    style: AppTypography.bodySmall.copyWith(
                      color: context.studioColors.muted,
                    ),
                  ),
                ),
                if (selected != null)
                  TextButton.icon(
                    onPressed: newLine,
                    icon: const Icon(AppIcons.create, size: AppIconSize.small),
                    label: Text(context.l10n.subtitleNewLine),
                  ),
              ],
            ),
            _cueList(context),
          ],
          const SizedBox(height: AppSpacing.xxs),
          TextField(
            controller: text,
            focusNode: textFocus,
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
          // Full width: "Update subtitle" wraps in a half-width button at
          // larger system font sizes.
          FilledButton.tonal(
            onPressed: commitCue,
            child: Text(
              selected == null
                  ? context.l10n.addSubtitle
                  : context.l10n.updateSubtitle,
            ),
          ),
          if (selected != null)
            Row(
              spacing: AppSpacing.xs,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => apply(() {
                      cues = track.split(selected!).cues.toList();
                      selected = null;
                    }),
                    child: Text(context.l10n.split),
                  ),
                ),
                Expanded(
                  child: OutlinedButton(
                    onPressed: selected! >= cues.length - 1
                        ? null
                        : () => apply(() {
                            cues = track.merge(selected!).cues.toList();
                            selected = null;
                          }),
                    child: Text(context.l10n.mergeNext),
                  ),
                ),
              ],
            ),
          const Divider(height: AppSpacing.lg),
          _sectionLabel(context, context.l10n.subtitleTextStyle),
          _styleControls(context),
          if (cues.isNotEmpty) ...[
            const Divider(height: AppSpacing.lg),
            Row(
              spacing: AppSpacing.xs,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => saveSrt(context),
                    icon: const Icon(AppIcons.save, size: AppIconSize.medium),
                    label: Text(context.l10n.saveSrtFile),
                  ),
                ),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => apply(() {
                      Clipboard.setData(ClipboardData(text: track.toSrt()));
                    }),
                    child: Text(context.l10n.copySrt),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        onPressed: () => apply(
          () => Navigator.pop(context, SubtitleEditResult(track, style)),
        ),
        child: Text(context.l10n.applySubtitles),
      ),
    ],
  );
}
