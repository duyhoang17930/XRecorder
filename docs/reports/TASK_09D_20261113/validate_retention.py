"""Verify TASK09D file-only cleanup without rebuilding caches or touching devices."""

import ast
import argparse
import collections
import hashlib
import json
from pathlib import Path
import re
import shutil
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--refresh', action='store_true', help='Refresh only this task-owned VALIDATION.json')
    args = parser.parse_args()
    baseline = json.loads((OUT / 'BASELINE.json').read_text(encoding='utf-8'))
    previous = json.loads(Path(baseline['reused_inventory']).read_text(encoding='utf-8'))
    removed = json.loads((OUT / 'FILES_REMOVED_MANIFEST.json').read_text(encoding='utf-8'))
    expected_missing = {r['relative_path'] for r in removed['files']}
    missing = [r['path'] for r in previous['files'] if not (ROOT / r['path']).exists()]
    lost_untracked = [line[3:] for line in baseline['git_status'].splitlines()
                      if line.startswith('?? ') and not (ROOT / line[3:]).is_file()]

    hashes = json.loads((OUT / 'SOURCE_PRESERVATION_BASELINE.json').read_text(encoding='utf-8'))
    changed = [r['path'] for r in hashes if digest(ROOT / r['path']) != r['sha256']]
    index = ROOT / 'docs/README.md'
    added_rows = ('| Architecture and feature status |', '| Testing instructions and acceptance criteria |',
                  '| Globalization and speech interfaces |', '| Known bugs and TASK10 prerequisites |',
                  '| Historical retention and storage decisions |')
    original_index = '\n'.join(line for line in index.read_text(encoding='utf-8').split('\n')
                               if not line.startswith(added_rows))
    expected_index = next(r['sha256'] for r in hashes if r['path'] == 'docs/README.md')
    index_additions_only = any(hashlib.sha256(original_index.replace('\n', eol).encode()).hexdigest()
                               == expected_index for eol in ['\n', '\r\n'])
    reference_index = ROOT / 'docs/REFERENCE_INDEX.md'
    expected_reference = next(r['sha256'] for r in hashes if r['path'] == 'docs/REFERENCE_INDEX.md')
    reference_prefix_only = (hashlib.sha256(reference_index.read_bytes().replace(
        b'](../image/', b'](../images/')).hexdigest() == expected_reference)

    protected_deltas = []
    for r in previous['files']:
        path = r['path']
        if not any(s in path.lower() for s in ['.avd/', 'checkpoint', 'qa5560', '/models/',
                                              'recovery', 'backup', '/assets/']):
            continue
        if not (ROOT / path).exists():
            protected_deltas.append(path)
            continue
        stat = (ROOT / path).stat()
        if stat.st_size != r['bytes'] or stat.st_mtime_ns != r['mtime_ns']:
            protected_deltas.append(path)

    paths = {r['path'] for r in previous['files'] if r['path'].startswith('docs/') and r['path'].endswith('.md')}
    paths.update(str(p.relative_to(ROOT)).replace('\\', '/') for p in OUT.glob('*.md'))
    paths.update({'README.md', 'docs/README.md'})
    new_documents = {'docs/README.md', 'docs/REFERENCE_INDEX.md', *[p.relative_to(ROOT).as_posix() for p in OUT.glob('*.md')]}
    broken, new_broken, checked = [], [], 0
    controls, whitespace = [], []
    for name in sorted(paths):
        path = ROOT / name
        if not path.exists():
            continue
        text = path.read_text(encoding='utf-8-sig')
        if name in new_documents:
            if any(ord(c) < 32 and c not in '\t\n\r' for c in text):
                controls.append(name)
            if any(line.rstrip(' \t') != line for line in text.splitlines()):
                whitespace.append(name)
        text = re.sub(r'```.*?```', '', text, flags=re.S)
        for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)', text):
            target = target.strip('<>').split('#')[0]
            if not target or re.match(r'[a-zA-Z][a-zA-Z0-9+.-]*:', target):
                continue
            checked += 1
            destination = path.parent / unquote(target)
            if not destination.exists():
                row = {'document': name, 'target': target}
                broken.append(row)
                if name in new_documents:
                    new_broken.append(row)

    syntax = []
    for path in OUT.glob('*.py'):
        text = path.read_text(encoding='utf-8')
        ast.parse(text, filename=str(path))
        compile(text, str(path), 'exec')
        syntax.append(path.name)
    jsons = []
    for path in OUT.glob('*.json'):
        json.loads(path.read_text(encoding='utf-8-sig'))
        jsons.append(path.name)

    diff = subprocess.run(['git', 'diff', '--check'], cwd=ROOT, capture_output=True, text=True)
    staged = subprocess.check_output(['git', 'diff', '--cached', '--name-status'], cwd=ROOT, encoding='utf-8')
    head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, encoding='utf-8').strip()
    status = subprocess.check_output(['git', 'status', '--porcelain=v1', '-uall'], cwd=ROOT, encoding='utf-8')
    tracked_before = [s for s in baseline['git_status'].splitlines() if not s.startswith('?? ')]
    tracked_after = [s for s in status.splitlines() if not s.startswith('?? ')]
    tracked_changes_preserved = (tracked_before == [s for s in tracked_after if s != ' M docs/REFERENCE_INDEX.md']
                                and ' M docs/REFERENCE_INDEX.md' in tracked_after)
    proposal = OUT / 'APPROVAL_FILES.csv'
    findings = {
        'head_unchanged': head == baseline['head'], 'staged_empty': not staged,
        'original_tracked_changes_preserved': tracked_changes_preserved,
        'source_hash_checks': len(hashes),
        'only_authorized_document_changes': set(changed) == {'docs/README.md', 'docs/REFERENCE_INDEX.md'},
        'index_additions_preserve_original': index_additions_only,
        'reference_index_only_repaired_prefixes': reference_prefix_only,
        'all_missing_reused_inventory_paths': missing, 'unexpected_missing': sorted(set(missing) - expected_missing),
        'lost_original_untracked': lost_untracked, 'protected_metadata_deltas': protected_deltas,
        'python_syntax': syntax, 'json_parse': jsons,
        'local_markdown_targets_checked': checked, 'new_broken_references': new_broken,
        'historical_unresolved_link_candidates': broken,
        'link_limits': 'Inline Markdown target-existence check; fenced examples excluded. '
                       'Historical relative-path style may produce parser false positives; candidates retained, not rewritten. '
                       'Remote links, HTML and every anchor not validated.',
        'new_control_characters': controls, 'new_trailing_whitespace': whitespace,
        'git_diff_check_exit': diff.returncode,
        'approval_csv_sha256': digest(proposal),
        'final_git_status': status, 'status_counts': dict(collections.Counter(s[:2] for s in status.splitlines())),
        'D_free_bytes_at_validation': shutil.disk_usage(ROOT).free,
        'report_logical_bytes_at_validation': sum(p.stat().st_size for p in OUT.iterdir() if p.is_file()),
        'tests_not_run': 'Flutter/native/device builds and tests: no product/test/runtime file changed; '
                         'running flutter test would unnecessarily recreate the caches just removed.',
        'failed_or_limited_attempts': ['Sandbox CIM process lookup denied; successful read-only escalation confirmed IDE roles.',
             'PowerShell JSON array wrapper was normalized in the task-owned removal report; exact deletions unaffected.',
             'Task-owned decision table refinement initially refused existing output; corrected exact report paths only.'],
    }
    failure = (not findings['head_unchanged'] or staged or not tracked_changes_preserved
               or not findings['only_authorized_document_changes'] or not index_additions_only or not reference_prefix_only
               or set(missing) != expected_missing or lost_untracked or protected_deltas
               or new_broken or controls or whitespace or diff.returncode)
    findings['preservation_verdict'] = 'FAIL' if failure else 'PASS'
    with (OUT / 'VALIDATION.json').open('w' if args.refresh else 'x', encoding='utf-8') as stream:
        json.dump(findings, stream, ensure_ascii=False, indent=2)
        stream.write('\n')
    print(json.dumps({k: v for k, v in findings.items() if k not in {
        'final_git_status', 'historical_unresolved_link_candidates', 'json_parse', 'failed_or_limited_attempts'}}))
    print('Historical unresolved link candidates:', len(broken))
    raise SystemExit(1 if failure else 0)


if __name__ == '__main__':
    main()
