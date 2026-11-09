import 'package:flutter/material.dart';

import '../../../constants/app_icons.dart';
import '../../theme/colors.dart';
import '../../theme/radius.dart';
import '../../theme/typography.dart';

class StudioDropdown<T> extends StatelessWidget {
  const StudioDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelText,
    this.hintText,
    this.enabled = true,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? labelText;
  final String? hintText;
  final bool enabled;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    key: ValueKey(value),
    initialValue: value,
    items: items,
    onChanged: enabled ? onChanged : null,
    isExpanded: true,
    style: AppTypography.body.copyWith(color: context.studioColors.text),
    icon: Icon(AppIcons.chevronDown, color: context.studioColors.muted),
    hint: hintText == null ? null : Text(hintText!),
    decoration: InputDecoration(labelText: labelText),
    borderRadius: BorderRadius.circular(AppRadius.menu),
    dropdownColor: context.studioColors.elevated,
  );
}
