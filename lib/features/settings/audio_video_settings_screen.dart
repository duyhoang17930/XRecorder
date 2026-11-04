import 'package:flutter/material.dart';

import 'recording_settings_form.dart';

class AudioVideoSettingsScreen extends StatelessWidget {
  const AudioVideoSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Audio & Video Settings')),
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
