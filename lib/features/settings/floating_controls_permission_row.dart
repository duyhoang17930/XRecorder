import 'package:flutter/material.dart';

import '../../core/constants/app_icons.dart';
import '../../core/ui/components/lists/studio_list.dart';
import '../../l10n/localization.dart';
import '../recording/recording_service.dart';

class FloatingControlsPermissionRow extends StatefulWidget {
  const FloatingControlsPermissionRow({super.key});

  @override
  State<FloatingControlsPermissionRow> createState() =>
      _FloatingControlsPermissionRowState();
}

class _FloatingControlsPermissionRowState
    extends State<FloatingControlsPermissionRow>
    with WidgetsBindingObserver {
  final _service = AndroidRecordingService();
  bool? _allowed;
  bool _openingSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final allowed = await _service.overlayPermissionGranted();
    if (mounted) setState(() => _allowed = allowed);
  }

  Future<void> _openSettings() async {
    if (_openingSettings) return;
    setState(() => _openingSettings = true);
    final opened = await _service.openOverlayPermissionSettings();
    if (!mounted) return;
    setState(() => _openingSettings = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.floatingControlsSettingsError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (_allowed) {
      true => context.l10n.floatingControlsPermissionGranted,
      false => context.l10n.floatingControlsPermissionRequired,
      null => null,
    };
    final title = context.l10n.floatingControlsTitle;
    final onTap = _openingSettings ? null : _openSettings;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: title,
      value: subtitle,
      hint: context.l10n.floatingControlsOpenHint,
      onTap: onTap,
      child: ExcludeSemantics(
        child: SettingsRow(
          title,
          icon: AppIcons.pictureInPicture,
          subtitle: subtitle,
          onTap: onTap,
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
