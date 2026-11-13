import 'package:xrecorder/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/studio_widgets.dart';
import '../../core/ui/components/dialogs/studio_name_dialog.dart';
import '../../core/domain/models.dart';
import 'project_controller.dart';
import 'project_repository.dart';
import 'editor_preview.dart';
import 'media_picker.dart';
import 'project_effects.dart';
import 'subtitles.dart';
import 'subtitle_editor.dart';
import 'editor_workspace.dart';
import 'editor_timeline.dart';
import 'editor_selection.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.id});
  final String id;
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final repository = AndroidEditProjectRepository();
  final preview = GlobalKey<EditorPreviewState>();
  ProjectController? controller;
  String? error;
  int selected = 0;
  Duration position = Duration.zero;
  final playhead = ValueNotifier(Duration.zero);
  final timelineScroll = ScrollController();
  String? panel;
  bool exporting = false, pickingMedia = false;
  bool leaving = false, allowLeave = false;
  Future<void> leave() async {
    if (panel != null) {
      setState(() => panel = null);
      return;
    }
    if (leaving) return;
    leaving = true;
    try {
      final model = controller!;
      while (model.saving) {
        await model.flushed;
      }
      if (!mounted) return;
      if (model.saveError != null) {
        final discard = await showStudioDialog<bool>(
          context: context,
          builder: (dialog) => StudioDialog(
            title: Text(context.l10n.leaveWithoutSaving),
            content: Text(context.l10n.recentEditsCouldNotBeSavedKeep),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: Text(context.l10n.keepEditing),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: Text(context.l10n.leave),
              ),
            ],
          ),
        );
        if (discard != true || !mounted) return;
      }
      setState(() => allowLeave = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/editor');
        }
      }
    } finally {
      leaving = false;
    }
  }

  final frames = <String, Future<Uint8List?>>{};
  Future<void> renameProject() async {
    final name = await showStudioDialog<String>(
      context: context,
      builder: (dialog) => StudioNameDialog(
        initial: controller!.project.title,
        title: dialog.l10n.projectName,
        label: dialog.l10n.name,
        maxLength: 80,
        submitLabel: dialog.l10n.saveName,
        onSubmit: (value) {
          if (value.trim().isNotEmpty) Navigator.pop(dialog, value.trim());
        },
      ),
    );
    if (mounted && name != null) {
      controller!.change(controller!.project.copyWith(title: name));
    }
  }

  Future<Uint8List?> frame(String uri, int milliseconds) {
    final key = '$uri@$milliseconds';
    if (frames.length > 60) frames.remove(frames.keys.first);
    return frames.putIfAbsent(
      key,
      () => const MethodChannel('com.xrecorder/media').invokeMethod<Uint8List>(
        'thumbnailAt',
        {'uri': uri, 'timeMs': milliseconds},
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final project = await repository.find(widget.id);
      if (project == null) throw const FormatException('Draft not found');
      if (mounted) {
        setState(() => controller = ProjectController(project, repository));
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  void act(VoidCallback action) {
    try {
      action();
    } catch (e) {
      showFailure(context, e, operation: UserOperation.editClip);
    }
  }

  Future<void> add() async {
    if (pickingMedia) return;
    setState(() => pickingMedia = true);
    try {
      final media = await pickEditorMedia(context);
      if (media != null && mounted) act(() => controller!.add(media));
    } finally {
      if (mounted) setState(() => pickingMedia = false);
    }
  }

  void changeClips(VoidCallback action, {int? preferredSelection}) {
    final before = controller!.project.clips;
    final index = selected;
    act(() {
      action();
      if (!mounted) return;
      setState(() {
        final after = controller!.project.clips;
        selected = after.isEmpty
            ? 0
            : (preferredSelection ?? retainClipSelection(before, after, index))
                  .clamp(0, after.length - 1);
        if (controller!.project.clips.isEmpty) panel = null;
      });
    });
  }

  void clipOption(String value) {
    final model = controller!;
    final index = selected;
    switch (value) {
      case 'earlier':
        changeClips(
          () => model.move(index, index - 1),
          preferredSelection: index - 1,
        );
      case 'later':
        changeClips(
          () => model.move(index, index + 1),
          preferredSelection: index + 1,
        );
      case 'duplicate':
        changeClips(() => model.duplicate(index));
      case 'relink':
        relink(index);
      case 'remove':
        changeClips(() => model.remove(index), preferredSelection: index);
    }
  }

  Future<void> relink(int index) async {
    if (pickingMedia) return;
    setState(() => pickingMedia = true);
    try {
      final source = await pickEditorMedia(context);
      if (!mounted || source == null) return;
      final clip = controller!.project.clips[index];
      if (clip.isImage != (source.kind == MediaKind.image) ||
          (!clip.isImage &&
              (source.duration == null || source.duration! < clip.outPoint))) {
        throw const FormatException(
          'Choose the same media type with enough duration for this clip.',
        );
      }
      controller!.update(
        index,
        clip.copyWith(
          mediaId: source.uri.toString(),
          title: source.displayName,
          sourceDuration: clip.isImage ? clip.sourceDuration : source.duration,
        ),
      );
    } catch (e) {
      if (mounted) showFailure(context, e, operation: UserOperation.openMedia);
    } finally {
      if (mounted) setState(() => pickingMedia = false);
    }
  }

  Future<void> export() async {
    if (exporting || controller!.project.clips.isEmpty) return;
    final project = controller!.project;
    setState(() => exporting = true);
    try {
      await preview.currentState?.command('pause');
      await AndroidEditProjectRepository.channel.invokeMethod<String>(
        'exportStart',
        project.toJson(),
      );
      if (mounted) await context.push('/exports');
    } catch (e) {
      if (mounted) showFailure(context, e, operation: UserOperation.export);
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Future<void> effects([int section = 0]) async {
    await preview.currentState?.command('pause');
    if (!mounted) return;
    final model = controller!;
    final next = await editProjectEffects(
      context,
      model.project.effects,
      durationMs: model.project.duration.inMilliseconds,
      initialSection: section,
    );
    if (next != null && mounted) {
      model.change(model.project.copyWith(effects: next));
    }
  }

  Future<void> subtitles() async {
    try {
      await preview.currentState?.command('pause');
      if (!mounted) return;
      final model = controller!;
      final next = await editSubtitles(
        context,
        SubtitleTrack.decode(
          model.project.effects['subtitles'],
          model.project.duration.inMilliseconds,
        ),
        project: model.project,
      );
      if (mounted && next != null) {
        model.change(
          model.project.copyWith(
            effects: {...model.project.effects, 'subtitles': next.toJson()},
          ),
        );
      }
    } catch (e) {
      if (mounted) showFailure(context, e, operation: UserOperation.editClip);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    playhead.dispose();
    timelineScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = controller;
    if (model == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.editor)),
        body: Center(
          child: error == null
              ? StudioLoadingState(label: context.l10n.openingYourProject)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.message(
                        UserMessages.failure(
                          error,
                          operation: UserOperation.loadDrafts,
                        ).text,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => error = null);
                        load();
                      },
                      child: Text(context.l10n.retry),
                    ),
                  ],
                ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final project = model.project;
        if (project.clips.isEmpty) panel = null;
        selected = selected.clamp(0, (project.clips.length - 1).clamp(0, 30));
        final clip = project.clips.isEmpty ? null : project.clips[selected];
        void selectPanel(String next) =>
            setState(() => panel = panel == next ? null : next);
        return PopScope(
          canPop:
              panel == null &&
              (allowLeave || (!model.saving && model.saveError == null)),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) leave();
          },
          child: Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: leave),
              title: Tooltip(
                message: project.title,
                child: Text(
                  project.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: context.l10n.renameProject,
                  onPressed: renameProject,
                  icon: const Icon(AppIcons.rename),
                ),
                FilledButton(
                  onPressed: exporting || project.clips.isEmpty ? null : export,
                  child: Text(
                    exporting ? context.l10n.starting : context.l10n.export,
                  ),
                ),
              ],
            ),
            body: VideoEditorWorkspace(
              preview: project.clips.isNotEmpty
                  ? EditorPreview(
                      key: preview,
                      fitViewport: true,
                      project: project,
                      onPosition: (value) {
                        if (!mounted) return;
                        position = value;
                        playhead.value = value;
                      },
                    )
                  : Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StudioEmptyState(
                              title: context.l10n.addYourFirstClip,
                              description:
                                  context.l10n.editACopyOriginalsStayUnchanged,
                              icon: AppIcons.videos,
                            ),
                            TextButton.icon(
                              onPressed: pickingMedia ? null : add,
                              icon: const Icon(AppIcons.create),
                              label: Text(context.l10n.addClip),
                            ),
                          ],
                        ),
                      ),
                    ),
              status: Column(
                children: [
                  Text(
                    context.message(
                      model.saveError != null
                          ? UserMessages.failure(
                              model.saveError,
                              operation: UserOperation.saveDraft,
                            ).text
                          : model.saving
                          ? context.l10n.savingDraft
                          : context.l10n.savedOriginalsUnchanged,
                    ),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  if (model.saveError != null)
                    TextButton(
                      onPressed: model.retrySave,
                      child: Text(context.l10n.retrySaving),
                    ),
                ],
              ),
              transport: ValueListenableBuilder<Duration>(
                valueListenable: playhead,
                builder: (context, current, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.playheadTime(
                        context.displayValue(
                          context.decimal(
                            current.inMilliseconds / 1000,
                            digits: 1,
                          ),
                        ),
                        context.displayValue(
                          context.decimal(
                            project.duration.inMilliseconds / 1000,
                            digits: 1,
                          ),
                        ),
                      ),
                    ),
                    if (project.duration > Duration.zero)
                      Semantics(
                        label: context.l10n.previewPosition,
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Slider(
                            key: const ValueKey('editor-playhead'),
                            value: current.inMilliseconds.toDouble().clamp(
                              0,
                              project.duration.inMilliseconds.toDouble(),
                            ),
                            max: project.duration.inMilliseconds.toDouble(),
                            onChanged: (v) => preview.currentState?.command(
                              'seek',
                              v.round(),
                            ),
                            semanticFormatterCallback: context.spokenValue(
                              (strings, value) => strings.secondsValue(value),
                              multiplier: .001,
                              digits: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              timeline: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.timeline,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.addClip,
                        onPressed: pickingMedia ? null : add,
                        icon: const Icon(AppIcons.create),
                      ),
                    ],
                  ),
                  if (project.clips.isNotEmpty)
                    EditorTimeline(
                      project: project,
                      selected: selected,
                      position: playhead,
                      scrollController: timelineScroll,
                      frame: frame,
                      onSelect: (i) {
                        setState(() => selected = i);
                        final start =
                            project.clips
                                .take(i)
                                .fold<int>(
                                  0,
                                  (total, c) =>
                                      total + c.duration.inMilliseconds,
                                ) ~/
                            project.speed;
                        preview.currentState?.command('seek', start);
                      },
                      onSeek: (time) => preview.currentState?.command(
                        'seek',
                        time.inMilliseconds,
                      ),
                      onTrim: (i, range) => act(
                        () => model.update(
                          i,
                          project.clips[i].copyWith(
                            inPoint: Duration(
                              milliseconds: range.start.round(),
                            ),
                            outPoint: Duration(milliseconds: range.end.round()),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              tools: EditorToolStrip(
                children: [
                  EditorTool(
                    label: context.l10n.edit,
                    icon: AppIcons.split,
                    selected: panel == 'edit',
                    onPressed: clip == null ? null : () => selectPanel('edit'),
                  ),
                  EditorTool(
                    label: context.l10n.editorAudio,
                    icon: AppIcons.microphone,
                    onPressed: () => effects(1),
                  ),
                  EditorTool(
                    label: context.message('Text'),
                    icon: AppIcons.text,
                    onPressed: () => effects(3),
                  ),
                  EditorTool(
                    label: context.l10n.subtitles,
                    icon: AppIcons.captions,
                    onPressed: project.clips.isEmpty ? null : subtitles,
                  ),
                  EditorTool(
                    label: context.l10n.effects,
                    icon: AppIcons.edit,
                    onPressed: () => effects(),
                  ),
                  EditorTool(
                    label: context.l10n.editorTransform,
                    icon: AppIcons.crop,
                    selected: panel == 'transform',
                    onPressed: clip == null
                        ? null
                        : () => selectPanel('transform'),
                  ),
                  EditorTool(
                    label: context.l10n.editorExportQuality,
                    icon: AppIcons.settings,
                    onPressed: () => effects(4),
                  ),
                ],
              ),
              history: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: context.l10n.undoEdit,
                    onPressed: model.canUndo
                        ? () => changeClips(model.undo)
                        : null,
                    icon: const Icon(AppIcons.undo),
                  ),
                  IconButton(
                    tooltip: context.l10n.redoEdit,
                    onPressed: model.canRedo
                        ? () => changeClips(model.redo)
                        : null,
                    icon: const Icon(AppIcons.redo),
                  ),
                ],
              ),
              contextual: clip == null || panel == null
                  ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                panel == 'edit'
                                    ? context.l10n.edit
                                    : context.l10n.editorTransform,
                              ),
                            ),
                            IconButton(
                              tooltip: context.l10n.close,
                              onPressed: () => setState(() => panel = null),
                              icon: const Icon(AppIcons.close),
                            ),
                          ],
                        ),
                        if (panel == 'edit') ...[
                          Tooltip(
                            message: clip.title,
                            child: Text(
                              context.l10n.selectedClipName(clip.title),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            context.l10n.trimTimeRange(
                              context.displayValue(
                                context.decimal(
                                  clip.inPoint.inMilliseconds / 1000,
                                  digits: 1,
                                ),
                              ),
                              context.displayValue(
                                context.decimal(
                                  clip.outPoint.inMilliseconds / 1000,
                                  digits: 1,
                                ),
                              ),
                            ),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                onPressed: () =>
                                    changeClips(() => model.split(position)),
                                icon: const Icon(AppIcons.split),
                                label: Text(context.l10n.split),
                              ),
                              PopupMenuButton<String>(
                                tooltip: context.l10n.clipOptions,
                                onSelected: clipOption,
                                icon: const Icon(AppIcons.more),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'duplicate',
                                    child: Text(context.l10n.duplicateClip),
                                  ),
                                  PopupMenuItem(
                                    value: 'earlier',
                                    enabled: selected > 0,
                                    child: Text(context.l10n.moveEarlier),
                                  ),
                                  PopupMenuItem(
                                    value: 'later',
                                    enabled:
                                        selected < project.clips.length - 1,
                                    child: Text(context.l10n.moveLater),
                                  ),
                                  PopupMenuItem(
                                    value: 'relink',
                                    enabled: !pickingMedia,
                                    child: Text(context.l10n.replaceSource),
                                  ),
                                  PopupMenuItem(
                                    value: 'remove',
                                    child: Text(
                                      context.l10n.removeClipFromProject,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                        if (panel == 'transform') ...[
                          TextButton.icon(
                            onPressed: () => model.update(
                              selected,
                              clip.copyWith(
                                rotation: (clip.rotation + 90) % 360,
                              ),
                            ),
                            icon: const Icon(AppIcons.rotate),
                            label: Text(
                              context.l10n.rotationValue(
                                context.displayValue(clip.rotation),
                              ),
                            ),
                          ),
                          Wrap(
                            children: [
                              TextButton(
                                onPressed: () => model.update(
                                  selected,
                                  clip.copyWith(flipH: !clip.flipH),
                                ),
                                child: Text(
                                  context.l10n.flipHorizontalState(
                                    clip.flipH ? ' · ${context.l10n.on}' : '',
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => model.update(
                                  selected,
                                  clip.copyWith(flipV: !clip.flipV),
                                ),
                                child: Text(
                                  context.l10n.flipVerticalState(
                                    clip.flipV ? ' · ${context.l10n.on}' : '',
                                  ),
                                ),
                              ),
                              if (clip.isImage)
                                for (final seconds in [2, 5, 10])
                                  TextButton(
                                    onPressed: () => model.update(
                                      selected,
                                      clip.copyWith(
                                        inPoint: Duration.zero,
                                        outPoint: Duration(seconds: seconds),
                                        sourceDuration: Duration(
                                          seconds: seconds,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      context.l10n.photoDuration(
                                        context.displayValue(seconds),
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                          Text(context.l10n.cropLeftRight),
                          _EditRange(
                            label: context.l10n.cropLeftAndRight,
                            key: ValueKey(
                              'horizontal-$selected-${clip.cropLeft}-${clip.cropRight}',
                            ),
                            value: RangeValues(clip.cropLeft, clip.cropRight),
                            max: 1,
                            minimum: .02,
                            onCommit: (v) => act(
                              () => model.update(
                                selected,
                                clip.copyWith(
                                  cropLeft: v.start,
                                  cropRight: v.end,
                                ),
                              ),
                            ),
                          ),
                          Text(context.l10n.cropTopBottom),
                          _EditRange(
                            label: context.l10n.cropTopAndBottom,
                            key: ValueKey(
                              'vertical-$selected-${clip.cropTop}-${clip.cropBottom}',
                            ),
                            value: RangeValues(clip.cropTop, clip.cropBottom),
                            max: 1,
                            minimum: .02,
                            onCommit: (v) => act(
                              () => model.update(
                                selected,
                                clip.copyWith(
                                  cropTop: v.start,
                                  cropBottom: v.end,
                                ),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => model.update(
                              selected,
                              clip.copyWith(
                                cropLeft: 0,
                                cropTop: 0,
                                cropRight: 1,
                                cropBottom: 1,
                                rotation: 0,
                                flipH: false,
                                flipV: false,
                              ),
                            ),
                            child: Text(context.l10n.resetCropRotation),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _EditRange extends StatefulWidget {
  const _EditRange({
    super.key,
    required this.value,
    required this.max,
    required this.minimum,
    required this.onCommit,
    required this.label,
  });
  final RangeValues value;
  final double max, minimum;
  final ValueChanged<RangeValues> onCommit;
  final String label;
  @override
  State<_EditRange> createState() => _EditRangeState();
}

class _EditRangeState extends State<_EditRange> {
  late RangeValues value = widget.value;
  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: RangeSlider(
        values: value,
        max: widget.max,
        onChanged: (v) {
          if (v.end - v.start >= widget.minimum) setState(() => value = v);
        },
        onChangeEnd: (_) => widget.onCommit(value),
        semanticFormatterCallback: context.spokenValue(
          (strings, value) => strings.accessibilityValue40(value),
          multiplier: 100,
        ),
      ),
    ),
  );
}
