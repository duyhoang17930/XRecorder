import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/studio_widgets.dart';
import 'settings_controller.dart';

class SettingsHubScreen extends StatelessWidget {
  const SettingsHubScreen({super.key});

  void _details(BuildContext context, String title, String content) {
    showStudioDialog<void>(
      context: context,
      builder: (dialog) => StudioDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    return ListView(
      primary: true,
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const SectionTitle('Settings'),
        if (settings.persistenceError != null) ...[
          const SizedBox(height: AppSpacing.md),
          StudioCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(settings.persistenceError!),
                Wrap(
                  children: [
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
                ),
              ],
            ),
          ),
        ],
        const StudioSectionLabel('CAPTURE'),
        StudioCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SettingsRow(
                'Video quality',
                icon: AppIcons.videoSettings,
                subtitle:
                    '${settings.resolution} · ${settings.fps} FPS · ${settings.bitrate}',
                onTap: () => context.push('/settings/audio-video'),
              ),
              const Divider(height: 1, indent: 72),
              SettingsRow(
                'Audio, countdown & facecam',
                icon: AppIcons.microphone,
                onTap: () => context.push('/settings/audio-video'),
              ),
            ],
          ),
        ),
        const StudioSectionLabel('APPEARANCE'),
        StudioCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChoiceGroup(
                label: 'Theme',
                options: const ['Dark', 'Light', 'System'],
                value: switch (settings.themeMode) {
                  ThemeMode.dark => 'Dark',
                  ThemeMode.light => 'Light',
                  ThemeMode.system => 'System',
                },
                onChanged: (value) => settings.setThemeMode(switch (value) {
                  'Light' => ThemeMode.light,
                  'System' => ThemeMode.system,
                  _ => ThemeMode.dark,
                }),
              ),
              Text(
                'System follows your device appearance.',
                style: TextStyle(color: context.studioColors.muted),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text('Language · English'),
            ],
          ),
        ),
        const StudioSectionLabel('YOUR WORKSPACE'),
        StudioCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SettingsRow(
                'Media storage',
                icon: AppIcons.folder,
                subtitle: 'Save locations',
                onTap: () => _details(
                  context,
                  'Media storage',
                  'Android 10+: Movies/XRecorder and Pictures/XRecorder. Older Android: app-specific external storage. Open library storage for actual usage.',
                ),
              ),
              const Divider(height: 1, indent: 72),
              SettingsRow(
                'Trash & restore',
                icon: AppIcons.trash,
                subtitle: 'Cleanup on opening Trash after 24 hours',
                onTap: () => context.push('/trash'),
              ),
              const Divider(height: 1, indent: 72),
              SettingsRow(
                'Export queue',
                icon: AppIcons.export,
                onTap: () => context.push('/exports'),
              ),
            ],
          ),
        ),
        const StudioSectionLabel('HELP & ABOUT'),
        StudioCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SettingsRow(
                'Help & guides',
                icon: AppIcons.help,
                onTap: () => context.push('/help'),
              ),
              SettingsRow(
                'Feedback',
                icon: AppIcons.feedback,
                onTap: () => context.push('/support'),
              ),
              SettingsRow(
                'Privacy',
                icon: AppIcons.privacy,
                subtitle: 'On-device processing',
                onTap: () => _details(
                  context,
                  'Privacy',
                  'Media processing stays on your device. No analytics, AI upload or livestream is enabled. Only explicit sharing hands content to another app.',
                ),
              ),
              SettingsRow(
                'About & licenses',
                icon: AppIcons.info,
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: '3HRecorder',
                  applicationVersion: '0.1.0+1',
                  children: [
                    const Text(
                      'Android screen recording and non-destructive editing. Media3: Apache-2.0. Manrope: SIL OFL. Lucide Flutter: MIT; Lucide artwork: ISC. See licenses for details.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          icon: const Icon(AppIcons.reset),
          label: const Text('Reset preferences'),
          onPressed: () async {
            final confirmed = await showStudioDialog<bool>(
              context: context,
              builder: (dialog) => StudioDialog(
                title: const Text('Reset preferences?'),
                content: const Text(
                  'Restore recording and appearance preferences to their defaults. Media and editor drafts are kept.',
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
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
