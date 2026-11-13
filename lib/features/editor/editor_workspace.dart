import 'package:flutter/material.dart';

import '../../core/widgets/studio_widgets.dart';

/// Presentation slots keep the native preview/controller independent of panels.
class VideoEditorWorkspace extends StatelessWidget {
  const VideoEditorWorkspace({
    super.key,
    required this.preview,
    required this.status,
    required this.transport,
    required this.timeline,
    required this.tools,
    required this.history,
    this.contextual,
  });
  final Widget preview, status, transport, timeline, tools, history;
  final Widget? contextual;

  Widget _scroll(Widget child) => ScrollConfiguration(
    // Context panels contain text/controls; stretching their glyphs obscures
    // feedback. Keep normal scrolling and gesture handling in this viewport.
    behavior: const MaterialScrollBehavior().copyWith(overscroll: false),
    child: SingleChildScrollView(primary: false, child: child),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: LayoutBuilder(
        builder: (context, box) {
          final landscape = box.maxWidth >= 600 && box.maxWidth > box.maxHeight;
          if (landscape) {
            return Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: preview),
                      transport,
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: (box.maxWidth * .45).clamp(280, 460),
                  child: Column(
                    children: [
                      Expanded(
                        child: _scroll(
                          Column(children: [status, timeline, ?contextual]),
                        ),
                      ),
                      history,
                      tools,
                    ],
                  ),
                ),
              ],
            );
          }
          if (box.maxHeight < 350) {
            return _scroll(
              Column(
                children: [
                  SizedBox(height: 150, child: preview),
                  transport,
                  status,
                  timeline,
                  ?contextual,
                  history,
                  tools,
                ],
              ),
            );
          }
          return Column(
            children: [
              Expanded(flex: contextual == null ? 3 : 2, child: preview),
              transport,
              Expanded(
                flex: contextual == null ? 2 : 3,
                child: _scroll(
                  Column(
                    children: [
                      ?contextual,
                      status,
                      KeyedSubtree(
                        key: const ValueKey('workspace-timeline'),
                        child: timeline,
                      ),
                    ],
                  ),
                ),
              ),
              history,
              tools,
            ],
          );
        },
      ),
    ),
  );
}

class EditorTool extends StatelessWidget {
  const EditorTool({
    super.key,
    required this.label,
    required this.icon,
    this.selected = false,
    this.onPressed,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    enabled: onPressed != null,
    child: Tooltip(
      message: label,
      child: Material(
        color: selected
            ? context.studioColors.primary.withValues(alpha: .12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: onPressed == null
                      ? context.studioColors.muted
                      : selected
                      ? context.studioColors.primary
                      : context.studioColors.text,
                ),
                const SizedBox(height: 4),
                Text(label, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class EditorToolStrip extends StatelessWidget {
  const EditorToolStrip({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(children: children),
  );
}
