import 'package:flutter/material.dart';

import '../../../constants/app_icons.dart';
import '../../../../l10n/localization.dart';

import '../../theme/colors.dart';
import '../../theme/typography.dart';

/// Controller remains owned by its field/dialog until the route unmounts.
/// Clearing edits the text only; it never submits or changes keyboard focus.
class StudioClearTextButton extends StatelessWidget {
  const StudioClearTextButton({
    super.key,
    required this.controller,
    this.enabled = true,
  });
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => value.text.isEmpty
            ? const SizedBox.shrink()
            : IconButton(
                tooltip: context.l10n.clearText,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: enabled ? controller.clear : null,
                icon: const Icon(AppIcons.close),
              ),
      );
}

class StudioTextField extends StatelessWidget {
  const StudioTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? labelText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;
  final int? minLines;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    focusNode: focusNode,
    maxLines: maxLines,
    minLines: minLines,
    enabled: enabled,
    readOnly: readOnly,
    autofocus: autofocus,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    textCapitalization: textCapitalization,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    style: AppTypography.body.copyWith(color: context.studioColors.text),
    decoration: InputDecoration(
      hintText: hintText,
      labelText: labelText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
    ),
  );
}
