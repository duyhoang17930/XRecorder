import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../cards/studio_cards.dart' show StudioIconTile;
import '../../theme/motion.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';

final _dialogOrigins = Expando<Set<ModalRoute<dynamic>?>>();

Future<T?> showStudioDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) async {
  if (!context.mounted) return null;
  final origin = ModalRoute.of(context);
  if (origin?.isCurrent == false) return null;
  final navigator = Navigator.of(context, rootNavigator: true);
  final origins = _dialogOrigins[navigator] ??= <ModalRoute<dynamic>?>{};
  // A branch route can remain current while a root dialog covers its shell.
  // Lock that origin synchronously; a current dialog may still open a child.
  if (!origins.add(origin)) return null;
  try {
    return await showDialog<T>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: barrierDismissible,
      barrierColor: AppColors.mediaScrim,
      builder: builder,
      animationStyle: AnimationStyle(
        duration: context.motion(AppMotion.standard),
        reverseDuration: context.motion(AppMotion.fast),
      ),
    );
  } finally {
    origins.remove(origin);
  }
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
                StudioIconTile(
                  icon: icon!,
                  size: 40,
                  iconSize: AppIconSize.medium,
                ),
                const SizedBox(width: AppSpacing.sm),
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
