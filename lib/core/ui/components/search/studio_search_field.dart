import 'package:xrecorder/l10n/localization.dart';
import 'package:flutter/material.dart';

import '../../../constants/app_icons.dart';
import '../../theme/colors.dart';
import '../../theme/radius.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';

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
  Widget build(BuildContext context) {
    final colors = context.studioColors;
    return Container(
      constraints: const BoxConstraints(minHeight: AppSize.touchTarget),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppRadius.search),
        boxShadow: AppShadows.search(context),
      ),
      child: Row(
        children: [
          Icon(AppIcons.search, size: AppIconSize.small, color: colors.muted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
              textInputAction: TextInputAction.search,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              textAlignVertical: TextAlignVertical.center,
              style: AppTypography.body.copyWith(color: colors.text),
              decoration: InputDecoration(
                hintText: context.message(widget.hintText),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                // Give the editable semantics node the full Android tap target,
                // not just the height of its text line.
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: context.l10n.clearSearch,
              onPressed: () {
                _controller.clear();
                widget.onChanged?.call('');
                widget.focusNode?.requestFocus();
              },
              icon: const Icon(AppIcons.close, size: AppIconSize.medium),
            ),
        ],
      ),
    );
  }
}
