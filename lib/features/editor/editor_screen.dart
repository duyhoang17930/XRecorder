import 'package:xrecorder/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/studio_widgets.dart';
import '../../core/domain/models.dart';
import 'project_controller.dart';
import 'project_repository.dart';
import 'editor_preview.dart';
import 'media_picker.dart';
import 'project_effects.dart';
import 'subtitles.dart';
import 'subtitle_editor.dart';

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
  bool exporting = false, pickingMedia = false;
  bool leaving = false, allowLeave = false;
  Future<void> leave() async {
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
      builder: (_) => _ProjectNameDialog(initial: controller!.project.title),
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

  @override
  void dispose() {
    controller?.dispose();
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
        selected = selected.clamp(0, (project.clips.length - 1).clamp(0, 30));
        final clip = project.clips.isEmpty ? null : project.clips[selected];
        return PopScope(
          canPop: allowLeave || (!model.saving && model.saveError == null),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) leave();
          },
          child: Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: leave),
              actions: [
                IconButton(
                  tooltip: context.l10n.renameProject,
                  onPressed: renameProject,
                  icon: const Icon(AppIcons.rename),
                ),
              ],
              title: Tooltip(
                message: project.title,
                child: Text(
                  project.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: context.l10n.undoEdit,
                      onPressed: model.canUndo ? model.undo : null,
                      icon: const Icon(AppIcons.undo),
                    ),
                    IconButton(
                      tooltip: context.l10n.redoEdit,
                      onPressed: model.canRedo ? model.redo : null,
                      icon: const Icon(AppIcons.redo),
                    ),
                    FilledButton.icon(
                      onPressed: exporting || project.clips.isEmpty
                          ? null
                          : export,
                      icon: Icon(
                        exporting ? AppIcons.processing : AppIcons.export,
                      ),
                      label: Text(
                        exporting ? context.l10n.starting : context.l10n.export,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  context.message(
                    model.saveError != null
                        ? UserMessages.failure(
                            model.saveError,
                            operation: UserOperation.saveDraft,
                          ).text
                        : (model.saving
                              ? context.l10n.savingDraft
                              : context.l10n.savedOriginalsUnchanged),
                  ),
                ),
                if (model.saveError != null)
                  TextButton(
                    onPressed: model.retrySave,
                    child: Text(context.l10n.retrySaving),
                  ),
                if (project.clips.isNotEmpty)
                  EditorPreview(
                    key: preview,
                    project: project,
                    onPosition: (value) {
                      if (mounted) setState(() => position = value);
                    },
                  )
                else
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: StudioEmptyState(
                      title: context.l10n.addYourFirstClip,
                      description: context.l10n.editACopyOriginalsStayUnchanged,
                      icon: AppIcons.videos,
                    ),
                  ),
                Text(
                  context.l10n.playheadTime(
                    context.displayValue(
                      context.decimal(
                        (position.inMilliseconds / 1000),
                        digits: 1,
                      ),
                    ),
                    context.displayValue(
                      context.decimal(
                        (project.duration.inMilliseconds / 1000),
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
                        value: position.inMilliseconds.toDouble().clamp(
                          0,
                          project.duration.inMilliseconds.toDouble(),
                        ),
                        max: project.duration.inMilliseconds.toDouble(),
                        onChanged: (v) =>
                            preview.currentState?.command('seek', v.round()),
                        semanticFormatterCallback: context.spokenValue(
                          (strings, value) => strings.secondsValue(value),
                          multiplier: .001,
                          digits: 1,
                        ),
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: project.clips.isEmpty
                          ? null
                          : () async {
                              try {
                                await preview.currentState?.command('pause');
                                if (!context.mounted) return;
                                final track = await editSubtitles(
                                  context,
                                  SubtitleTrack.decode(
                                    model.project.effects['subtitles'],
                                    model.project.duration.inMilliseconds,
                                  ),
                                  project: model.project,
                                );
                                if (mounted && track != null) {
                                  model.change(
                                    model.project.copyWith(
                                      effects: {
                                        ...model.project.effects,
                                        'subtitles': track.toJson(),
                                      },
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  showFailure(
                                    context,
                                    e,
                                    operation: UserOperation.editClip,
                                  );
                                }
                              }
                            },
                      icon: const Icon(AppIcons.captions),
                      label: Text(context.l10n.subtitles),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await preview.currentState?.command('pause');
                        if (!context.mounted) return;
                        final effects = await editProjectEffects(
                          context,
                          project.effects,
                          durationMs: project.duration.inMilliseconds,
                        );
                        if (effects != null && mounted) {
                          model.change(
                            model.project.copyWith(effects: effects),
                          );
                        }
                      },
                      icon: const Icon(AppIcons.settings),
                      label: Text(context.l10n.effects),
                    ),
                    TextButton.icon(
                      onPressed: pickingMedia ? null : add,
                      icon: const Icon(AppIcons.create),
                      label: Text(context.l10n.addClip),
                    ),
                    TextButton.icon(
                      onPressed: clip == null
                          ? null
                          : () => act(() => model.split(position)),
                      icon: const Icon(AppIcons.split),
                      label: Text(context.l10n.split),
                    ),
                  ],
                ),
                if (project.clips.isNotEmpty)
                  SectionTitle(context.l10n.timeline),
                if (project.clips.isNotEmpty)
                  SizedBox(
                    height:
                        AppSize.timeline *
                        (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
                          1,
                          2,
                        ),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (var i = 0; i < project.clips.length; i++)
                            InkWell(
                              onTap: () {
                                setState(() => selected = i);
                                preview.currentState?.command(
                                  'seek',
                                  project.clips
                                          .take(i)
                                          .fold<int>(
                                            0,
                                            (total, c) =>
                                                total +
                                                c.duration.inMilliseconds,
                                          ) ~/
                                      project.speed,
                                );
                              },
                              child: Container(
                                width: 150,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: context.studioColors.elevated,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.control,
                                  ),
                                  border: Border.all(
                                    color: selected == i
                                        ? Theme.of(context).colorScheme.primary
                                        : context.studioColors.border,
                                    width: AppBorder.focused,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: FutureBuilder<Uint8List?>(
                                        future: frame(
                                          project.clips[i].mediaId,
                                          project
                                              .clips[i]
                                              .inPoint
                                              .inMilliseconds,
                                        ),
                                        builder: (context, snapshot) =>
                                            snapshot.data == null
                                            ? const Center(
                                                child: Icon(AppIcons.videos),
                                              )
                                            : Image.memory(
                                                snapshot.data!,
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(
                                        AppSpacing.xs,
                                      ),
                                      child: Text(
                                        context.l10n.clipDurationLabel(
                                          context.displayValue(i + 1),
                                          context.displayValue(
                                            context.decimal(
                                              (project
                                                      .clips[i]
                                                      .duration
                                                      .inMilliseconds /
                                                  1000),
                                              digits: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                for (var i = 0; i < project.clips.length; i++)
                  Card(
                    color: selected == i
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          onTap: () => setState(() => selected = i),
                          title: Text(
                            context.l10n.sequenceLabel(
                              context.displayValue(i + 1),
                              context.displayValue(project.clips[i].title),
                            ),
                          ),
                          subtitle: Text(
                            context.l10n.secondsShort(
                              context.displayValue(
                                context.decimal(
                                  (project.clips[i].duration.inMilliseconds /
                                      1000),
                                  digits: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            children: [
                              IconButton(
                                tooltip: context.l10n.moveEarlier,
                                onPressed: i == 0
                                    ? null
                                    : () => model.move(i, i - 1),
                                icon: const Icon(AppIcons.moveEarlier),
                              ),
                              IconButton(
                                tooltip: context.l10n.moveLater,
                                onPressed: i == project.clips.length - 1
                                    ? null
                                    : () => model.move(i, i + 1),
                                icon: const Icon(AppIcons.moveLater),
                              ),
                              IconButton(
                                tooltip: context.l10n.duplicateClip,
                                onPressed: () => act(() => model.duplicate(i)),
                                icon: const Icon(AppIcons.create),
                              ),
                              IconButton(
                                tooltip: context.l10n.replaceSource,
                                onPressed: pickingMedia
                                    ? null
                                    : () => relink(i),
                                icon: const Icon(AppIcons.folderOpen),
                              ),
                              IconButton(
                                tooltip: context.l10n.removeClipFromProject,
                                onPressed: () => model.remove(i),
                                icon: const Icon(AppIcons.close),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (clip != null) ...[
                  const Divider(),
                  Text(
                    context.l10n.selectedClipName(
                      context.displayValue(clip.title),
                    ),
                  ),
                  Text(
                    context.l10n.trimTimeRange(
                      context.displayValue(
                        context.decimal(
                          (clip.inPoint.inMilliseconds / 1000),
                          digits: 1,
                        ),
                      ),
                      context.displayValue(
                        context.decimal(
                          (clip.outPoint.inMilliseconds / 1000),
                          digits: 1,
                        ),
                      ),
                    ),
                  ),
                  _EditRange(
                    label: context.l10n.trimClip,
                    seconds: true,
                    key: ValueKey(
                      'trim-$selected-${clip.inPoint}-${clip.outPoint}',
                    ),
                    value: RangeValues(
                      clip.inPoint.inMilliseconds.toDouble(),
                      clip.outPoint.inMilliseconds.toDouble(),
                    ),
                    max: clip.sourceDuration.inMilliseconds.toDouble(),
                    minimum: 200,
                    onCommit: (v) => act(
                      () => model.update(
                        selected,
                        clip.copyWith(
                          inPoint: Duration(milliseconds: v.start.round()),
                          outPoint: Duration(milliseconds: v.end.round()),
                        ),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => model.update(
                      selected,
                      clip.copyWith(rotation: (clip.rotation + 90) % 360),
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
                                sourceDuration: Duration(seconds: seconds),
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
                        clip.copyWith(cropLeft: v.start, cropRight: v.end),
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
                        clip.copyWith(cropTop: v.start, cropBottom: v.end),
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
        );
      },
    );
  }
}

class _ProjectNameDialog extends StatefulWidget {
  const _ProjectNameDialog({required this.initial});
  final String initial;
  @override
  State<_ProjectNameDialog> createState() => _ProjectNameDialogState();
}

class _ProjectNameDialogState extends State<_ProjectNameDialog> {
  late final field = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StudioDialog(
    title: Text(context.l10n.projectName),
    content: TextField(
      controller: field,
      maxLength: 80,
      decoration: InputDecoration(labelText: context.l10n.name),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      TextButton(
        onPressed: () {
          if (field.text.trim().isNotEmpty) {
            Navigator.pop(context, field.text.trim());
          }
        },
        child: Text(context.l10n.saveName),
      ),
    ],
  );
}

class _EditRange extends StatefulWidget {
  const _EditRange({
    super.key,
    required this.value,
    required this.max,
    required this.minimum,
    required this.onCommit,
    required this.label,
    this.seconds = false,
  });
  final RangeValues value;
  final double max, minimum;
  final ValueChanged<RangeValues> onCommit;
  final String label;
  final bool seconds;
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
        semanticFormatterCallback: widget.seconds
            ? context.spokenValue(
                (strings, value) => strings.secondsValue(value),
                multiplier: .001,
                digits: 1,
              )
            : context.spokenValue(
                (strings, value) => strings.accessibilityValue40(value),
                multiplier: 100,
              ),
      ),
    ),
  );
}
