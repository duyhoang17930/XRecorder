import 'package:flutter/material.dart';

import '../../core/widgets/studio_widgets.dart';
import '../../l10n/app_languages.dart';
import '../../l10n/localization.dart';
import 'settings_controller.dart';

Future<void> showAppLanguageDialog(BuildContext context) {
  final settings = SettingsScope.of(context);
  return showStudioDialog<void>(
    context: context,
    builder: (_) => _AppLanguageDialog(settings: settings),
  );
}

class _AppLanguageDialog extends StatefulWidget {
  const _AppLanguageDialog({required this.settings});
  final SettingsController settings;
  @override
  State<_AppLanguageDialog> createState() => _AppLanguageDialogState();
}

class _AppLanguageDialogState extends State<_AppLanguageDialog> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final selected = widget.settings.appLocale;
    return StudioDialog(
      title: Text(context.l10n.appLanguage),
      content: SizedBox(
        width: 420,
        height: 440,
        child: Column(
          children: [
            StudioSearchField(
              hintText: context.l10n.searchLanguages,
              onChanged: (value) =>
                  setState(() => query = value.trim().toLowerCase()),
            ),
            Expanded(
              child: ListView(
                children: [
                  if (query.isEmpty ||
                      context.l10n.followSystem.toLowerCase().contains(query))
                    _option(null, context.l10n.followSystem, selected == null),
                  for (final locale in AppLanguages.supported)
                    if ('${AppLanguages.nativeName(locale)} ${locale.toLanguageTag()}'
                        .toLowerCase()
                        .contains(query))
                      _option(
                        locale,
                        AppLanguages.nativeName(locale),
                        selected == locale,
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.close),
        ),
      ],
    );
  }

  Widget _option(Locale? locale, String name, bool selected) => ListTile(
    title: Text(name),
    trailing: selected ? const Icon(AppIcons.ready) : null,
    selected: selected,
    onTap: () {
      widget.settings.setAppLocale(locale);
      Navigator.pop(context);
    },
  );
}
