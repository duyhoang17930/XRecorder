import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../constants/design_tokens.dart';

Future<T?> showStudioBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = true,
  bool enableDrag = true,
  bool isDismissible = true,
}) => showModalBottomSheet<T>(
  context: context,
  builder: builder,
  isScrollControlled: isScrollControlled,
  useSafeArea: useSafeArea,
  enableDrag: enableDrag,
  isDismissible: isDismissible,
  backgroundColor: context.studioColors.surface,
  barrierColor: AppColors.mediaScrim,
  elevation: 0,
  clipBehavior: Clip.antiAlias,
  sheetAnimationStyle: AnimationStyle(
    duration: context.motion(AppMotion.slow),
    reverseDuration: context.motion(AppMotion.standard),
  ),
  shape: RoundedRectangleBorder(
    borderRadius: const BorderRadius.vertical(
      top: Radius.circular(AppRadius.feature),
    ),
    side: BorderSide(color: context.studioColors.border),
  ),
);

Future<T?> showStudioDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => showDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  barrierColor: AppColors.mediaScrim,
  builder: builder,
  animationStyle: AnimationStyle(
    duration: context.motion(AppMotion.standard),
    reverseDuration: context.motion(AppMotion.fast),
  ),
);

class StudioDialog extends StatelessWidget {
  const StudioDialog({
    super.key,
    this.title,
    this.icon,
    this.content,
    this.actions = const [],
    this.insetPadding = const EdgeInsets.symmetric(
      horizontal: 28,
      vertical: 24,
    ),
    this.contentPadding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.xs,
    ),
  });

  final Widget? title;
  final IconData? icon;
  final Widget? content;
  final List<Widget> actions;
  final EdgeInsets insetPadding;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    insetPadding: insetPadding,
    title: title == null && icon == null
        ? null
        : Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: context.studioColors.primary,
                  size: AppIconSize.large,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              if (title != null) Expanded(child: title!),
            ],
          ),
    content: content == null
        ? null
        : DefaultTextStyle(
            style: AppTypography.body.copyWith(
              color: context.studioColors.muted,
            ),
            child: content!,
          ),
    contentPadding: contentPadding,
    actions: actions,
  );
}

class StudioSheetHeader extends StatelessWidget {
  const StudioSheetHeader({
    super.key,
    required this.title,
    this.description,
    this.icon,
    this.actions = const [],
  });

  final String title;
  final String? description;
  final IconData? icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: context.studioColors.primary,
                size: AppIconSize.large,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            ...actions,
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            description!,
            style: AppTypography.body.copyWith(
              color: context.studioColors.muted,
            ),
          ),
        ],
      ],
    ),
  );
}
