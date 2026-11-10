import 'package:xrecorder/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/studio_widgets.dart';
import 'settings_controller.dart';
import '../../l10n/app_languages.dart';
import 'app_language_dialog.dart';

class SettingsHubScreen extends StatefulWidget {
  const SettingsHubScreen({super.key});

  @override
  State<SettingsHubScreen> createState() => _SettingsHubScreenState();
}

class _SettingsHubScreenState extends State<SettingsHubScreen> {
  bool _openingRoute = false;
  bool _openingOverlay = false;

  Future<T?> _present<T>(Future<T?> Function() open) async {
    if (_openingOverlay || _openingRoute || !mounted) return null;
    _openingOverlay = true;
    try {
      return await open();
    } finally {
      _openingOverlay = false;
    }
  }

  Future<void> _open(BuildContext context, String path) async {
    if (_openingRoute ||
        _openingOverlay ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    _openingRoute = true;
    try {
      await context.push<void>(path);
    } finally {
      _openingRoute = false;
    }
  }

  void _details(BuildContext context, String title, String content) {
    _present(
      () => showStudioDialog<void>(
        context: context,
        builder: (dialog) => StudioDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: Text(dialog.l10n.close),
            ),
          ],
        ),
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
        SectionTitle(context.l10n.settings),
        if (settings.persistenceError != null) ...[
          const SizedBox(height: AppSpacing.md),
          StudioCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.message(settings.persistenceError!)),
                Wrap(
                  children: [
                    TextButton(
                      onPressed: settings.retryRestore,
                      child: Text(context.l10n.retryLoading),
                    ),
                    if (settings.canSave)
                      TextButton(
                        onPressed: settings.retrySave,
                        child: Text(context.l10n.retrySaving),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
        StudioSectionLabel(context.l10n.capture),
        StudioCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SettingsRow(
                context.l10n.videoQuality,
                icon: AppIcons.videoSettings,
                subtitle:
                    '${settings.resolution} · ${settings.fps} FPS · ${settings.bitrate}',
                onTap: () => _open(context, '/settings/audio-video'),
              ),
              const Divider(height: 1, indent: 72),
              SettingsRow(
                context.l10n.audioCountdownFacecam,
                icon: AppIcons.microphone,
                onTap: () => _open(context, '/settings/audio-video'),
              ),
            ],
          ),
        ),
        StudioSectionLabel(context.l10n.appearance),
        StudioCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChoiceGroup(
                label: context.l10n.theme,
                options: const ['Dark', 'Light', 'System'],
                optionLabelBuilder: (value) => context.message(value),
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
                context.l10n.systemFollowsYourDeviceAppearance,
                style: TextStyle(color: context.studioColors.muted),
              ),
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                container: true,
                child: SettingsRow(
                  context.l10n.appLanguage,
                  icon: AppIcons.settings,
                  subtitle: settings.appLocale == null
                      ? context.l10n.followSystem
                      : AppLanguages.nativeName(settings.appLocale!),
                  onTap: () => _present(() => showAppLanguageDialog(context)),
                ),
              ),
            ],
          ),
        ),
        StudioSectionLabel(context.l10n.yourWorkspace),
        StudioCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SettingsRow(
                context.l10n.mediaStorage,
                icon: AppIcons.folder,
                subtitle: context.l10n.saveLocations,
                onTap: () => _details(
                  context,
                  context.l10n.mediaStorage,
                  context.l10n.android10MoviesXrecorderAndPicturesXrecorder,
                ),
              ),
              const Divider(height: 1, indent: 72),
              SettingsRow(
                context.l10n.trashRestore,
                icon: AppIcons.trash,
                subtitle: context.l10n.cleanupOnOpeningTrashAfter24Hours,
                onTap: () => _open(context, '/trash'),
              ),
              const Divider(height: 1, indent: 72),
              SettingsRow(
                context.l10n.exportQueue,
                icon: AppIcons.export,
                onTap: () => _open(context, '/exports'),
              ),
            ],
          ),
        ),
        StudioSectionLabel(context.l10n.helpAbout),
        StudioCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SettingsRow(
                context.l10n.helpGuides,
                icon: AppIcons.help,
                onTap: () => _open(context, '/help'),
              ),
              SettingsRow(
                context.l10n.feedback,
                icon: AppIcons.feedback,
                onTap: () => _open(context, '/support'),
              ),
              SettingsRow(
                context.l10n.privacy,
                icon: AppIcons.privacy,
                subtitle: context.l10n.onDeviceProcessing,
                onTap: () => _details(
                  context,
                  context.l10n.privacy,
                  context.l10n.mediaProcessingStaysOnYourDeviceNo,
                ),
              ),
              SettingsRow(
                context.l10n.aboutLicenses,
                icon: AppIcons.info,
                onTap: () => _present(
                  () => showStudioDialog<void>(
                    context: context,
                    builder: (context) => AboutDialog(
                      applicationName: '3HRecorder',
                      applicationVersion: '0.1.0+1',
                      children: [
                        Text(
                          context
                              .l10n
                              .androidScreenRecordingAndNonDestructiveEditing,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          icon: const Icon(AppIcons.reset),
          label: Text(context.l10n.resetPreferences),
          onPressed: () async {
            final confirmed = await _present(
              () => showStudioDialog<bool>(
                context: context,
                builder: (dialog) => StudioDialog(
                  title: Text(dialog.l10n.resetPreferences550bf6),
                  content: Text(
                    dialog.l10n.restoreRecordingAndAppearancePreferencesToTheir,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: Text(dialog.l10n.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: Text(dialog.l10n.reset),
                    ),
                  ],
                ),
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
