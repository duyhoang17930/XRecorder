import 'package:flutter/material.dart';

import '../../../constants/app_icons.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../cards/studio_cards.dart' show StudioIconTile;

class SettingsRow extends StatelessWidget {
  const SettingsRow(
    this.title, {
    super.key,
    required this.icon,
    this.subtitle,
    this.onTap,
    this.value,
    this.onChanged,
    this.iconColor,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool? value;
  final ValueChanged<bool>? onChanged;
  final Color? iconColor;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    leading: StudioIconTile(icon: icon, color: iconColor),
    title: Text(title, style: AppTypography.bodyEmphasis),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle!,
            style: AppTypography.bodySmall.copyWith(
              color: context.studioColors.muted,
            ),
          ),
    trailing: value == null
        ? (onTap == null
              ? null
              : Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? AppIcons.back
                      : AppIcons.chevronRight,
                  size: AppIconSize.medium,
                  color: context.studioColors.muted,
                ))
        : Switch(value: value!, onChanged: onChanged),
    onTap: onTap,
  );
}
