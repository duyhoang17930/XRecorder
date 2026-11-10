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
  final search = TextEditingController();
  final searchFocus = FocusNode();
  final searchKey = GlobalKey(debugLabel: 'language-search');

  @override
  void dispose() {
    search.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  Widget _searchField(BuildContext context) => StudioSearchField(
    key: searchKey,
    controller: search,
    focusNode: searchFocus,
    hintText: context.l10n.searchLanguages,
    onChanged: (value) => setState(() => query = value.trim().toLowerCase()),
  );

  Widget _options(Locale? selected, {bool compact = false}) => ListView(
    shrinkWrap: compact,
    physics: compact ? const NeverScrollableScrollPhysics() : null,
    children: [
      if (query.isEmpty ||
          context.l10n.followSystem.toLowerCase().contains(query))
        _option(
          null,
          context.l10n.followSystem,
          selected == null,
          compact: compact,
        ),
      for (final locale in AppLanguages.supported)
        if ('${AppLanguages.nativeName(locale)} ${locale.toLanguageTag()}'
            .toLowerCase()
            .contains(query))
          _option(
            locale,
            AppLanguages.nativeName(locale),
            selected == locale,
            compact: compact,
          ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final selected = widget.settings.appLocale;
    final media = MediaQuery.of(context);
    final availableHeight =
        media.size.height -
        media.viewInsets.bottom -
        media.viewPadding.vertical;
    if (availableHeight < 300) {
      return Semantics(
        namesRoute: true,
        label: context.l10n.appLanguage,
        child: Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: 420,
            height: (availableHeight - 16).clamp(0, 300),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _searchField(context)),
                        const SizedBox(width: AppSpacing.xs),
                        IconButton(
                          tooltip: context.l10n.close,
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(AppIcons.close),
                        ),
                      ],
                    ),
                    _options(selected, compact: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return StudioDialog(
      title: Text(context.l10n.appLanguage),
      content: SizedBox(
        width: 420,
        height:
            ((MediaQuery.sizeOf(context).height -
                        MediaQuery.viewInsetsOf(context).bottom) *
                    .5)
                .clamp(120.0, 440.0),
        child: Column(
          children: [
            _searchField(context),
            Expanded(child: _options(selected)),
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

  Widget _option(
    Locale? locale,
    String name,
    bool selected, {
    bool compact = false,
  }) => ListTile(
    minTileHeight: compact ? AppSize.touchTarget : null,
    selectedTileColor: context.studioColors.primary.withValues(alpha: .10),
    selectedColor: context.studioColors.text,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
    ),
    title: Text(name),
    trailing: selected ? const Icon(AppIcons.ready) : null,
    selected: selected,
    onTap: () {
      widget.settings.setAppLocale(locale);
      Navigator.pop(context);
    },
  );
}
