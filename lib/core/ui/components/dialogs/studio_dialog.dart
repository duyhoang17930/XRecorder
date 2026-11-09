import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/motion.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';

Future<T?> showStudioDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  if (ModalRoute.of(context)?.isCurrent == false) return Future<T?>.value();
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: AppColors.mediaScrim,
    builder: builder,
    animationStyle: AnimationStyle(
      duration: context.motion(AppMotion.standard),
      reverseDuration: context.motion(AppMotion.fast),
    ),
  );
}

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
