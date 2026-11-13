import 'package:flutter/material.dart';

import '../../../../l10n/localization.dart';
import '../inputs/studio_fields.dart';
import 'studio_dialog.dart';

/// Shared name-entry presentation. Callers retain validation and save semantics.
class StudioNameDialog extends StatefulWidget {
  const StudioNameDialog({
    super.key,
    required this.initial,
    required this.title,
    required this.label,
    required this.maxLength,
    required this.submitLabel,
    required this.onSubmit,
  });

  final String initial;
  final String title;
  final String label;
  final int maxLength;
  final String submitLabel;
  final ValueChanged<String> onSubmit;

  @override
  State<StudioNameDialog> createState() => _StudioNameDialogState();
}

class _StudioNameDialogState extends State<StudioNameDialog> {
  late final field = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StudioDialog(
    title: Text(widget.title),
    content: TextField(
      controller: field,
      maxLength: widget.maxLength,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: StudioClearTextButton(controller: field),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      TextButton(
        onPressed: () => widget.onSubmit(field.text),
        child: Text(widget.submitLabel),
      ),
    ],
  );
}
