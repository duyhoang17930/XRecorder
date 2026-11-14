import 'package:flutter/material.dart';

import '../../l10n/localization.dart';
import 'recording_settings_form.dart';

class AudioVideoSettingsScreen extends StatelessWidget {
  const AudioVideoSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.recordingSettings)),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: RecordingSettingsForm(),
          ),
        ),
      ),
    ),
  );
}
