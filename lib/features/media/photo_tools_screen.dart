import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/widgets/studio_widgets.dart';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'media_repository.dart';

class PhotoMark {
  PhotoMark(this.tool, this.color, this.points);
  final String tool;
  final Color color;
  final List<Offset> points;
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
  String tool = 'Pen';
  Color color = Colors.red;
  RangeValues horizontal = const RangeValues(0, 1),
      vertical = const RangeValues(0, 1);
  final marks = <PhotoMark>[];
  final undoHistory = <List<PhotoMark>>[], redoHistory = <List<PhotoMark>>[];
  List<PhotoMark> snapshot() =>
      marks.map((m) => PhotoMark(m.tool, m.color, List.of(m.points))).toList();
  void remember() {
    undoHistory.add(snapshot());
    redoHistory.clear();
  }

  void undoMark() {
    redoHistory.add(snapshot());
    marks
      ..clear()
      ..addAll(undoHistory.removeLast());
  }

  void redoMark() {
    undoHistory.add(snapshot());
    marks
      ..clear()
      ..addAll(redoHistory.removeLast());
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final bytes = await channel.invokeMethod<Uint8List>('imageBytes', {
        'uri': widget.uri,
      });
      if (bytes == null) throw StateError('Image unavailable');
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 2048,
        allowUpscaling: false,
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
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..translate(-crop.left, -crop.top);
      PhotoPainter(source, marks).paint(canvas, Size(width, height));
      final picture = recorder.endRecording();
      final output = await picture.toImage(
        crop.width.round().clamp(1, source.width),
        crop.height.round().clamp(1, source.height),
      );
      picture.dispose();
      final bytes = await output.toByteData(format: ui.ImageByteFormat.png);
      output.dispose();
      final uri = await channel.invokeMethod<String>('saveImage', {
        'bytes': bytes!.buffer.asUint8List(),
      });
      if (uri == null) throw StateError('No image was saved');
      if (mounted) {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = image;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop & annotate a copy'),
        actions: [
          TextButton(
            onPressed: source == null || saving ? null : save,
            child: Text(saving ? 'Saving…' : 'Save copy'),
          ),
        ],
      ),
      body: source == null
          ? Center(
              child: error == null
                  ? const CircularProgressIndicator()
                  : Text(error!),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Full-screen capture + crop. Marks are burned into the saved copy. Original stays intact. Working image width is limited to 2048 pixels.',
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
                      tooltip: 'Undo mark',
                      onPressed: undoHistory.isEmpty || saving
                          ? null
                          : () => setState(undoMark),
                      icon: const Icon(AppIcons.undo),
                    ),
                    IconButton(
                      tooltip: 'Redo mark',
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
                AspectRatio(
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
                                  marks.add(PhotoMark(tool, color, [p]));
                                }
                              }),
                        onPanUpdate: saving
                            ? null
                            : (d) {
                                if (tool != 'Eraser' && marks.isNotEmpty) {
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
                const Text('Crop left / right'),
                RangeSlider(
                  values: horizontal,
                  onChanged: saving
                      ? null
                      : (v) {
                          if (v.end - v.start >= .02) {
                            setState(() => horizontal = v);
                          }
                        },
                ),
                const Text('Crop top / bottom'),
                RangeSlider(
                  values: vertical,
                  onChanged: saving
                      ? null
                      : (v) {
                          if (v.end - v.start >= .02) {
                            setState(() => vertical = v);
                          }
                        },
                ),
                TextButton(
                  onPressed: saving
                      ? null
                      : () => setState(() {
                          horizontal = const RangeValues(0, 1);
                          vertical = const RangeValues(0, 1);
                        }),
                  child: const Text('Reset crop'),
                ),
              ],
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
        ..strokeWidth = math.max(2, size.width * .006);
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
