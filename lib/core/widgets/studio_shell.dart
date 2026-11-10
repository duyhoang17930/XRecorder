import 'dart:ui' show ImageFilter;

import 'package:xrecorder/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/recording/recording_service.dart';
import '../constants/app_icons.dart';
import '../domain/models.dart' show RecordingState;
import '../ui/theme/colors.dart';
import '../ui/theme/motion.dart';
import '../ui/theme/radius.dart';
import '../ui/theme/spacing.dart';
import '../ui/theme/typography.dart';
import 'studio_create_sheet.dart';
import 'studio_tab_scroll.dart';

class StudioShell extends StatefulWidget {
  const StudioShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;
  @override
  State<StudioShell> createState() => _StudioShellState();
}

class _StudioShellState extends State<StudioShell> {
  bool _openingCreate = false;
  Future<void> create() async {
    if (_openingCreate) return;
    _openingCreate = true;
    try {
      await openStudioCreate(context);
    } finally {
      _openingCreate = false;
    }
  }

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
  Widget build(BuildContext context) {
    final capture = CaptureScope.of(context);
    final session = capture.session;
    final reserveCaptureFooter =
        capture.feedback != null ||
        (session != null &&
            session.state != RecordingState.idle &&
            session.state != RecordingState.completed &&
            capture.dismissedId != session.id);
    return Scaffold(
      // Reserve the original footer area whenever capture UI can be visible.
      // CaptureStatusBar remains responsible for its content and actions.
      extendBody: !reserveCaptureFooter,
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
        onCreate: create,
      ),
    );
  }
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
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    final c = context.studioColors;
    final reduceMotion = context.reduceMotion;
    final tabDuration = reduceMotion ? Duration.zero : AppMotion.standard;
    final indicatorDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 260);
    final radius = BorderRadius.circular(AppRadius.pill);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppBreakpoints.tablet),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xxs,
            ),
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: dark ? .18 : .08,
                          ),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: radius,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: c.surface.withValues(
                              alpha: dark ? .74 : .76,
                            ),
                            borderRadius: radius,
                            border: Border.all(
                              color: c.border.withValues(alpha: .58),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xxs),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final segmentWidth = constraints.maxWidth / 4;
                                final indicatorInset = AppSpacing.xxs;
                                return Stack(
                                  clipBehavior: Clip.hardEdge,
                                  children: [
                                    AnimatedPositionedDirectional(
                                      duration: indicatorDuration,
                                      curve: AppMotion.emphasized,
                                      start:
                                          (selected.clamp(0, 3) * segmentWidth +
                                                  indicatorInset)
                                              .toDouble(),
                                      top: indicatorInset,
                                      bottom: indicatorInset,
                                      width: segmentWidth - indicatorInset * 2,
                                      child: DecoratedBox(
                                        key: const ValueKey(
                                          'navigation-selected-indicator',
                                        ),
                                        decoration: BoxDecoration(
                                          color: c.primary.withValues(
                                            alpha: dark ? .18 : .10,
                                          ),
                                          borderRadius: radius,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        _destination(
                                          context,
                                          context.l10n.video,
                                          AppIcons.videos,
                                          0,
                                          tabDuration,
                                        ),
                                        _destination(
                                          context,
                                          context.l10n.photo,
                                          AppIcons.photos,
                                          1,
                                          tabDuration,
                                        ),
                                        _destination(
                                          context,
                                          context.l10n.edit,
                                          AppIcons.edit,
                                          2,
                                          tabDuration,
                                        ),
                                        _destination(
                                          context,
                                          context.l10n.settings,
                                          AppIcons.settings,
                                          3,
                                          tabDuration,
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                SizedBox.square(
                  dimension: AppSize.create,
                  child: Tooltip(
                    message: context.l10n.create,
                    child: FilledButton(
                      onPressed: onCreate,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size.square(AppSize.create),
                        tapTargetSize: MaterialTapTargetSize.padded,
                        shape: const CircleBorder(),
                      ),
                      child: Icon(
                        AppIcons.create,
                        semanticLabel: context.l10n.create,
                        size: AppIconSize.primary,
                      ),
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

  Widget _destination(
    BuildContext context,
    String label,
    IconData icon,
    int index,
    Duration duration,
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
              padding: EdgeInsets.zero,
              minimumSize: const Size(AppSize.touchTarget, AppSize.navigation),
              tapTargetSize: MaterialTapTargetSize.padded,
              shape: const StadiumBorder(),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxs,
                vertical: AppSpacing.xxs,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: active ? c.primary : c.muted),
                    duration: duration,
                    curve: AppMotion.emphasized,
                    builder: (context, color, child) =>
                        Icon(icon, color: color, size: AppIconSize.large),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  MediaQuery.withClampedTextScaling(
                    maxScaleFactor: AppSize.navigationLabelScale,
                    child: AnimatedDefaultTextStyle(
                      duration: duration,
                      curve: AppMotion.emphasized,
                      style: AppTypography.navigation.copyWith(
                        color: active ? c.primary : c.muted,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
