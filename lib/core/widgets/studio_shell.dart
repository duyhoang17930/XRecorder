import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/recording/recording_service.dart';
import 'studio_create_sheet.dart';
import 'studio_widgets.dart';
import 'studio_tab_scroll.dart';

class StudioShell extends StatefulWidget {
  const StudioShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;
  @override
  State<StudioShell> createState() => _StudioShellState();
}

class _StudioShellState extends State<StudioShell> {
  final controllers = List.generate(4, (_) => ScrollController());
  void select(int index) {
    if (index != widget.navigationShell.currentIndex) {
      widget.navigationShell.goBranch(index);
      return;
    }
    final controller = controllers[index];
    if (!controller.hasClients ||
        controller.positions.length != 1 ||
        !controller.position.hasContentDimensions) {
      return;
    }
    final top = controller.position.minScrollExtent;
    if (context.reduceMotion) {
      controller.jumpTo(top);
    } else {
      controller.animateTo(
        top,
        duration: AppMotion.slow,
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppBreakpoints.content),
          child: Column(
            children: [
              Expanded(
                child: StudioTabScrollScope(
                  controllers: controllers,
                  child: widget.navigationShell,
                ),
              ),
              const CaptureStatusBar(),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: StudioBottomNavigation(
      selected: widget.navigationShell.currentIndex,
      onDestination: select,
      onCreate: () => openStudioCreate(context),
    ),
  );
}

class StudioBottomNavigation extends StatelessWidget {
  const StudioBottomNavigation({
    super.key,
    required this.selected,
    required this.onDestination,
    required this.onCreate,
  });
  final int selected;
  final ValueChanged<int> onDestination;
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) {
    final c = context.studioColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppBreakpoints.tablet),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxs,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _destination(context, 'Video', AppIcons.videos, 0),
                  _destination(context, 'Photo', AppIcons.photos, 1),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(
                          dimension: AppSize.create,
                          child: Tooltip(
                            message: 'Create',
                            child: FilledButton(
                              onPressed: onCreate,
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card,
                                  ),
                                ),
                              ),
                              child: const Icon(
                                AppIcons.create,
                                semanticLabel: 'Create',
                                size: AppIconSize.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        MediaQuery.withClampedTextScaling(
                          maxScaleFactor: AppSize.navigationLabelScale,
                          child: Text(
                            'Create',
                            textAlign: TextAlign.center,
                            style: AppTypography.navigation.copyWith(
                              color: c.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _destination(context, 'Edit', AppIcons.edit, 2),
                  _destination(context, 'Settings', AppIcons.settings, 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _destination(
    BuildContext context,
    String label,
    IconData icon,
    int index,
  ) {
    final c = context.studioColors;
    final active = selected == index;
    return Expanded(
      child: Semantics(
        selected: active,
        child: Tooltip(
          message: label,
          child: TextButton(
            onPressed: () => onDestination(index),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xs,
                horizontal: AppSpacing.xxs,
              ),
              foregroundColor: active ? c.primary : c.muted,
              minimumSize: const Size(AppSize.touchTarget, AppSize.navigation),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: active
                        ? c.primary.withValues(alpha: .12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xxs,
                    ),
                    child: Icon(icon, size: AppIconSize.large),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: AppSize.navigationLabelScale,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: AppTypography.navigation,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
