import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/studio_widgets.dart';
import 'project_controller.dart';
import 'project_repository.dart';
import 'editor_preview.dart';
import 'media_picker.dart';

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
  final frames = <String, Future<Uint8List?>>{};
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
      showNotice(context, e.toString());
    }
  }

  Future<void> add() async {
    final media = await pickEditorMedia(context);
    if (media != null && mounted) act(() => controller!.add(media));
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
        appBar: AppBar(title: const Text('Editor')),
        body: Center(
          child: error == null
              ? const CircularProgressIndicator()
              : Text(error!),
        ),
      );
    }
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final project = model.project;
        selected = selected.clamp(0, (project.clips.length - 1).clamp(0, 30));
        final clip = project.clips.isEmpty ? null : project.clips[selected];
        return Scaffold(
          appBar: AppBar(
            title: Text(project.title),
            actions: [
              IconButton(
                tooltip: 'Undo edit',
                onPressed: model.canUndo ? model.undo : null,
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                tooltip: 'Redo edit',
                onPressed: model.canRedo ? model.redo : null,
                icon: const Icon(Icons.redo),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                model.saveError ??
                    (model.saving
                        ? 'Saving draft…'
                        : 'Draft saved · Originals unchanged'),
              ),
              if (model.saveError != null)
                TextButton(
                  onPressed: model.retrySave,
                  child: const Text('Retry saving'),
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
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('Add videos to begin a non-destructive project.'),
                ),
              Text(
                '${(position.inMilliseconds / 1000).toStringAsFixed(1)} / ${(project.duration.inMilliseconds / 1000).toStringAsFixed(1)} seconds',
              ),
              if (project.duration > Duration.zero)
                Slider(
                  value: position.inMilliseconds.toDouble().clamp(
                    0,
                    project.duration.inMilliseconds.toDouble(),
                  ),
                  max: project.duration.inMilliseconds.toDouble(),
                  onChanged: (v) =>
                      preview.currentState?.command('seek', v.round()),
                ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: add,
                    icon: const Icon(Icons.add),
                    label: const Text('Add clip / merge'),
                  ),
                  TextButton.icon(
                    onPressed: clip == null
                        ? null
                        : () => act(() => model.split(position)),
                    icon: const Icon(Icons.content_cut),
                    label: const Text('Split at playhead'),
                  ),
                ],
              ),
              if (project.clips.isNotEmpty)
                const Text('Timeline · clips play in order'),
              if (project.clips.isNotEmpty)
                SizedBox(
                  height: 100,
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
                                        total + c.duration.inMilliseconds,
                                  ),
                            );
                          },
                          child: Container(
                            width: 150,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: selected == i
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: FutureBuilder<Uint8List?>(
                                    future: frame(
                                      project.clips[i].mediaId,
                                      project.clips[i].inPoint.inMilliseconds,
                                    ),
                                    builder: (context, snapshot) =>
                                        snapshot.data == null
                                        ? const Center(
                                            child: Icon(Icons.movie_outlined),
                                          )
                                        : Image.memory(
                                            snapshot.data!,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                ),
                                Text(
                                  'Clip ${i + 1} · ${(project.clips[i].duration.inMilliseconds / 1000).toStringAsFixed(1)}s',
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              for (var i = 0; i < project.clips.length; i++)
                Card(
                  color: selected == i
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: ListTile(
                    onTap: () => setState(() => selected = i),
                    title: Text('${i + 1}. ${project.clips[i].title}'),
                    subtitle: Text(
                      '${(project.clips[i].duration.inMilliseconds / 1000).toStringAsFixed(1)}s',
                    ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Move earlier',
                          onPressed: i == 0 ? null : () => model.move(i, i - 1),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          tooltip: 'Move later',
                          onPressed: i == project.clips.length - 1
                              ? null
                              : () => model.move(i, i + 1),
                          icon: const Icon(Icons.arrow_downward),
                        ),
                        IconButton(
                          tooltip: 'Remove clip from project',
                          onPressed: () => model.remove(i),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
              if (clip != null) ...[
                const Divider(),
                Text('Selected clip: ${clip.title}'),
                Text(
                  'Trim ${(clip.inPoint.inMilliseconds / 1000).toStringAsFixed(1)}–${(clip.outPoint.inMilliseconds / 1000).toStringAsFixed(1)}s',
                ),
                _EditRange(
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
                  icon: const Icon(Icons.rotate_90_degrees_ccw),
                  label: Text('Rotate · ${clip.rotation}°'),
                ),
                const Text('Crop left / right'),
                _EditRange(
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
                const Text('Crop top / bottom'),
                _EditRange(
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
                    ),
                  ),
                  child: const Text('Reset crop & rotation'),
                ),
              ],
            ],
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
  });
  final RangeValues value;
  final double max, minimum;
  final ValueChanged<RangeValues> onCommit;
  @override
  State<_EditRange> createState() => _EditRangeState();
}

class _EditRangeState extends State<_EditRange> {
  late RangeValues value = widget.value;
  @override
  Widget build(BuildContext context) => RangeSlider(
    values: value,
    max: widget.max,
    onChanged: (v) {
      if (v.end - v.start >= widget.minimum) setState(() => value = v);
    },
    onChangeEnd: (_) => widget.onCommit(value),
  );
}
