import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/motion.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';

Future<T?> showStudioBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = true,
  bool enableDrag = true,
  bool isDismissible = true,
}) {
  if (ModalRoute.of(context)?.isCurrent == false) return Future<T?>.value();
  return showModalBottomSheet<T>(
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
