"""TASK09C final host integrity checks; never deletes or rewrites source."""

import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1048576), b''):
            h.update(chunk)
    return h.hexdigest()


def write_new(name, data):
    with (OUT / name).open('x', encoding='utf-8') as stream:
        json.dump(data, stream, indent=2, ensure_ascii=False)
        stream.write('\n')


def main():
    baseline = json.loads((OUT / 'baseline_inventory.json').read_text(encoding='utf-8'))
    manifest = json.loads((OUT / 'CLEANUP_MANIFEST.json').read_text(encoding='utf-8'))
    allowed_changes = {'README.md', 'tool/evaluate_task07_asr.py', 'tool/analyze_whisper_benchmark.py',
                       'lib/features/editor/editor_screen.dart', 'lib/features/media/video_details_screen.dart'}
    allowed_deletes = {r['relative_path'] for r in manifest['candidates'] if r['result'] == 'deleted'}
    changed, missing = [], []
    for row in baseline['files']:
        path = ROOT / row['path']
        if not path.exists():
            missing.append(row['path'])
        elif row.get('sha256') and digest(path) != row['sha256']:
            changed.append(row['path'])

    diff = subprocess.run(['git', 'diff', '--check'], cwd=ROOT, capture_output=True, text=True)
    status = subprocess.check_output(['git', 'status', '--porcelain=v1', '-uall'], cwd=ROOT,
                                     encoding='utf-8')
    staged = subprocess.check_output(['git', 'diff', '--cached', '--name-status'], cwd=ROOT,
                                     encoding='utf-8')
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, encoding='utf-8').strip()

    docs = [ROOT / 'README.md', ROOT / 'docs/README.md', *OUT.glob('*.md')]
    links, broken, controls = [], [], []
    for path in docs:
        text = path.read_text(encoding='utf-8')
        if any(ord(c) < 32 and c not in '\t\n\r' for c in text):
            controls.append(path.relative_to(ROOT).as_posix())
        for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)', text):
            target = target.strip('<>').split('#')[0]
            if not target or re.match(r'[a-z]+://|mailto:', target):
                continue
            actual = path.parent / unquote(target)
            row = {'from': path.relative_to(ROOT).as_posix(), 'target': target, 'exists': actual.exists()}
            links.append(row)
            if not actual.exists():
                broken.append(row)

    imports, bad_imports = [], []
    for path in (ROOT / 'lib').rglob('*.dart'):
        if 'generated' in path.parts:
            continue
        text = path.read_text(encoding='utf-8')
        for uri in re.findall(r"(?:import|export|part)\s+['\"]([^'\"]+)['\"]", text):
            if uri.startswith('package:xrecorder/'):
                target = ROOT / 'lib' / uri.removeprefix('package:xrecorder/')
            elif ':' not in uri:
                target = path.parent / uri
            else:
                continue
            row = {'from': path.relative_to(ROOT).as_posix(), 'uri': uri, 'exists': target.exists()}
            imports.append(row)
            if not target.exists():
                bad_imports.append(row)

    syntax = []
    paths = [ROOT / 'tool/repository_inventory.py', ROOT / 'tool/asr_metrics.py',
             ROOT / 'tool/tests/test_asr_metrics.py', ROOT / 'tool/evaluate_task07_asr.py',
             ROOT / 'tool/analyze_whisper_benchmark.py', *OUT.glob('*.py')]
    for path in paths:
        text = path.read_text(encoding='utf-8')
        ast.parse(text, filename=str(path))
        compile(text, str(path), 'exec')
        syntax.append(path.relative_to(ROOT).as_posix())

    new_text_whitespace = []
    for line in status.splitlines():
        if not line.startswith('?? '):
            continue
        path = ROOT / line[3:]
        if path.suffix not in {'.py', '.md', '.dart', '.json', '.patch', '.csv'}:
            continue
        # Only new TASK09C files, never reformat pre-existing untracked user work.
        if not (str(path).startswith(str(OUT)) or path in {
                ROOT / 'tool/repository_inventory.py', ROOT / 'tool/asr_metrics.py',
                ROOT / 'tool/tests/test_asr_metrics.py', ROOT / 'docs/README.md',
                ROOT / 'lib/core/ui/components/dialogs/studio_name_dialog.dart'}):
            continue
        if path.suffix == '.patch':
            continue  # Unified diff context uses leading blank markers intentionally.
        for number, text in enumerate(path.read_text(encoding='utf-8-sig').splitlines(), 1):
            if text.rstrip(' \t') != text:
                new_text_whitespace.append({'path': line[3:], 'line': number})

    findings = {
        'head_unchanged': head == baseline['head'], 'staging_empty': staged == '',
        'expected_changed_files': sorted(changed), 'unexpected_changed_files': sorted(set(changed) - allowed_changes),
        'missing_files': sorted(missing), 'unexpected_missing_files': sorted(set(missing) - allowed_deletes),
        'git_diff_check_exit': diff.returncode, 'git_diff_check_stderr': diff.stderr,
        'new_text_whitespace': new_text_whitespace,
        'local_links_checked': len(links), 'broken_links': broken, 'control_character_files': controls,
        'local_dart_imports_checked': len(imports), 'broken_dart_imports': bad_imports,
        'python_syntax_checked': syntax,
        'limits': 'Local link targets checked, not remote URLs or every Markdown anchor. '
                  'Historical XML/l10n baseline findings remain separate. Native/device QA not run.',
    }
    failures = (not findings['head_unchanged'] or not findings['staging_empty']
                or set(changed) != allowed_changes or set(missing) != allowed_deletes
                or diff.returncode or new_text_whitespace or broken or controls or bad_imports)
    findings['task09c_integrity'] = 'FAIL' if failures else 'PASS'
    write_new('final_checks.json', findings)
    write_new('final_git_status.json', {'head': head, 'status_porcelain': status,
                                       'staged_diff': staged,
                                       'note': 'Snapshot before writing these two final JSON reports.'})
    print(json.dumps(findings, ensure_ascii=True))
    raise SystemExit(1 if failures else 0)


if __name__ == '__main__':
    main()
