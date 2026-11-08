import 'package:flutter/material.dart';

import '../../core/widgets/studio_widgets.dart';
import '../../l10n/localization.dart';
import 'speech_languages.dart';

Future<SpeechLanguage?> chooseSpeechLanguage(
  BuildContext context,
  String current,
) => showStudioDialog<SpeechLanguage>(
  context: context,
  builder: (_) => _SpeechLanguageDialog(current: current),
);

class _SpeechLanguageDialog extends StatefulWidget {
  const _SpeechLanguageDialog({required this.current});
  final String current;
  @override
  State<_SpeechLanguageDialog> createState() => _SpeechLanguageDialogState();
}

class _SpeechLanguageDialogState extends State<_SpeechLanguageDialog> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;
    final matching = SpeechLanguages.values
        .where(
          (language) =>
              '${language.code} ${language.englishName} ${language.nativeName} ${language.displayName(strings)}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    return StudioDialog(
      title: Text(strings.speechLanguage),
      content: SizedBox(
        width: 460,
        height: 440,
        child: Column(
          children: [
            StudioSearchField(
              hintText: strings.searchLanguages,
              onChanged: (value) =>
                  setState(() => query = value.trim().toLowerCase()),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: matching.length,
                itemBuilder: (context, index) {
                  final language = matching[index];
                  return ListTile(
                    title: Text(language.displayName(strings)),
                    subtitle: Text(
                      language.code == 'auto'
                          ? strings.reviewSubtitles
                          : '${language.nativeName} · ${language.code}${language.available ? '' : ' · ${strings.speechLanguageUnavailable}'}',
                    ),
                    enabled: language.available,
                    trailing: language.code == widget.current
                        ? const Icon(AppIcons.ready)
                        : null,
                    onTap: language.available
                        ? () => Navigator.pop(context, language)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.close),
        ),
      ],
    );
  }
}
