import 'package:xrecorder/l10n/localization.dart';
import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';

class ChoiceGroup extends StatelessWidget {
  const ChoiceGroup({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.disabledOptions = const {},
    this.optionLabelBuilder,
  });
  final String label;
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  final Set<String> disabledOptions;
  final String Function(String)? optionLabelBuilder;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.xs),
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xxs,
        children: options
            .map(
              (option) => Tooltip(
                message: disabledOptions.contains(option)
                    ? context.l10n.notSupportedByThisDeviceOrThe
                    : '',
                child: ChoiceChip(
                  label: Text(optionLabelBuilder?.call(option) ?? option),
                  selected: value == option,
                  labelStyle: AppTypography.bodySmall.copyWith(
                    color: disabledOptions.contains(option)
                        ? context.studioColors.disabled
                        : value == option
                        ? context.studioColors.primary
                        : context.studioColors.text,
                  ),
                  onSelected: disabledOptions.contains(option)
                      ? null
                      : (_) => onChanged(option),
                ),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: AppSpacing.md),
    ],
  );
}
