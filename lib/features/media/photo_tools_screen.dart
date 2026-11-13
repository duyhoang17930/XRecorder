import 'package:xrecorder/l10n/localization.dart';

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/widgets/studio_widgets.dart';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'media_repository.dart';
import 'photo_editor_panels.dart';
import '../editor/editor_workspace.dart';

class PhotoMark {
  PhotoMark(
    this.tool,
    this.color,
    this.points, {
    this.width = .006,
    this.text = '',
  });
  final String tool;
  final Color color;
  final List<Offset> points;
  final double width;
  final String text;
}

typedef _PhotoSnapshot = ({
  List<PhotoMark> marks,
  RangeValues horizontal,
  RangeValues vertical,
  int turns,
  bool flipH,
  bool flipV,
});

Future<ui.Image> renderPhotoCopy(
  ui.Image source,
  List<PhotoMark> marks,
  Rect crop, {
  int turns = 0,
  bool flipH = false,
  bool flipV = false,
}) async {
  final width = turns.isOdd ? crop.height : crop.width;
  final height = turns.isOdd ? crop.width : crop.height;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..translate(width / 2, height / 2)
    ..rotate(turns * math.pi / 2)
    ..scale(flipH ? -1.0 : 1.0, flipV ? -1.0 : 1.0)
    ..translate(-crop.width / 2 - crop.left, -crop.height / 2 - crop.top);
  PhotoPainter(
    source,
    marks,
  ).paint(canvas, Size(source.width.toDouble(), source.height.toDouble()));
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(
      width.round().clamp(1, 2048),
      height.round().clamp(1, 2048),
    );
  } finally {
    picture.dispose();
  }
}

/// Edits a copy of a full-screen screenshot; coordinates are image-relative.
class PhotoToolsScreen extends StatefulWidget {
  const PhotoToolsScreen({super.key, required this.uri});
  final String uri;
  @override
  State<PhotoToolsScreen> createState() => _PhotoToolsScreenState();
}

class _PhotoToolsScreenState extends State<PhotoToolsScreen> {
  static const channel = MethodChannel('com.xrecorder/media');
  ui.Image? image;
  String? error;
  bool saving = false;
  bool leaving = false, allowLeave = false;
  bool get dirty =>
      marks.isNotEmpty ||
      horizontal != const RangeValues(0, 1) ||
      vertical != const RangeValues(0, 1);
  int turns = 0;
  String exportFormat = 'png';
  int exportEdge = 2048, jpegQuality = 95;
  bool flipH = false, flipV = false;
  Future<void> leave() async {
    if (leaving || saving) return;
    leaving = true;
    try {
      final discard =
          !(dirty || turns != 0 || flipH || flipV) ||
          await showStudioDialog<bool>(
                context: context,
                builder: (dialog) => StudioDialog(
                  title: Text(dialog.l10n.discardPhotoEdits),
                  content: Text(dialog.l10n.yourOriginalPhotoIsUnchangedSaveA),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: Text(dialog.l10n.keepEditing),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: Text(dialog.l10n.discardEdits),
                    ),
                  ],
                ),
              ) ==
              true;
      if (!mounted || !discard) return;
      setState(() => allowLeave = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/photos');
        }
      }
    } finally {
      leaving = false;
    }
  }

  String tool = 'Pen';
  Color color = Colors.red;
  double strokeWidth = .006;
  String panel = 'draw';
  PhotoMark? _activeMark;
  final _canvasRevision = ValueNotifier<int>(0);
  final _toolAnchors = <String, GlobalKey>{};
  final label = TextEditingController();
  final _textFocus = FocusNode();
  final _textFieldKey = GlobalKey(debugLabel: 'photo-annotation-text');
  (Size, EdgeInsets, EdgeInsets, double, Locale, TextDirection)? _toolLayout;
  RangeValues horizontal = const RangeValues(0, 1),
      vertical = const RangeValues(0, 1);
  final marks = <PhotoMark>[];
  final undoHistory = <_PhotoSnapshot>[], redoHistory = <_PhotoSnapshot>[];
  _PhotoSnapshot snapshot() => (
    marks: marks
        .map(
          (m) => PhotoMark(
            m.tool,
            m.color,
            List.of(m.points),
            width: m.width,
            text: m.text,
          ),
        )
        .toList(),
    horizontal: horizontal,
    vertical: vertical,
    turns: turns,
    flipH: flipH,
    flipV: flipV,
  );
  void restore(_PhotoSnapshot value) {
    marks
      ..clear()
      ..addAll(
        value.marks.map(
          (m) => PhotoMark(
            m.tool,
            m.color,
            List.of(m.points),
            width: m.width,
            text: m.text,
          ),
        ),
      );
    horizontal = value.horizontal;
    vertical = value.vertical;
    turns = value.turns;
    flipH = value.flipH;
    flipV = value.flipV;
  }

  void remember() {
    undoHistory.add(snapshot());
    if (undoHistory.length > 50) undoHistory.removeAt(0);
    redoHistory.clear();
  }

  void undoMark() {
    _activeMark = null;
    redoHistory.add(snapshot());
    restore(undoHistory.removeLast());
  }

  void redoMark() {
    _activeMark = null;
    undoHistory.add(snapshot());
    restore(redoHistory.removeLast());
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reveal after geometry/locale changes only. Accessibility attachment also
    // updates MediaQuery; it must not undo the user's manual toolbar scroll.
    final layout = (
      MediaQuery.sizeOf(context),
      MediaQuery.viewInsetsOf(context),
      MediaQuery.paddingOf(context),
      MediaQuery.textScalerOf(context).scale(14),
      Localizations.localeOf(context),
      Directionality.of(context),
    );
    if (_toolLayout != layout) {
      _toolLayout = layout;
      _revealTool(_selectedTool);
    }
  }

  String get _selectedTool => panel != 'draw'
      ? panel
      : ['Rectangle', 'Circle', 'Arrow'].contains(tool)
      ? 'shapes'
      : tool == 'Pen' || tool == 'Eraser'
      ? 'pen'
      : tool.toLowerCase();

  Future<void> load() async {
    try {
      final bytes = await channel.invokeMethod<Uint8List>('decodePhoto', {
        'uri': widget.uri,
      });
      if (bytes == null) throw StateError('Image unavailable');
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (width, height) {
          final scale = math.min(1.0, 2048 / math.max(width, height));
          return ui.TargetImageSize(
            width: math.max(1, (width * scale).round()),
            height: math.max(1, (height * scale).round()),
          );
        },
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (mounted) {
        setState(() => image = frame.image);
      } else {
        frame.image.dispose();
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = UserMessages.failure(
            e,
            operation: UserOperation.loadPhoto,
          ).text,
        );
      }
    }
  }

  Future<void> save() async {
    final source = image;
    if (source == null || saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final width = source.width.toDouble(), height = source.height.toDouble();
      final crop = Rect.fromLTRB(
        horizontal.start * width,
        vertical.start * height,
        horizontal.end * width,
        vertical.end * height,
      );
      final output = await renderPhotoCopy(
        source,
        marks,
        crop,
        turns: turns,
        flipH: flipH,
        flipV: flipV,
      );
      ByteData? bytes;
      try {
        bytes = await output.toByteData(format: ui.ImageByteFormat.png);
      } finally {
        output.dispose();
      }
      final uri = await channel.invokeMethod<String>('saveImage', {
        'bytes': bytes!.buffer.asUint8List(),
        'format': exportFormat,
        'maxEdge': exportEdge,
        'quality': jpegQuality,
      });
      if (uri == null) throw StateError('No image was saved');
      if (mounted) {
        setState(() => allowLeave = true);
        MediaScope.of(context).refresh();
        context.pushReplacement('/media/${Uri.encodeComponent(uri)}');
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = UserMessages.failure(
            e,
            operation: UserOperation.savePhoto,
          ).text,
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    _canvasRevision.dispose();
    image?.dispose();
    label.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  Future<void> _exportOptions() async {
    final next = await editPhotoExportOptions(context, (
      format: exportFormat,
      maxEdge: exportEdge,
      quality: jpegQuality,
    ));
    if (mounted && next != null) {
      setState(() {
        exportFormat = next.format;
        exportEdge = next.maxEdge;
        jpegQuality = next.quality;
      });
    }
  }

  Future<void> _ink() async {
    final next = await choosePhotoInk(context, color);
    if (mounted && next != null) setState(() => color = next);
  }

  void _tool(String next) {
    setState(() {
      _activeMark = null;
      panel = 'draw';
      tool = next;
    });
    _revealTool(_selectedTool);
  }

  void _revealTool(String name) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _toolAnchors['photo-tool-$name']?.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: .5,
          duration: context.motion(AppMotion.standard),
        );
      }
    });
  }

  void _selectPanel(String name) {
    setState(() {
      _activeMark = null;
      panel = name;
    });
    _revealTool(name);
  }

  Future<void> _allTools() async {
    final next = await choosePhotoTool(
      context,
      title: context.l10n.editorAllTools,
      icon: AppIcons.tools,
      selected: panel == 'draw' ? tool : panel,
      isScrollControlled: true,
      tools: [
        for (final value in [
          'Pen',
          'Rectangle',
          'Circle',
          'Arrow',
          'Text',
          'Eraser',
        ])
          (value, context.message(value)),
        ('crop', context.l10n.editorCrop),
        ('transform', context.l10n.editorTransform),
      ],
    );
    if (!mounted || next == null) return;
    if (next == 'crop' || next == 'transform') {
      _selectPanel(next);
    } else {
      _tool(next);
    }
  }

  Future<void> _shapes() async {
    final next = await choosePhotoTool(
      context,
      title: context.l10n.editorShapes,
      icon: AppIcons.shapes,
      selected: panel == 'draw' ? tool : '',
      selectedTileColor: context.studioColors.primary.withValues(alpha: .10),
      tools: [
        for (final shape in ['Rectangle', 'Circle', 'Arrow'])
          (shape, context.message(shape)),
      ],
    );
    if (mounted && next != null) _tool(next);
  }

  void _crop(RangeValues next, bool isHorizontal) {
    if (!next.start.isFinite || !next.end.isFinite) return;
    final bounded = RangeValues(next.start.clamp(0, 1), next.end.clamp(0, 1));
    if (bounded.end - bounded.start < .02) return;
    setState(() {
      if (isHorizontal) {
        horizontal = bounded;
      } else {
        vertical = bounded;
      }
    });
  }

  Widget _toolbar(double height) {
    final shapes = ['Rectangle', 'Circle', 'Arrow'].contains(tool);
    Widget button(
      String name,
      IconData icon,
      bool selected,
      VoidCallback action,
      String id,
    ) => Padding(
      key: _toolAnchors.putIfAbsent(id, () => GlobalKey()),
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSize.touchTarget),
        child: EditorTool(
          key: ValueKey(id),
          icon: icon,
          label: name,
          selected: selected,
          onPressed: saving ? null : action,
        ),
      ),
    );
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  button(
                    context.l10n.editorCrop,
                    AppIcons.crop,
                    panel == 'crop',
                    () => _selectPanel('crop'),
                    'photo-tool-crop',
                  ),
                  button(
                    context.l10n.drawing,
                    AppIcons.pen,
                    panel == 'draw' && (tool == 'Pen' || tool == 'Eraser'),
                    () => _tool('Pen'),
                    'photo-tool-pen',
                  ),
                  button(
                    context.l10n.editorShapes,
                    AppIcons.shapes,
                    panel == 'draw' && shapes,
                    _shapes,
                    'photo-tool-shapes',
                  ),
                  button(
                    context.message('Text'),
                    AppIcons.text,
                    panel == 'draw' && tool == 'Text',
                    () => _tool('Text'),
                    'photo-tool-text',
                  ),
                  button(
                    context.l10n.editorTransform,
                    AppIcons.rotate,
                    panel == 'transform',
                    () => _selectPanel('transform'),
                    'photo-tool-transform',
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: context.l10n.editorAllTools,
            onPressed: saving ? null : _allTools,
            icon: const Icon(AppIcons.tools),
          ),
        ],
      ),
    );
  }

  Widget _cropSlider(
    String title,
    String semanticLabel,
    RangeValues value,
    bool isHorizontal,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: AppTypography.bodyEmphasis),
      Text(
        '${context.displayValue((value.start * 100).round())}% – '
        '${context.displayValue((value.end * 100).round())}%',
        style: AppTypography.caption.copyWith(
          color: context.studioColors.muted,
        ),
      ),
      Semantics(
        label: semanticLabel,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: RangeSlider(
            key: ValueKey(
              isHorizontal ? 'photo-crop-horizontal' : 'photo-crop-vertical',
            ),
            values: value,
            onChangeStart: saving ? null : (_) => remember(),
            onChanged: saving ? null : (v) => _crop(v, isHorizontal),
            semanticFormatterCallback: context.spokenValue(
              (strings, value) => strings.accessibilityValue40(value),
              multiplier: 100,
            ),
          ),
        ),
      ),
    ],
  );

  Widget _drawingTools() => Wrap(
    spacing: AppSpacing.xs,
    children: [
      for (final value in ['Pen', 'Eraser'])
        ChoiceChip(
          key: ValueKey('photo-context-${value.toLowerCase()}'),
          label: Text(context.message(value)),
          avatar: Icon(
            value == 'Pen' ? AppIcons.pen : AppIcons.eraser,
            size: AppIconSize.small,
          ),
          selected: tool == value,
          onSelected: saving ? null : (_) => _tool(value),
        ),
    ],
  );

  void _applyText() {
    final text = label.text.trim();
    if (saving || text.isEmpty) return;
    setState(() {
      remember();
      _activeMark = null;
      marks.add(
        PhotoMark(
          'Text',
          color,
          [const Offset(.5, .5)],
          width: strokeWidth,
          text: text,
        ),
      );
    });
    _textFocus.unfocus();
  }

  Widget _contextualControls(ui.Image source, {bool compact = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (error != null)
        Text(
          context.message(error!),
          style: TextStyle(color: context.studioColors.warning),
        ),
      if (panel == 'draw' && ['Rectangle', 'Circle', 'Arrow'].contains(tool))
        Text(context.message(tool), style: AppTypography.bodyEmphasis),
      if (panel == 'crop') ...[
        _cropSlider(
          context.l10n.cropLeftRight,
          context.l10n.cropLeftAndRight,
          horizontal,
          true,
        ),
        _cropSlider(
          context.l10n.cropTopBottom,
          context.l10n.cropTopAndBottom,
          vertical,
          false,
        ),
        TextButton(
          onPressed: saving
              ? null
              : () => setState(() {
                  remember();
                  horizontal = const RangeValues(0, 1);
                  vertical = const RangeValues(0, 1);
                }),
          child: Text(context.l10n.resetCrop),
        ),
      ] else if (panel == 'transform') ...[
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            OutlinedButton.icon(
              onPressed: saving
                  ? null
                  : () => setState(() {
                      remember();
                      turns = (turns + 1) % 4;
                    }),
              icon: const Icon(AppIcons.rotate),
              label: Text(context.l10n.rotate90),
            ),
            FilterChip(
              chipAnimationStyle: AppMotion.chipStyle(
                reduceMotion: context.reduceMotion,
              ),
              label: Text(context.l10n.flipHorizontalState('')),
              avatar: const Icon(
                AppIcons.flipHorizontal,
                size: AppIconSize.small,
              ),
              selected: flipH,
              onSelected: saving
                  ? null
                  : (v) => setState(() {
                      remember();
                      flipH = v;
                    }),
            ),
            FilterChip(
              chipAnimationStyle: AppMotion.chipStyle(
                reduceMotion: context.reduceMotion,
              ),
              label: Text(context.l10n.flipVerticalState('')),
              avatar: const Icon(
                AppIcons.flipVertical,
                size: AppIconSize.small,
              ),
              selected: flipV,
              onSelected: saving
                  ? null
                  : (v) => setState(() {
                      remember();
                      flipV = v;
                    }),
            ),
          ],
        ),
      ] else if (tool == 'Eraser') ...[
        _drawingTools(),
        Text(context.l10n.photoDragToErase),
      ] else ...[
        if (!compact || tool != 'Text')
          Semantics(
            label: photoInkName(context, color),
            child: OutlinedButton.icon(
              key: const ValueKey('photo-current-color'),
              onPressed: saving ? null : _ink,
              icon: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.studioColors.outline),
                ),
              ),
              label: Text(context.l10n.editorColor),
            ),
          ),
        if (!compact || tool != 'Text') const SizedBox(height: AppSpacing.xs),
        if (tool == 'Pen') _drawingTools(),
        if (tool == 'Text') ...[
          TextField(
            key: _textFieldKey,
            controller: label,
            focusNode: _textFocus,
            maxLength: 120,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _textFocus.unfocus(),
            decoration: InputDecoration(
              labelText: context.l10n.textToPlaceOnPhoto,
              suffixIcon: StudioClearTextButton(
                controller: label,
                enabled: !saving,
              ),
              counterText: compact ? '' : null,
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: label,
            builder: (context, value, _) => TextButton(
              onPressed: saving || value.text.trim().isEmpty
                  ? null
                  : _applyText,
              child: Text(context.l10n.editorApply),
            ),
          ),
        ] else ...[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            children: [
              Text(context.l10n.strokeWidth, style: AppTypography.bodyEmphasis),
              Text(
                context.l10n.pixelCount(
                  context.displayValue(
                    math.max(2, (strokeWidth * source.width).round()),
                  ),
                ),
              ),
            ],
          ),
          Semantics(
            label: context.l10n.strokeWidth,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Slider(
                key: const ValueKey('photo-stroke-width'),
                value: strokeWidth,
                min: .002,
                max: .02,
                onChanged: saving
                    ? null
                    : (value) {
                        if (!value.isFinite) return;
                        setState(() {
                          // Slider._lerp(1) can round .02 above the valid maximum.
                          strokeWidth = value.clamp(.002, .02);
                        });
                      },
                semanticFormatterCallback: (v) => context.l10n.pixelCount(
                  context.displayValue(math.max(2, (v * source.width).round())),
                ),
              ),
            ),
          ),
        ],
      ],
    ],
  );

  Widget _preview(ui.Image source) => RepaintBoundary(
    key: const ValueKey('photo-preview-frame'),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.studioColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.studioColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: LayoutBuilder(
          builder: (context, box) {
            final aspect = turns.isOdd
                ? source.height / source.width
                : source.width / source.height;
            final width = math.min(box.maxWidth, box.maxHeight * aspect);
            final height = width / aspect;
            return Center(
              child: SizedBox(
                width: width,
                height: height,
                child: RotatedBox(
                  quarterTurns: turns,
                  child: Transform.flip(
                    flipX: flipH,
                    flipY: flipV,
                    child: LayoutBuilder(
                      builder: (context, canvas) {
                        Offset point(Offset value) => Offset(
                          (value.dx / canvas.maxWidth).clamp(0, 1),
                          (value.dy / canvas.maxHeight).clamp(0, 1),
                        );
                        return GestureDetector(
                          key: const ValueKey('photo-drawing-surface'),
                          onPanStart: saving || panel != 'draw'
                              ? null
                              : (d) {
                                  if (tool == 'Text' &&
                                      label.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          context.l10n.photoEnterText,
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  setState(() {
                                    final p = point(d.localPosition);
                                    _activeMark = null;
                                    if (tool == 'Eraser') {
                                      final index = marks.lastIndexWhere(
                                        (m) => m.points.any(
                                          (v) => (v - p).distance < .06,
                                        ),
                                      );
                                      if (index >= 0) {
                                        remember();
                                        marks.removeAt(index);
                                      }
                                    } else {
                                      remember();
                                      _activeMark = PhotoMark(
                                        tool,
                                        color,
                                        [p],
                                        width: strokeWidth,
                                        text: label.text.trim(),
                                      );
                                      marks.add(_activeMark!);
                                    }
                                  });
                                },
                          onPanUpdate: saving || panel != 'draw'
                              ? null
                              : (d) {
                                  final mark = _activeMark;
                                  if (mark != null) {
                                    mark.points.add(point(d.localPosition));
                                    // Paint the active canvas without rebuilding toolbars on every sample.
                                    _canvasRevision.value++;
                                  }
                                },
                          onPanEnd: (_) => _activeMark = null,
                          onPanCancel: () => _activeMark = null,
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: CustomPaint(
                              painter: PhotoPainter(
                                source,
                                marks,
                                repaint: _canvasRevision,
                                crop: Rect.fromLTRB(
                                  horizontal.start,
                                  vertical.start,
                                  horizontal.end,
                                  vertical.end,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );

  Widget _editorBody(ui.Image source) => SafeArea(
    bottom: false,
    child: Padding(
      padding: EdgeInsets.all(
        MediaQuery.viewInsetsOf(context).bottom > 0
            ? AppSpacing.xxs
            : AppSpacing.md,
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final toolHeight = math.max(
            64.0,
            MediaQuery.textScalerOf(context).scale(14) * 1.5 + 48,
          );
          final controls = SingleChildScrollView(
            key: ValueKey('photo-controls-$panel-$tool'),
            primary: false,
            child: _contextualControls(source, compact: box.maxHeight < 140),
          );
          final landscape = box.maxWidth >= 600 && box.maxWidth > box.maxHeight;
          final shortWorkspace = box.maxHeight < 140;
          final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
          if (shortWorkspace && (!landscape || keyboardVisible)) {
            return controls;
          }
          if (landscape) {
            return Row(
              children: [
                Expanded(child: _preview(source)),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: (box.maxWidth * .38).clamp(260, 360),
                  child: shortWorkspace
                      ? SingleChildScrollView(
                          child: Column(
                            children: [
                              _toolbar(toolHeight),
                              const SizedBox(height: AppSpacing.xs),
                              _contextualControls(source),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            _toolbar(toolHeight),
                            const SizedBox(height: AppSpacing.xs),
                            Expanded(child: controls),
                          ],
                        ),
                ),
              ],
            );
          }
          final panelHeight = math.max(
            0.0,
            math.min(
              220.0,
              math.min(box.maxHeight * .34, box.maxHeight - toolHeight - 64),
            ),
          );
          return Column(
            children: [
              Expanded(child: _preview(source)),
              const SizedBox(height: AppSpacing.xs),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: panelHeight),
                child: controls,
              ),
              _toolbar(toolHeight),
            ],
          );
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final source = image;
    return PopScope(
      canPop:
          allowLeave || (!(dirty || turns != 0 || flipH || flipV) && !saving),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: saving ? null : leave),
          title: Text(context.l10n.photoEditor),
          actions: [
            IconButton(
              tooltip: context.l10n.undoPhotoEdit,
              onPressed: undoHistory.isEmpty || saving
                  ? null
                  : () => setState(undoMark),
              icon: const Icon(AppIcons.undo),
            ),
            IconButton(
              tooltip: context.l10n.redoPhotoEdit,
              onPressed: redoHistory.isEmpty || saving
                  ? null
                  : () => setState(redoMark),
              icon: const Icon(AppIcons.redo),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: context.l10n.editorExportQuality,
                  onPressed: saving ? null : _exportOptions,
                  icon: const Icon(AppIcons.settings),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: source == null || saving ? null : save,
                    icon: Icon(saving ? AppIcons.processing : AppIcons.save),
                    label: Text(
                      saving ? context.l10n.saving : context.l10n.saveCopy,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: source == null
            ? Center(
                child: error == null
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(context.message(error!)),
                          TextButton(
                            onPressed: () {
                              setState(() => error = null);
                              load();
                            },
                            child: Text(context.l10n.retry),
                          ),
                        ],
                      ),
              )
            : _editorBody(source),
      ),
    );
  }
}

class PhotoPainter extends CustomPainter {
  PhotoPainter(this.image, this.marks, {this.crop, super.repaint});
  final ui.Image image;
  final List<PhotoMark> marks;
  final Rect? crop;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint(),
    );
    for (final mark in marks) {
      if (mark.points.isEmpty) continue;
      Offset at(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
      final paint = Paint()
        ..color = mark.color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = math.max(2, size.width * mark.width);
      if (mark.tool == 'Text') {
        final text = TextPainter(
          text: TextSpan(
            text: mark.text,
            style: TextStyle(
              fontFamily: AppFonts.family,
              color: mark.color,
              fontSize: math.max(16, size.width * .045),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: math.max(1, size.width - at(mark.points.first).dx));
        text.paint(canvas, at(mark.points.first));
        text.dispose();
        continue;
      }
      if (mark.tool == 'Arrow') {
        final start = at(mark.points.first), end = at(mark.points.last);
        final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
        final head = math.max(8.0, paint.strokeWidth * 4);
        canvas.drawLine(start, end, paint);
        for (final offset in [-math.pi / 6, math.pi / 6]) {
          canvas.drawLine(
            end,
            end -
                Offset(
                  math.cos(angle + offset) * head,
                  math.sin(angle + offset) * head,
                ),
            paint,
          );
        }
        continue;
      }
      if (mark.tool == 'Pen') {
        final first = at(mark.points.first);
        final path = Path()..moveTo(first.dx, first.dy);
        for (final p in mark.points.skip(1)) {
          final v = at(p);
          path.lineTo(v.dx, v.dy);
        }
        if (mark.points.length == 1) {
          canvas.drawCircle(
            first,
            paint.strokeWidth / 2,
            Paint()..color = mark.color,
          );
        } else {
          canvas.drawPath(path, paint);
        }
      } else {
        final rect = Rect.fromPoints(
          at(mark.points.first),
          at(mark.points.last),
        );
        if (mark.tool == 'Circle') {
          canvas.drawOval(rect, paint);
        } else {
          canvas.drawRect(rect, paint);
        }
      }
    }
    if (crop != null) {
      final rect = Rect.fromLTRB(
        crop!.left * size.width,
        crop!.top * size.height,
        crop!.right * size.width,
        crop!.bottom * size.height,
      );
      final shade = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRect(rect);
      canvas.drawPath(shade, Paint()..color = Colors.black54);
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PhotoPainter oldDelegate) => true;
}
