import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/studio_widgets.dart';
import 'settings_controller.dart';

class SettingsHubScreen extends StatelessWidget {
  const SettingsHubScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle('Settings'),
        if (settings.persistenceError != null) ...[
          Text(settings.persistenceError!),
          TextButton(
            onPressed: settings.retryRestore,
            child: const Text('Retry loading'),
          ),
          if (settings.canSave)
            TextButton(
              onPressed: settings.retrySave,
              child: const Text('Retry saving'),
            ),
        ],
        SettingsRow(
          'Resolution & Video Quality',
          icon: Icons.video_settings,
          subtitle:
              '${settings.resolution} · ${settings.fps} FPS · ${settings.bitrate}',
          onTap: () => context.push('/settings/audio-video'),
        ),
        SettingsRow(
          'Audio, countdown & facecam',
          icon: Icons.mic_none,
          subtitle: 'Capability-aware settings for your next recording',
          onTap: () => context.push('/settings/audio-video'),
        ),
        const ListTile(
          leading: Icon(Icons.folder_outlined),
          title: Text('Media storage'),
          subtitle: Text(
            'Android 10+: Movies/XRecorder and Pictures/XRecorder. Older Android: app-specific external storage. Open the library storage button for actual usage.',
          ),
        ),
        SettingsRow(
          'Trash & restore',
          icon: Icons.delete_outline,
          subtitle: 'Cleanup on opening Trash after 24 hours',
          onTap: () => context.push('/trash'),
        ),
        SettingsRow(
          'Export queue',
          icon: Icons.file_upload_outlined,
          subtitle: 'Progress, cancellation and retry',
          onTap: () => context.push('/exports'),
        ),
        SettingsRow(
          'FAQ & User Guide',
          icon: Icons.help_outline,
          onTap: () => context.push('/help'),
        ),
        SettingsRow(
          'Feedback & issue report',
          icon: Icons.feedback_outlined,
          onTap: () => context.push('/support'),
        ),
        const ListTile(
          leading: Icon(Icons.translate),
          title: Text('Language & appearance'),
          subtitle: Text('English · Dark theme'),
        ),
        const ListTile(
          leading: Icon(Icons.privacy_tip_outlined),
          title: Text('Privacy'),
          subtitle: Text(
            'Media processing stays on your device. No analytics, AI upload or livestream is enabled. Only explicit sharing hands content to another app.',
          ),
        ),
        SettingsRow(
          'About & licenses',
          icon: Icons.info_outline,
          onTap: () => showAboutDialog(
            context: context,
            applicationName: 'XRecorder',
          applicationVersion: '0.1.0+1',
            children: [
              const Text(
                'Android screen recording and non-destructive media editing. AndroidX Media3 is licensed under Apache-2.0. Manrope uses the SIL Open Font License. See the bundled license list.',
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialog) => AlertDialog(
                title: const Text('Reset preferences?'),
                content: const Text(
                  'Restore recording preferences to their defaults. Media and editor drafts are kept.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            );
            if (confirmed == true) settings.reset();
          },
          child: const Text('Reset preferences'),
        ),
      ],
    );
  }
}
