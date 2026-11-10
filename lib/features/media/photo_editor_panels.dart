import 'package:flutter/material.dart';

import '../../core/widgets/studio_widgets.dart';
import '../../l10n/localization.dart';

const photoInkPresets = [
  (Colors.red, 'Red'),
  (Colors.yellow, 'Yellow'),
  (Colors.cyan, 'Cyan'),
  (Colors.white, 'White'),
  (Colors.black, 'Black'),
];

String photoInkName(BuildContext context, Color color) => context.l10n.inkColor(
  context.message(photoInkPresets.firstWhere((entry) => entry.$1 == color).$2),
);

Future<String?> choosePhotoTool(
  BuildContext context, {
  required String title,
  required IconData icon,
  required List<(String, String)> tools,
  required String selected,
  bool isScrollControlled = false,
  Color? selectedTileColor,
}) => showStudioBottomSheet<String>(
  context: context,
  isScrollControlled: isScrollControlled,
  builder: (context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StudioSheetHeader(title: title, icon: icon),
          for (final (id, label) in tools)
            ListTile(
              title: Text(label),
              selected: id == selected,
              selectedTileColor: selectedTileColor,
              trailing: id == selected ? const Icon(AppIcons.selected) : null,
              onTap: () => Navigator.pop(context, id),
            ),
        ],
      ),
    ),
  ),
);

Future<Color?> choosePhotoInk(
  BuildContext context,
  Color current,
) => showStudioBottomSheet<Color>(
  context: context,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudioSheetHeader(
            title: context.l10n.editorColor,
            icon: AppIcons.palette,
          ),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final entry in photoInkPresets)
                Semantics(
                  selected: current == entry.$1,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: current == entry.$1
                          ? context.studioColors.primary.withValues(alpha: .10)
                          : null,
                    ),
                    onPressed: () => Navigator.pop(context, entry.$1),
                    icon: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: entry.$1,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.studioColors.outline),
                      ),
                      child: current == entry.$1
                          ? Icon(
                              AppIcons.selected,
                              size: 18,
                              color: entry.$1.computeLuminance() > .45
                                  ? Colors.black
                                  : Colors.white,
                            )
                          : null,
                    ),
                    label: Text(photoInkName(context, entry.$1)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.close),
            ),
          ),
        ],
      ),
    ),
  ),
);

typedef PhotoExportOptions = ({String format, int maxEdge, int quality});

Future<PhotoExportOptions?> editPhotoExportOptions(
  BuildContext context,
  PhotoExportOptions current,
) => showStudioBottomSheet<PhotoExportOptions>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _PhotoExportOptions(current: current),
);

class _PhotoExportOptions extends StatefulWidget {
  const _PhotoExportOptions({required this.current});
  final PhotoExportOptions current;
  @override
  State<_PhotoExportOptions> createState() => _PhotoExportOptionsState();
}

class _PhotoExportOptionsState extends State<_PhotoExportOptions> {
  late String format = widget.current.format;
  late int edge = widget.current.maxEdge;
  late int quality = widget.current.quality;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudioSheetHeader(
            title: context.l10n.editorExportQuality,
            description: context.l10n.editAnSrgbCopyWithOrientationApplied,
          ),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: format,
            decoration: InputDecoration(
              labelText: context.l10n.exportImageFormat,
            ),
            items: [
              DropdownMenuItem(
                value: 'png',
                child: Text(context.l10n.pngLossless),
              ),
              DropdownMenuItem(
                value: 'jpeg',
                child: Text(context.l10n.jpegSmallerFile),
              ),
            ],
            onChanged: (value) => setState(() => format = value!),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: edge,
            decoration: InputDecoration(
              labelText: context.l10n.longestEdgeNoEnlargement,
            ),
            items: [
              for (final value in [480, 720, 1080, 2048])
                DropdownMenuItem(
                  value: value,
                  child: Text(
                    context.l10n.pixelCount(context.displayValue(value)),
                  ),
                ),
            ],
            onChanged: (value) => setState(() => edge = value!),
          ),
          if (format == 'jpeg') ...[
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: quality,
              decoration: InputDecoration(labelText: context.l10n.jpegQuality),
              items: [
                for (final value in [70, 85, 95, 100])
                  DropdownMenuItem(
                    value: value,
                    child: Text(
                      context.l10n.percentValue(context.displayValue(value)),
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => quality = value!),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              spacing: AppSpacing.sm,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, (
                    format: format,
                    maxEdge: edge,
                    quality: quality,
                  )),
                  child: Text(context.l10n.editorApply),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
