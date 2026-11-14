"""Scoped presentation-only localization; stable preference values stay unchanged."""
from pathlib import Path
import re

for name in ['lib/features/settings/recording_settings_form.dart', 'lib/features/recording/recording_setup_sheet.dart']:
    path = Path(name); source = path.read_text(encoding='utf8')
    source = re.sub(r"const Text\(\s*('(?:[^'\\]|\\.)*')\s*,?\s*\)", r'Text(context.message(\1))', source)
    source = re.sub(r"(label|tooltip|labelText): ('[A-Za-z][^']*')", r'\1: context.message(\2)', source)
    if 'recording_settings_form' in name:
        source = source.replace('ChoiceGroup(\n', 'ChoiceGroup(\n                optionLabelBuilder: context.message,\n')
        source = source.replace('_gain(\n', '_gain(context,\n')
        source = source.replace('Widget _gain(String label,', 'Widget _gain(BuildContext context, String label,')
        source = source.replace('Widget _autoStop(SettingsController s)', 'Widget _autoStop(BuildContext context, SettingsController s)')
        source = source.replace('_autoStop(s)', '_autoStop(context, s)')
        source = source.replace("Text('$label: ${value.round()}%')", "Text('${context.message(label)}: ${context.displayValue(value.round())}%')")
        source = source.replace('label: label,', 'label: context.message(label),')
    else:
        source = source.replace("title: 'Recording settings'", "title: context.l10n.recordingSettings")
        source = source.replace("Text(advanced ? 'Advanced' : 'Basic')", "Text(context.message(advanced ? 'Advanced' : 'Basic'))")
        source = source.replace("capture.busy ? 'Session already active' : 'Start Recording',", "context.message(capture.busy ? 'Session already active' : 'Start Recording'),")
    path.write_text(source, encoding='utf8')
