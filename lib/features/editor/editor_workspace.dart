import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/widgets/studio_widgets.dart';
import '../../l10n/localization.dart';

String formatEditorTimestamp(Duration value) {
  final totalSeconds = value.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  String twoDigits(int part) => part.toString().padLeft(2, '0');
  return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
}

/// Presentation slots keep the native preview/controller independent of panels.
class VideoEditorWorkspace extends StatelessWidget {
  const VideoEditorWorkspace({
    super.key,
    required this.preview,
    required this.status,
    required this.transport,
    required this.timeline,
    required this.tools,
    required this.history,
    this.contextual,
  });
  final Widget preview, status, transport, timeline, tools, history;
  final Widget? contextual;

  Widget _scroll(Widget child) => ScrollConfiguration(
    // Context panels contain text/controls; stretching their glyphs obscures
    // feedback. Keep normal scrolling and gesture handling in this viewport.
    behavior: const MaterialScrollBehavior().copyWith(overscroll: false),
    child: SingleChildScrollView(primary: false, child: child),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: true,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        0,
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final landscape = box.maxWidth >= 600 && box.maxWidth > box.maxHeight;
          if (landscape) {
            return Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: preview),
                      transport,
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: (box.maxWidth * .45).clamp(280, 460),
                  child: Column(
                    children: [
                      Expanded(
                        child: _scroll(
                          Column(children: [status, timeline, ?contextual]),
                        ),
                      ),
                      history,
                      tools,
                    ],
                  ),
                ),
              ],
            );
          }
          if (box.maxHeight < 350) {
            return _scroll(
              Column(
                children: [
                  SizedBox(height: 150, child: preview),
                  transport,
                  status,
                  timeline,
                  ?contextual,
                  history,
                  tools,
                ],
              ),
            );
          }
          return Column(
            children: [
              Expanded(flex: contextual == null ? 3 : 2, child: preview),
              transport,
              Expanded(
                flex: contextual == null ? 2 : 3,
                child: _scroll(
                  Column(
                    children: [
                      ?contextual,
                      status,
                      KeyedSubtree(
                        key: const ValueKey('workspace-timeline'),
                        child: timeline,
                      ),
                    ],
                  ),
                ),
              ),
              history,
              tools,
            ],
          );
        },
      ),
    ),
  );
}

class EditorExportAction extends StatelessWidget {
  const EditorExportAction({
    super.key,
    required this.enabled,
    required this.exporting,
    required this.onPressed,
  });

  final bool enabled;
  final bool exporting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = exporting ? context.l10n.starting : context.l10n.export;
    final action = MediaQuery.sizeOf(context).width <= 380
        ? IconButton.filledTonal(
            key: const ValueKey('editor-export-compact'),
            tooltip: label,
            onPressed: enabled ? onPressed : null,
            style: IconButton.styleFrom(
              minimumSize: const Size.square(48),
              foregroundColor: context.studioColors.primary,
              backgroundColor: context.studioColors.primary.withValues(
                alpha: .12,
              ),
            ),
            icon: const Icon(AppIcons.export),
          )
        : FilledButton.icon(
            key: const ValueKey('editor-export-labeled'),
            onPressed: enabled ? onPressed : null,
            icon: const Icon(AppIcons.export, size: 18),
            label: Text(label),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.padded,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            ),
          );
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
      child: action,
    );
  }
}

class EditorPlaybackControls extends StatelessWidget {
  const EditorPlaybackControls({
    super.key,
    required this.position,
    required this.duration,
    required this.playing,
    required this.onToggle,
    required this.onSeek,
  });

  final ValueListenable<Duration> position;
  final Duration duration;
  final bool playing;
  final VoidCallback onToggle;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Duration>(
    valueListenable: position,
    builder: (context, current, _) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxs),
          child: Row(
            children: [
              IconButton.filledTonal(
                tooltip: playing
                    ? context.l10n.pausePreview
                    : context.l10n.playPreview,
                onPressed: onToggle,
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(48),
                  foregroundColor: context.studioColors.primary,
                  backgroundColor: context.studioColors.primary.withValues(
                    alpha: .12,
                  ),
                ),
                icon: Icon(playing ? AppIcons.pause : AppIcons.play),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(
                  label:
                      '${context.l10n.previewPosition}: ${formatEditorTimestamp(current)} / ${formatEditorTimestamp(duration)}',
                  child: ExcludeSemantics(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '${formatEditorTimestamp(current)} / ${formatEditorTimestamp(duration)}',
                        style: Theme.of(context).textTheme.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (duration > Duration.zero)
          Semantics(
            label: context.l10n.previewPosition,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SliderTheme(
                data: editorSliderTheme(context),
                child: Slider(
                  key: const ValueKey('editor-playhead'),
                  value: current.inMilliseconds.toDouble().clamp(
                    0,
                    duration.inMilliseconds.toDouble(),
                  ),
                  max: duration.inMilliseconds.toDouble(),
                  onChanged: (value) =>
                      onSeek(Duration(milliseconds: value.round())),
                  semanticFormatterCallback: context.spokenValue(
                    (strings, value) => strings.secondsValue(value),
                    multiplier: .001,
                    digits: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

SliderThemeData editorSliderTheme(BuildContext context) {
  final colors = context.studioColors;
  return SliderThemeData(
    trackHeight: 4,
    activeTrackColor: colors.primary,
    inactiveTrackColor: colors.border,
    disabledActiveTrackColor: colors.disabled,
    disabledInactiveTrackColor: colors.border,
    thumbColor: colors.primary,
    overlayColor: colors.primary.withValues(alpha: .12),
    thumbShape: const RoundSliderThumbShape(
      enabledThumbRadius: 7,
      disabledThumbRadius: 7,
    ),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
    rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
    rangeThumbShape: const RoundRangeSliderThumbShape(
      enabledThumbRadius: 8,
      disabledThumbRadius: 8,
    ),
  );
}

class EditorTool extends StatelessWidget {
  const EditorTool({
    super.key,
    required this.label,
    required this.icon,
    this.selected = false,
    this.onPressed,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    enabled: onPressed != null,
    child: Tooltip(
      message: label,
      child: Material(
        color: selected
            ? context.studioColors.primary.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? .18
                    : .12,
              )
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: onPressed == null
                      ? context.studioColors.muted
                      : selected
                      ? context.studioColors.primary
                      : context.studioColors.text,
                ),
                const SizedBox(height: 4),
                Text(label, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class EditorToolStrip extends StatelessWidget {
  const EditorToolStrip({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
    // Docked like the app's navigation bar: soft surface, fading edge.
    child: StudioFadeBorder(
      radius: AppRadius.feature,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: Row(children: children),
      ),
    ),
  );
}
