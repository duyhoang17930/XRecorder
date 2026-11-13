import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/domain/models.dart';
import '../../core/widgets/studio_widgets.dart';
import '../../l10n/localization.dart';

class EditorTimeline extends StatelessWidget {
  const EditorTimeline({
    super.key,
    required this.project,
    required this.selected,
    required this.position,
    required this.scrollController,
    required this.frame,
    required this.onSelect,
    required this.onSeek,
    required this.onTrim,
  });
  final EditProject project;
  final int selected;
  final ValueListenable<Duration> position;
  final ScrollController scrollController;
  final Future<Uint8List?> Function(String, int) frame;
  final ValueChanged<int> onSelect;
  final ValueChanged<Duration> onSeek;
  final void Function(int, RangeValues) onTrim;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 112 + MediaQuery.textScalerOf(context).scale(12) * 2,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: ListView.builder(
        key: const PageStorageKey('editor-timeline'),
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: project.clips.length,
        itemBuilder: (context, i) {
          final clip = project.clips[i];
          final width =
              (clip.duration.inMilliseconds / project.speed / 1000 * 48).clamp(
                144.0,
                240.0,
              );
          final startMs =
              project.clips
                  .take(i)
                  .fold<int>(0, (sum, c) => sum + c.duration.inMilliseconds) /
              project.speed;
          final durationMs = clip.duration.inMilliseconds / project.speed;
          void seek(Offset local) => onSeek(
            Duration(
              milliseconds:
                  (startMs + local.dx.clamp(0, width) / width * durationMs)
                      .round(),
            ),
          );
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: SizedBox(
              width: width,
              child: GestureDetector(
                onLongPressStart: (d) => seek(d.localPosition),
                onLongPressMoveUpdate: (d) => seek(d.localPosition),
                child: Semantics(
                  selected: selected == i,
                  child: Material(
                    color: context.studioColors.elevated,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      side: BorderSide(
                        color: selected == i
                            ? context.studioColors.primary
                            : context.studioColors.border,
                        width: 2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onSelect(i),
                      child: Column(
                        children: [
                          Expanded(
                            child: ValueListenableBuilder<Duration>(
                              valueListenable: position,
                              child: FutureBuilder<Uint8List?>(
                                future: frame(
                                  clip.mediaId,
                                  clip.inPoint.inMilliseconds,
                                ),
                                builder: (context, snapshot) =>
                                    snapshot.data == null
                                    ? const Center(child: Icon(AppIcons.videos))
                                    : Image.memory(
                                        snapshot.data!,
                                        fit: BoxFit.cover,
                                        width: width,
                                        gaplessPlayback: true,
                                      ),
                              ),
                              builder: (context, current, image) {
                                final fraction =
                                    (current.inMilliseconds - startMs) /
                                    durationMs;
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    image!,
                                    if (fraction >= 0 && fraction <= 1)
                                      Positioned(
                                        left: fraction * (width - 3),
                                        top: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 3,
                                          color: context.studioColors.primary,
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                          Text(
                            context.l10n.clipDurationLabel(
                              context.displayValue(i + 1),
                              context.displayValue(
                                context.decimal(durationMs / 1000, digits: 1),
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (selected == i)
                            _TimelineTrim(
                              key: ValueKey('timeline-trim-$i-${clip.mediaId}'),
                              clip: clip,
                              onCommit: (range) => onTrim(i, range),
                            )
                          else
                            const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _TimelineTrim extends StatefulWidget {
  const _TimelineTrim({super.key, required this.clip, required this.onCommit});
  final TimelineClip clip;
  final ValueChanged<RangeValues> onCommit;
  @override
  State<_TimelineTrim> createState() => _TimelineTrimState();
}

class _TimelineTrimState extends State<_TimelineTrim> {
  late RangeValues values = _range;
  bool dragging = false;
  RangeValues get _range => RangeValues(
    widget.clip.inPoint.inMilliseconds.toDouble(),
    widget.clip.outPoint.inMilliseconds.toDouble(),
  );
  @override
  void didUpdateWidget(covariant _TimelineTrim oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!dragging) values = _range;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Semantics(
      label: context.l10n.trimClip,
      child: RangeSlider(
        values: values,
        max: widget.clip.sourceDuration.inMilliseconds.toDouble(),
        onChangeStart: (_) => dragging = true,
        onChanged: (next) {
          if (next.start.isFinite &&
              next.end.isFinite &&
              next.end - next.start >= 200) {
            setState(() => values = next);
          }
        },
        onChangeEnd: (_) {
          dragging = false;
          widget.onCommit(values);
        },
        semanticFormatterCallback: context.spokenValue(
          (strings, value) => strings.secondsValue(value),
          multiplier: .001,
          digits: 1,
        ),
      ),
    ),
  );
}
