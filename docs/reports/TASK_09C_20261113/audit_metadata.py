"""TASK09C metadata audit. Retains all inputs; creates new reports exclusively."""

import ast
import collections
import csv
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent


def write_json(name, data):
    with (OUT / name).open('x', encoding='utf-8') as stream:
        json.dump(data, stream, indent=2, ensure_ascii=False)
        stream.write('\n')


def owner(path):
    if (path.startswith(('lib/features/recording/', 'docs/p1/'))
            or '/recording/' in path
            or path in {'lib/features/settings/recording_settings_form.dart',
                        'lib/features/settings/audio_video_settings_screen.dart',
                        'lib/core/widgets/studio_create_sheet.dart'}):
        return 'P1 read-only'
    if path.startswith(('lib/features/editor/', 'lib/features/media/photo_')) or '/editor/' in path:
        return 'P3'
    if path.startswith(('build/', 'docs/reports/', 'docs/implementation/TASK_')):
        return 'QA/history; retention owner required'
    if path.startswith(('lib/core/', 'lib/app/', 'lib/l10n/')):
        return 'Shared P2/P3/UIUX'
    if path.startswith(('lib/features/media/', 'lib/features/settings/')) or '/media/' in path:
        return 'P2'
    return 'Shared/repository; exact owner not recorded'


def classify(path):
    parts = path.split('/')
    if parts[0] in {'.git', '.claude-local', 'image', '.vscode'}:
        return 'L UNKNOWN / PROTECTED'
    if any(word in path.lower() for word in ['.avd/', 'checkpoint', 'qa5560',
                                           'backup', 'recovery', '/models/']):
        return 'L UNKNOWN / PROTECTED'
    if path.startswith(('build/verification/', 'build/task', 'docs/reports/')):
        return 'H QA / RECOVERY EVIDENCE'
    if parts[0] in {'build', '.dart_tool'} or any(p in {'.gradle', '__pycache__'} for p in parts):
        return 'I REGENERABLE BUILD ARTIFACT'
    if path.startswith(('test/', 'integration_test/', 'test_driver/')):
        return 'B ACTIVE TEST'
    if path.startswith(('assets/', 'android/app/src/main/res/')):
        return 'E REQUIRED ASSET'
    if path.startswith('tool/'):
        return 'C ACTIVE TOOL'
    if path.startswith('docs/'):
        if Path(path).name.startswith(('TASK_', 'phase_')) or path.startswith('docs/p1/'):
            return 'G HISTORICAL DOCUMENTATION'
        return 'F CURRENT DOCUMENTATION'
    if path.startswith(('lib/', 'android/app/src/main/')):
        return 'A ACTIVE SOURCE'
    if path.startswith('android/app/src/'):
        return 'B ACTIVE TEST'
    if Path(path).suffix in {'.yaml', '.lock', '.kts', '.properties', '.xml', '.json'}:
        return 'D REQUIRED CONFIGURATION'
    if parts[0] in {'ios', 'macos', 'linux', 'windows', 'web'}:
        return 'L UNKNOWN / PROTECTED'
    return 'D REQUIRED CONFIGURATION'


def main():
    baseline = json.loads((OUT / 'baseline_inventory.json').read_text(encoding='utf-8'))
    tracked, ignored = set(baseline['tracked']), set(baseline['ignored'])
    text_files = {}
    for row in baseline['files']:
        path = row['path']
        if (Path(path).suffix in {'.py', '.md', '.dart', '.ps1', '.yaml', '.kts', '.xml'}
                and path.split('/')[0] in {'lib', 'docs', 'tool', 'test', 'integration_test',
                                         'test_driver', 'android', '.github'}
                and '/third_party/' not in path and row['bytes'] < 2_000_000):
            text_files[path] = (ROOT / path).read_text(encoding='utf-8-sig')

    def references(path):
        # Name hits are evidence of retention, never proof of absence/dynamic reachability.
        name = Path(path).name
        return [p for p, text in text_files.items() if p != path and name in text]

    with (OUT / 'FILE_CLASSIFICATION.csv').open('x', encoding='utf-8', newline='') as stream:
        writer = csv.writer(stream)
        writer.writerow(['path', 'classification', 'owner', 'logical_bytes', 'git_status'])
        counts = collections.Counter()
        for row in baseline['files']:
            path = row['path']
            classification = classify(path)
            counts[classification] += 1
            writer.writerow([path, classification, owner(path), row['bytes'],
                             'tracked' if path in tracked else 'ignored' if path in ignored else 'untracked'])

    python_rows, syntax_errors = [], []
    for path, text in text_files.items():
        if not path.endswith('.py'):
            continue
        try:
            tree = ast.parse(text, filename=path)
            compile(text, path, 'exec')  # In-memory only; no pycache or code execution.
            python_rows.append({
                'path': path, 'purpose': ast.get_docstring(tree),
                'imports': sorted({n.module or '' for n in ast.walk(tree) if isinstance(n, ast.ImportFrom)}
                                  | {a.name for n in ast.walk(tree) if isinstance(n, ast.Import) for a in n.names}),
                'references': references(path), 'owner': owner(path),
                'reproducibility_evidence': path.startswith('docs/'),
                'decision': 'retain; historical/protected' if path.startswith('docs/')
                            else 'retain active tool; no removal proof',
                'side_effect_markers': sorted({token for token in ['subprocess', 'unlink', 'rmtree',
                    'uninstall', 'clear', 'urlopen', 'adb'] if token in text}),
            })
        except (SyntaxError, ValueError) as error:
            syntax_errors.append({'path': path, 'error': str(error)})
    write_json('PYTHON_TOOL_AUDIT.json', {'scripts': python_rows, 'syntax_errors': syntax_errors,
        'limits': 'Inspected AST/docstring/imports/name references; scripts not executed. '
                  'No-reference scripts retained. docs scripts remain historical reproduction evidence.'})

    configs, config_errors, config_skips = [], [], []
    for row in baseline['files']:
        path = row['path']
        if path.split('/')[0] not in {'lib', 'android', 'assets', 'docs', 'test', '.github'}:
            continue
        suffix = Path(path).suffix.lower()
        if suffix not in {'.json', '.arb', '.xml'}:
            continue
        if row['bytes'] > 5_000_000:
            config_skips.append({'path': path, 'reason': 'Large historical payload; retained, not parsed'})
            continue
        try:
            text = (ROOT / path).read_text(encoding='utf-8-sig')
            if suffix == '.xml':
                ET.fromstring(text)
            else:
                json.loads(text)
            configs.append(path)
        except (ValueError, ET.ParseError, UnicodeError) as error:
            config_errors.append({'path': path, 'error': str(error),
                                  'baseline_sha256': row.get('sha256'),
                                  'decision': 'retain; do not repair historical evidence'})
    write_json('CONFIG_VALIDATION.json', {'parsed': configs, 'errors': config_errors, 'skipped': config_skips,
        'limits': 'Syntax only; ARB key/placeholder parity checked separately. Build-generated '
                  'JSON and installed model contents not parsed or changed.'})

    duplicate_groups = collections.defaultdict(list)
    for row in baseline['files']:
        path = row['path']
        if row.get('sha256') and (path.startswith(('assets/', 'image/', 'android/app/src/main/res/'))
                                  or (path.startswith('docs/') and path.endswith('.md'))):
            duplicate_groups[row['sha256']].append(row)
    duplicates = []
    for digest, rows in duplicate_groups.items():
        if len(rows) > 1:
            duplicates.append({'sha256': digest, 'files': rows,
                               'references': {r['path']: references(r['path']) for r in rows},
                               'decision': 'retain: reference assets or Android resource qualifiers'})
    write_json('ASSET_DOCUMENT_DUPLICATES.json', duplicates)

    large = []
    for row in baseline['files']:
        if row['bytes'] > 100_000_000:
            large.append({**row, 'classification': classify(row['path']), 'owner': owner(row['path']),
                          'deletion_eligibility': 'not authorized; protected/unknown or retention review required'})
    write_json('LARGE_FILE_RETENTION.json', sorted(large, key=lambda r: -r['bytes']))

    summary = {'classification_counts': dict(counts), 'python_scripts_reviewed': len(python_rows),
               'python_syntax_errors': syntax_errors, 'config_parsed': len(configs),
               'config_errors': config_errors, 'config_skipped': config_skips,
               'duplicate_asset_document_groups': len(duplicates), 'large_files_retained': len(large),
               'absent_directories': [p for p in ['scripts', 'tools'] if not (ROOT / p).exists()],
               'limits': 'Classification is conservative metadata routing, not a claim every historical '
                         'script/API is obsolete or every native symbol was proven live.'}
    write_json('METADATA_AUDIT_SUMMARY.json', summary)
    print(json.dumps({k: v for k, v in summary.items() if k != 'classification_counts'}, ensure_ascii=True))


if __name__ == '__main__':
    main()
