import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/widgets/studio_widgets.dart';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'media_repository.dart';

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
                  title: const Text('Discard photo edits?'),
                  content: const Text(
                    'Your original photo is unchanged. Save a copy to keep these edits.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('Keep editing'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('Discard edits'),
                    ),
                  ],
                ),
              ) ==
              true;
      if (!mounted || !discard) return;
      setState(() => allowLeave = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) context.pop();
    } finally {
      leaving = false;
    }
  }

  String tool = 'Pen';
  Color color = Colors.red;
  double strokeWidth = .006;
  final label = TextEditingController();
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
    redoHistory.add(snapshot());
    restore(undoHistory.removeLast());
  }

  void redoMark() {
    undoHistory.add(snapshot());
    restore(redoHistory.removeLast());
  }

  @override
  void initState() {
    super.initState();
    load();
  }

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
    image?.dispose();
    label.dispose();
    super.dispose();
  }

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
          title: const Text('Photo editor'),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton.icon(
              onPressed: source == null || saving ? null : save,
              icon: Icon(saving ? AppIcons.processing : AppIcons.save),
              label: Text(saving ? 'Saving…' : 'Save copy'),
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
                          Text(error!),
                          TextButton(
                            onPressed: () {
                              setState(() => error = null);
                              load();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Edit an sRGB copy with orientation applied. Up to 2048px on the longest edge. JPEG uses a white background for transparency.',
                  ),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: exportFormat,
                    decoration: const InputDecoration(
                      labelText: 'Export image format',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'png',
                        child: Text('PNG · lossless'),
                      ),
                      DropdownMenuItem(
                        value: 'jpeg',
                        child: Text('JPEG · smaller file'),
                      ),
                    ],
                    onChanged: saving
                        ? null
                        : (v) => setState(() => exportFormat = v!),
                  ),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: exportEdge,
                    decoration: const InputDecoration(
                      labelText: 'Longest edge (no enlargement)',
                    ),
                    items: [480, 720, 1080, 2048]
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text('$v pixels'),
                          ),
                        )
                        .toList(),
                    onChanged: saving
                        ? null
                        : (v) => setState(() => exportEdge = v!),
                  ),
                  if (exportFormat == 'jpeg')
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: jpegQuality,
                      decoration: const InputDecoration(
                        labelText: 'JPEG quality',
                      ),
                      items: [70, 85, 95, 100]
                          .map(
                            (v) =>
                                DropdownMenuItem(value: v, child: Text('$v%')),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (v) => setState(() => jpegQuality = v!),
                    ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final value in [
                        'Pen',
                        'Rectangle',
                        'Circle',
                        'Arrow',
                        'Text',
                        'Eraser',
                      ])
                        ChoiceChip(
                          label: Text(value),
                          selected: tool == value,
                          onSelected: saving
                              ? null
                              : (_) => setState(() => tool = value),
                        ),
                      IconButton(
                        tooltip: 'Undo photo edit',
                        onPressed: undoHistory.isEmpty || saving
                            ? null
                            : () => setState(undoMark),
                        icon: const Icon(AppIcons.undo),
                      ),
                      IconButton(
                        tooltip: 'Redo photo edit',
                        onPressed: redoHistory.isEmpty || saving
                            ? null
                            : () => setState(redoMark),
                        icon: const Icon(AppIcons.redo),
                      ),
                      for (final ink in const [
                        (Colors.red, 'Red'),
                        (Colors.yellow, 'Yellow'),
                        (Colors.cyan, 'Cyan'),
                        (Colors.white, 'White'),
                        (Colors.black, 'Black'),
                      ])
                        Semantics(
                          selected: color == ink.$1,
                          child: IconButton(
                            tooltip: '${ink.$2} ink',
                            style: IconButton.styleFrom(
                              backgroundColor: ink.$1.computeLuminance() < .2
                                  ? const Color(0xFFDEE3EC)
                                  : const Color(0xFF242D3E),
                            ),
                            onPressed: saving
                                ? null
                                : () => setState(() => color = ink.$1),
                            icon: Icon(
                              color == ink.$1
                                  ? AppIcons.selected
                                  : AppIcons.unselected,
                              color: ink.$1,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: saving
                            ? null
                            : () => setState(() {
                                remember();
                                turns = (turns + 1) % 4;
                              }),
                        child: const Text('Rotate 90°'),
                      ),
                      TextButton(
                        onPressed: saving
                            ? null
                            : () => setState(() {
                                remember();
                                flipH = !flipH;
                              }),
                        child: Text('Flip horizontal${flipH ? ' · On' : ''}'),
                      ),
                      TextButton(
                        onPressed: saving
                            ? null
                            : () => setState(() {
                                remember();
                                flipV = !flipV;
                              }),
                        child: Text('Flip vertical${flipV ? ' · On' : ''}'),
                      ),
                    ],
                  ),
                  if (tool == 'Text')
                    TextField(
                      controller: label,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Text to place on photo',
                      ),
                    ),
                  Semantics(
                    label: 'Stroke width',
                    child: Slider(
                      value: strokeWidth,
                      min: .002,
                      max: .02,
                      onChanged: saving
                          ? null
                          : (value) => setState(() => strokeWidth = value),
                      semanticFormatterCallback: (value) =>
                          '${(value * 2048).round()} pixels at 2048 pixels wide',
                    ),
                  ),
                  RotatedBox(
                    quarterTurns: turns,
                    child: Transform.flip(
                      flipX: flipH,
                      flipY: flipV,
                      child: AspectRatio(
                        aspectRatio: source.width / source.height,
                        child: LayoutBuilder(
                          builder: (context, box) {
                            Offset point(Offset value) => Offset(
                              (value.dx / box.maxWidth).clamp(0, 1),
                              (value.dy / box.maxHeight).clamp(0, 1),
                            );
                            return GestureDetector(
                              onPanStart: saving
                                  ? null
                                  : (d) => setState(() {
                                      final p = point(d.localPosition);
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
                                        marks.add(
                                          PhotoMark(
                                            tool,
                                            color,
                                            [p],
                                            width: strokeWidth,
                                            text: label.text.trim(),
                                          ),
                                        );
                                      }
                                    }),
                              onPanUpdate: saving
                                  ? null
                                  : (d) {
                                      if (tool != 'Eraser' &&
                                          marks.isNotEmpty) {
                                        setState(
                                          () => marks.last.points.add(
                                            point(d.localPosition),
                                          ),
                                        );
                                      }
                                    },
                              child: CustomPaint(
                                painter: PhotoPainter(
                                  source,
                                  marks,
                                  crop: Rect.fromLTRB(
                                    horizontal.start,
                                    vertical.start,
                                    horizontal.end,
                                    vertical.end,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const Text('Crop left / right'),
                  Semantics(
                    label: 'Crop left and right',
                    child: RangeSlider(
                      values: horizontal,
                      onChangeStart: saving ? null : (_) => remember(),
                      onChanged: saving
                          ? null
                          : (v) {
                              if (v.end - v.start >= .02) {
                                setState(() => horizontal = v);
                              }
                            },
                      semanticFormatterCallback: (v) =>
                          '${(v * 100).round()} percent',
                    ),
                  ),
                  const Text('Crop top / bottom'),
                  Semantics(
                    label: 'Crop top and bottom',
                    child: RangeSlider(
                      values: vertical,
                      onChangeStart: saving ? null : (_) => remember(),
                      onChanged: saving
                          ? null
                          : (v) {
                              if (v.end - v.start >= .02) {
                                setState(() => vertical = v);
                              }
                            },
                      semanticFormatterCallback: (v) =>
                          '${(v * 100).round()} percent',
                    ),
                  ),
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => setState(() {
                            remember();
                            horizontal = const RangeValues(0, 1);
                            vertical = const RangeValues(0, 1);
                          }),
                    child: const Text('Reset crop'),
                  ),
                ],
              ),
      ),
    );
  }
}

class PhotoPainter extends CustomPainter {
  PhotoPainter(this.image, this.marks, {this.crop});
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
