import '../../l10n/editor_numbers.dart';

import 'package:xrecorder/l10n/localization.dart';
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
    title: Text(context.l10n.textStickersDrawing),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.xs,
        children: [
          for (var i = 0; i < layers.length; i++)
            ListTile(
              tileColor: context.studioColors.surface,
              contentPadding: const EdgeInsetsDirectional.only(
                start: AppSpacing.sm,
                end: AppSpacing.xxs,
              ),
              leading: StudioIconTile(
                icon: _layerIcon(layers[i]['kind']),
                size: 40,
                iconSize: AppIconSize.medium,
              ),
              title: Text(
                context.l10n.sequenceLabel(
                  context.displayValue(i + 1),
                  context.effectValue(layers[i]['kind']!),
                ),
              ),
              subtitle: Text(
                context.l10n.timeRangeSeconds(
                  context.displayValue((layers[i]['startMs'] as num) / 1000),
                  context.displayValue((layers[i]['endMs'] as num) / 1000),
                ),
              ),
              onTap: () => edit(i, layers[i]['kind'] as String),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: context.l10n.moveLayerForward,
                    icon: const Icon(AppIcons.chevronUp),
                    onPressed: i == layers.length - 1
                        ? null
                        : () => setState(() {
                            final layer = layers.removeAt(i);
                            layers.insert(i + 1, layer);
                          }),
                  ),
                  IconButton(
                    tooltip: context.l10n.deleteLayerNumber(
                      context.displayValue(i + 1),
                    ),
                    icon: const Icon(AppIcons.trash),
                    onPressed: () => setState(() => layers.removeAt(i)),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Text(
              context.l10n.laterLayersAppearInFrontPositionAnd,
              style: AppTypography.bodySmall.copyWith(
                color: context.studioColors.muted,
              ),
            ),
          ),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final kind in ['text', 'sticker', 'drawing'])
                OutlinedButton.icon(
                  onPressed: layers.length >= 40
                      ? null
                      : () => edit(null, kind),
                  icon: Icon(_layerIcon(kind), size: AppIconSize.medium),
                  label: Text(
                    context.l10n.addLayerKind(context.effectValue(kind)),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, layers),
        child: Text(context.l10n.useLayers),
      ),
    ],
  );
}

IconData _layerIcon(Object? kind) => switch (kind) {
  'text' => AppIcons.text,
  'sticker' => AppIcons.sticker,
  _ => AppIcons.pen,
};

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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.controlValue(
            context.displayValue(label),
            context.displayValue(context.decimal(v, digits: 2)),
          ),
          style: AppTypography.bodySmall.copyWith(
            color: context.studioColors.text,
          ),
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Slider(
            value: v,
            min: min,
            max: max,
            semanticFormatterCallback: context.spokenValue(
              (strings, number) => strings.accessibilityValue41(label, number),
              digits: 2,
            ),
            onChanged: (n) => setState(() => value[key] = n),
          ),
        ),
      ],
    );
  }

  void save() {
    try {
      final a = parseEditorDecimal(start.text),
          b = parseEditorDecimal(end.text);
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
    title: Text(
      context.l10n.editLayerKind(context.effectValue(value['kind']!)),
    ),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.md,
        children: [
          if (value['kind'] == 'text')
            TextField(
              controller: text,
              maxLength: 2000,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: context.l10n.layerText,
                suffixIcon: StudioClearTextButton(controller: text),
              ),
            ),
          if (value['kind'] == 'sticker')
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: value['sticker'] as String,
              decoration: InputDecoration(labelText: context.l10n.sticker),
              items: ['star', 'heart', 'circle']
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(context.effectValue(v)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => value['sticker'] = v!),
            ),
          if (value['kind'] == 'drawing') ...[
            Semantics(
              label: context.l10n.drawingPadDragToDrawUsePosition,
              child: AspectRatio(
                aspectRatio: 1,
                child: Builder(
                  builder: (context) => GestureDetector(
                    onPanStart: (d) => setState(() {
                      if (points.length < 2048) {
                        final size = context.size!;
                        points.add(null);
                        points.add([
                          (d.localPosition.dx / size.width).clamp(0.0, 1.0),
                          (d.localPosition.dy / size.height).clamp(0.0, 1.0),
                        ]);
                      }
                    }),
                    onPanUpdate: (d) => setState(() {
                      if (points.length < 2048) {
                        final size = context.size!;
                        points.add([
                          (d.localPosition.dx / size.width).clamp(0.0, 1.0),
                          (d.localPosition.dy / size.height).clamp(0.0, 1.0),
                        ]);
                      }
                    }),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      // A visible canvas so people can see where to draw.
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.studioColors.background,
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                          border: Border.all(
                            color: context.studioColors.border,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
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
                ),
              ),
            ),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(points.clear),
                  icon: const Icon(AppIcons.eraser, size: AppIconSize.medium),
                  label: Text(context.l10n.clearDrawing),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(
                    () => points.addAll([
                      null,
                      [.2, .5],
                      [.8, .5],
                    ]),
                  ),
                  icon: const Icon(AppIcons.pen, size: AppIconSize.medium),
                  label: Text(context.l10n.addStraightLine),
                ),
              ],
            ),
          ],
          Wrap(
            spacing: AppSpacing.xs,
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
                    tooltip: {
                      0xFFFFFFFF: context.l10n.white,
                      0xFFFFD54F: context.l10n.yellow,
                      0xFFEF5350: context.l10n.red,
                      0xFF42A5F5: context.l10n.blue,
                      0xFF000000: context.l10n.black,
                    }[color],
                    icon: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: value['color'] == color
                              ? context.studioColors.primary
                              : context.studioColors.outline,
                          width: value['color'] == color ? 3 : 1,
                        ),
                      ),
                      child: const SizedBox.square(dimension: 28),
                    ),
                    onPressed: () => setState(() => value['color'] = color),
                  ),
                ),
            ],
          ),
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
          slider('x', context.l10n.horizontalPosition, 0, 1),
          slider('y', context.l10n.verticalPosition, 0, 1),
          slider('scale', context.l10n.size, .1, 4),
          slider('rotation', context.l10n.rotationInDegrees, -360, 360),
          if (error != null)
            Text(
              context.message(error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(onPressed: save, child: Text(context.l10n.useLayer)),
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
