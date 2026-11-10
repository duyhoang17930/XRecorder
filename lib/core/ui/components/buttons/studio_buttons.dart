import 'package:flutter/material.dart';

import '../../../constants/app_icons.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon = AppIcons.forward,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: AppIconSize.medium),
      label: Text(label, textAlign: TextAlign.center),
    ),
  );
}

class RecordActionButton extends StatelessWidget {
  const RecordActionButton({
    super.key,
    required this.onPressed,
    this.label = 'Record screen',
  });
  final VoidCallback? onPressed;
  final String label;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: context.studioColors.primary,
      foregroundColor: context.studioColors.primaryForeground,
    ),
    icon: const Icon(AppIcons.record, size: AppIconSize.medium),
    label: Text(label, textAlign: TextAlign.center),
  );
}
