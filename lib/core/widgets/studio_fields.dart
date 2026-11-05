import '../constants/app_icons.dart';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../constants/design_tokens.dart';

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

class StudioSearchField extends StatefulWidget {
  const StudioSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  State<StudioSearchField> createState() => _StudioSearchFieldState();
}

class _StudioSearchFieldState extends State<StudioSearchField> {
  late TextEditingController _controller;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _useController(widget.controller);
  }

  @override
  void didUpdateWidget(covariant StudioSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_handleControllerChange);
      if (_ownsController) _controller.dispose();
      _useController(widget.controller);
    }
  }

  void _useController(TextEditingController? controller) {
    _ownsController = controller == null;
    _controller = controller ?? TextEditingController();
    _controller.addListener(_handleControllerChange);
  }

  void _handleControllerChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChange);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StudioTextField(
    controller: _controller,
    focusNode: widget.focusNode,
    hintText: widget.hintText,
    autofocus: widget.autofocus,
    textInputAction: TextInputAction.search,
    onChanged: widget.onChanged,
    onSubmitted: widget.onSubmitted,
    prefixIcon: Icon(
      AppIcons.search,
      size: AppIconSize.medium,
      color: context.studioColors.muted,
    ),
    suffixIcon: _controller.text.isEmpty
        ? null
        : IconButton(
            tooltip: 'Clear search',
            onPressed: () {
              _controller.clear();
              widget.onChanged?.call('');
            },
            icon: const Icon(AppIcons.close, size: AppIconSize.medium),
          ),
  );
}

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
    borderRadius: BorderRadius.circular(AppRadius.control),
    dropdownColor: context.studioColors.elevated,
  );
}
