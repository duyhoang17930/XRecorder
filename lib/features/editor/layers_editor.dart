import 'package:flutter/material.dart';

import '../../core/widgets/studio_widgets.dart';
import 'timeline_effects.dart';

Future<List<Map<String, Object>>?> editLayers(
  BuildContext context,
  List<Map<String, Object>> layers,
  int durationMs,
) => showStudioDialog(
  context: context,
  builder: (_) => _LayersEditor(layers: layers, durationMs: durationMs),
);

class _LayersEditor extends StatefulWidget {
  const _LayersEditor({required this.layers, required this.durationMs});
  final List<Map<String, Object>> layers;
  final int durationMs;
  @override
  State<_LayersEditor> createState() => _LayersEditorState();
}

class _LayersEditorState extends State<_LayersEditor> {
  late final layers = widget.layers
      .map((v) => Map<String, Object>.from(v))
      .toList();
  Future<void> edit(int? index, String kind) async {
    final value = await showStudioDialog<Map<String, Object>>(
      context: context,
      builder: (_) => _LayerDialog(
        value: index == null
            ? {'kind': kind, 'startMs': 0, 'endMs': widget.durationMs}
            : layers[index],
        durationMs: widget.durationMs,
      ),
    );
    if (mounted && value != null) {
      setState(() {
        if (index == null) {
          layers.add(value);
        } else {
          layers[index] = value;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => StudioDialog(
    title: const Text('Text, stickers & drawing'),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < layers.length; i++)
            ListTile(
              title: Text('${i + 1}. ${layers[i]['kind']}'),
              subtitle: Text(
                '${(layers[i]['startMs'] as num) / 1000}–${(layers[i]['endMs'] as num) / 1000}s',
              ),
              onTap: () => edit(i, layers[i]['kind'] as String),
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: 'Move layer forward',
                    icon: const Icon(AppIcons.chevronUp),
                    onPressed: i == layers.length - 1
                        ? null
                        : () => setState(() {
                            final layer = layers.removeAt(i);
                            layers.insert(i + 1, layer);
                          }),
                  ),
                  IconButton(
                    tooltip: 'Delete layer ${i + 1}',
                    icon: const Icon(AppIcons.trash),
                    onPressed: () => setState(() => layers.removeAt(i)),
                  ),
                ],
              ),
            ),
          const Text(
            'Later layers appear in front. Position and size are relative to the exported frame.',
          ),
          Wrap(
            children: [
              for (final kind in ['text', 'sticker', 'drawing'])
                TextButton(
                  onPressed: layers.length >= 40
                      ? null
                      : () => edit(null, kind),
                  child: Text('Add $kind'),
                ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, layers),
        child: const Text('Use layers'),
      ),
    ],
  );
}

class _LayerDialog extends StatefulWidget {
  const _LayerDialog({required this.value, required this.durationMs});
  final Map<String, Object> value;
  final int durationMs;
  @override
  State<_LayerDialog> createState() => _LayerDialogState();
}

class _LayerDialogState extends State<_LayerDialog> {
  late final value = <String, Object>{
    'x': .5,
    'y': .5,
    'scale': 1.0,
    'rotation': 0.0,
    'color': 0xFFFFFFFF,
    'sticker': 'star',
    ...widget.value,
  };
  late final text = TextEditingController(text: value['text'] as String? ?? '');
  late final start = TextEditingController(
    text: '${(value['startMs'] as num) / 1000}',
  );
  late final end = TextEditingController(
    text: '${(value['endMs'] as num) / 1000}',
  );
  late final points = <Object?>[...?value['points'] as List?];
  String? error;
  @override
  void dispose() {
    text.dispose();
    start.dispose();
    end.dispose();
    super.dispose();
  }

  Widget slider(String key, String label, double min, double max) {
    final v = (value[key] as num).toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ${v.toStringAsFixed(2)}'),
        Slider(
          value: v,
          min: min,
          max: max,
          semanticFormatterCallback: (n) => '$label ${n.toStringAsFixed(2)}',
          onChanged: (n) => setState(() => value[key] = n),
        ),
      ],
    );
  }

  void save() {
    try {
      final a = double.tryParse(start.text), b = double.tryParse(end.text);
      if (a == null || b == null || !a.isFinite || !b.isFinite) {
        throw const FormatException('Enter valid times in seconds.');
      }
      final next = <String, Object>{
        ...value,
        'startMs': (a * 1000).round(),
        'endMs': (b * 1000).round(),
        'text': text.text,
        'points': points,
      };
      validateLayer(next, widget.durationMs);
      Navigator.pop(context, next);
    } on FormatException catch (e) {
      setState(() => error = e.message.toString());
    }
  }

  @override
  Widget build(BuildContext context) => StudioDialog(
    title: Text('Edit ${value['kind']} layer'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value['kind'] == 'text')
            TextField(
              controller: text,
              maxLength: 2000,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Layer text'),
            ),
          if (value['kind'] == 'sticker')
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: value['sticker'] as String,
              decoration: const InputDecoration(labelText: 'Sticker'),
              items: [
                'star',
                'heart',
                'circle',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => value['sticker'] = v!),
            ),
          if (value['kind'] == 'drawing') ...[
            Semantics(
              label: 'Drawing pad. Drag to draw; use position and size controls below to place it.',
              child: AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (context, size) => GestureDetector(
                    onPanStart: (d) => setState(() {
                      if (points.length < 2048) {
                        points.add(null);
                        points.add([
                          (d.localPosition.dx / size.maxWidth).clamp(0.0, 1.0),
                          (d.localPosition.dy / size.maxHeight).clamp(0.0, 1.0),
                        ]);
                      }
                    }),
                    onPanUpdate: (d) => setState(() {
                      if (points.length < 2048) {
                        points.add([
                          (d.localPosition.dx / size.maxWidth).clamp(0.0, 1.0),
                          (d.localPosition.dy / size.maxHeight).clamp(0.0, 1.0),
                        ]);
                      }
                    }),
                    child: CustomPaint(
                      painter: _DrawingPainter(
                        List.of(points),
                        Color(value['color'] as int),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(points.clear),
              child: const Text('Clear drawing'),
            ),
            TextButton(
              onPressed: () => setState(
                () => points.addAll([
                  null,
                  [.2, .5],
                  [.8, .5],
                ]),
              ),
              child: const Text('Add straight line'),
            ),
          ],
          Wrap(
            children: [
              for (final color in [
                0xFFFFFFFF,
                0xFFFFD54F,
                0xFFEF5350,
                0xFF42A5F5,
                0xFF000000,
              ])
                Semantics(
                  selected: value['color'] == color,
                  child: IconButton(
                    tooltip: const {
                      0xFFFFFFFF: 'White',
                      0xFFFFD54F: 'Yellow',
                      0xFFEF5350: 'Red',
                      0xFF42A5F5: 'Blue',
                      0xFF000000: 'Black',
                    }[color],
                    icon: Icon(AppIcons.selected, color: Color(color)),
                    onPressed: () => setState(() => value['color'] = color),
                  ),
                ),
            ],
          ),
          TextField(
            controller: start,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Start (seconds)'),
          ),
          TextField(
            controller: end,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'End (seconds)'),
          ),
          slider('x', 'Horizontal position', 0, 1),
          slider('y', 'Vertical position', 0, 1),
          slider('scale', 'Size', .1, 4),
          slider('rotation', 'Rotation in degrees', -360, 360),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(onPressed: save, child: const Text('Use layer')),
    ],
  );
}

class _DrawingPainter extends CustomPainter {
  const _DrawingPainter(this.points, this.color);
  final List<Object?> points;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF303030), BlendMode.src);
    final path = Path();
    var first = true;
    for (final point in points) {
      if (point == null) {
        first = true;
      } else {
        final xy = point as List;
        final x = (xy[0] as num) * size.width, y = (xy[1] as num) * size.height;
        if (first) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        first = false;
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .012
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_DrawingPainter old) =>
      old.points != points || old.color != color;
}
