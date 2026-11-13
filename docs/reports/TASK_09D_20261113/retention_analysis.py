"""TASK09D retention decisions using TASK09C path lists; no deletion or tree walk."""

import collections
import csv
import ctypes
from ctypes import wintypes
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
PREVIOUS = ROOT / 'docs/reports/TASK_09C_20261113'

CANONICAL = {
    'docs/README.md', 'docs/APP_SPEC_VI.md', 'docs/TECH_STACK_RESEARCH_VI.md',
    'docs/REFERENCE_INDEX.md', 'docs/3HRecorder_TASK_03_1_UX_GUIDELINES.md',
    'docs/implementation/P2_P3_CONTRACTS.md', 'docs/implementation/REUSE_REGISTER.md',
    'docs/p1/TASK_00_OWNERSHIP_AND_CONTRACT.md',
    'docs/TASK_09B_FULL_COVERAGE_COMPLETION_PROMPT.md',
    'build/uiux02/workspace/build/app/outputs/flutter-apk/app-debug.apk',
    'docs/implementation/TASK_07_ASR_CONTRACT_AND_BENCHMARK.md',
    'docs/implementation/TASK_07_GLOBALIZATION_MATRIX.md',
    'docs/implementation/TASK_09B_BUG_REGISTER.md',
    'docs/implementation/TASK_09B_P1_HANDOFF_UPDATE.md',
    'docs/implementation/TASK_09B_FINAL_REPORT_VI.md',
    'docs/implementation/TASK_09B_TEST_EVIDENCE.md',
    'docs/implementation/TASK_09B_SCENARIO_MATRIX.md',
    'docs/implementation/TASK_09B_INTERACTION_COVERAGE.csv',
    'docs/implementation/TASK_09_P1_HANDOFF.md',
    'docs/TASK_09B_ACCEPTANCE_CHECKLIST.md', 'docs/TASK_09_FULL_APP_QA_MATRIX.md',
    'docs/implementation/TASK_08_DATA_RECOVERY_FINAL_STATUS.md',
    'docs/implementation/TASK_08_DATA_SAFETY_REPORT.md',
    'docs/implementation/TASK_08_DATA_RECOVERY_FINAL_STATUS.md',
    'docs/implementation/POST_PULL_TEAM_INTEGRATION_AUDIT.md',
    'docs/ui/README.md', 'docs/ui/DESIGN_SYSTEM.md', 'docs/ui/UX_REPORT_VI.md',
    'docs/ui/USABILITY_TEST_VI.md', 'docs/performance/README.md',
    'docs/xrecorder/PRIVACY.md', 'docs/xrecorder/phase_13_validation.md',
}

CURRENT_UI = 'docs/reports/TASK_UI_UX_06_20261111_172021_ffa4c9/'
CANONICAL.update({CURRENT_UI + name for name in {
    'TASK_UI_UX_06_EDITOR_REDESIGN_REPORT_v2.md', 'P1_UI06_HANDOFF.md',
    'P1_AUTOSTOP_SPACING_PROPOSED.patch', 'capture_journal_runtime_comparison.json',
    'data_preservation_final_v2.json', 'qa06.py', 'profile06_runner.py',
    'profile06_editors.py', 'review_video_keyframes.py', 'verify_export_visual_content.py',
}})
CANONICAL.update({
    'docs/reports/TASK_UI_UX_05B_20261111_113152_839655/qa05b.py',
    'docs/reports/TASK_UI_UX_05B_20261111_113152_839655/P1_UI05B_HANDOFF.md',
})


def write_json(name, value):
    with (OUT / name).open('x', encoding='utf-8') as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write('\n')


def main():
    previous = json.loads((PREVIOUS / 'after_inventory.json').read_text(encoding='utf-8'))
    baseline = json.loads((OUT / 'BASELINE.json').read_text(encoding='utf-8'))
    files = {row['path']: row for row in previous['files']}
    # Include current Git-listed documents written after the older snapshot.
    for line in baseline['git_status'].splitlines():
        path = line[3:]
        if path.startswith('docs/') and path not in files and (ROOT / path).is_file():
            stat = (ROOT / path).stat()
            files[path] = {'path': path, 'bytes': stat.st_size, 'mtime_ns': stat.st_mtime_ns}
    tracked = set(previous['tracked'])
    dirty = {line[3:].strip('"') for line in baseline['git_status'].splitlines()
             if not line.startswith('?? ')}
    allocated = {r['path']: r for r in json.loads((OUT / 'ALLOCATED_STORAGE.json').read_text(encoding='utf-8'))}
    duplicate_groups = json.loads((PREVIOUS / 'HISTORICAL_DOCUMENT_ASSET_DUPLICATES.json').read_text(encoding='utf-8'))
    duplicates = {p: g['sha256'] for g in duplicate_groups for p in g['paths']}

    references = collections.defaultdict(set)
    active_references = collections.defaultdict(set)
    texts = {}
    reference_files = 0
    for path, row in files.items():
        if (Path(path).suffix not in {'.md', '.py', '.ps1', '.dart', '.yaml', '.kts', '.xml'}
                or row['bytes'] > 2_000_000 or path.startswith(('.git/', '.dart_tool/', '.claude-local/', 'build/research/'))):
            continue
        try:
            text = (ROOT / path).read_text(encoding='utf-8-sig')
        except (OSError, UnicodeError):
            continue
        reference_files += 1
        if path.startswith('docs/') and Path(path).suffix in {'.txt', '.log', '.md'}:
            texts[path] = text[:20000]
        tokens = set(re.findall(r'[A-Za-z0-9_][A-Za-z0-9_.-]*\.(?:md|py|json|png|jpg|jpeg|mp4|apk|csv|txt|log|svg|tar|html|yaml|dart)', text))
        tokens.update(m + '.py' for m in re.findall(r'\b(?:import|from)\s+([A-Za-z_][A-Za-z_0-9]*)', text))
        for token in tokens:
            references[token].add(path)
            if path.startswith(('lib/', 'test/', 'integration_test/', 'test_driver/', 'tool/', '.github/')):
                active_references[token].add(path)

    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
                                  ctypes.c_void_p, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
    kernel.CreateFileW.restype = wintypes.HANDLE
    kernel.GetFileInformationByHandleEx.argtypes = [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD]
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    class Info(ctypes.Structure):
        _fields_ = [('allocation', ctypes.c_longlong), ('length', ctypes.c_longlong),
                    ('links', wintypes.DWORD), ('pending', ctypes.c_ubyte), ('directory', ctypes.c_ubyte)]

    def allocation(path):
        if path in allocated:
            return allocated[path]['allocated_bytes']
        handle = kernel.CreateFileW(str(ROOT / path), 0x80, 7, None, 3, 0x00200000, None)
        if handle == ctypes.c_void_p(-1).value:
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            info = Info()
            if not kernel.GetFileInformationByHandleEx(handle, 1, ctypes.byref(info), ctypes.sizeof(info)):
                raise ctypes.WinError(ctypes.get_last_error())
            return info.allocation
        finally:
            kernel.CloseHandle(handle)

    target_duplicate = 'build/uiux02/workspace/build/app/outputs/apk/debug/app-debug.apk'
    historical_prefixes = ('docs/', 'build/verification/', 'build/task',
                           'build/uiux02/', 'build/final_api34_avd/')
    rows, counts, groups = [], collections.Counter(), collections.defaultdict(list)
    for path, row in sorted(files.items()):
        if not path.startswith(historical_prefixes):
            continue
        name, lower = Path(path).name, path.lower()
        suffix = Path(path).suffix.lower()
        refs = sorted(references[name] - {path})
        active = sorted(active_references[name] - {path})
        category, group, reason = 'C', '', 'Unique dated task/report evidence; retain historical facts'
        if path in CANONICAL or path.startswith('docs/reports/TASK_09C_20261113/'):
            category, reason = 'A', 'Canonical current guidance, open-gate proof or current maintenance baseline'
        elif suffix in {'.tar', '.zip', '.gguf', '.ggml'} or any(s in lower for s in [
                'build/task021_avd/', '/offline_checkpoint', '/incident', '/followup_',
                '/recovery', '/models/', 'ggml-tiny', 'ggml-base', 'ggml-small']):
            category, reason = 'H', 'Recovery lineage, private backup, model weights or incident material; no deletion proposal'
        elif ('.avd/' in path or path.endswith('.avd.ini')
              or path.startswith(('build/verification/task07/avds/', 'build/verification/task09/avds/', 'build/final_api34_avd/'))):
            category, reason = 'H', 'AVD state/backing-chain/grants may be unique; no automatic deletion'
            if path.startswith(('build/verification/task07/avds/', 'build/verification/task09/avds/', 'build/final_api34_avd/')):
                group = 'P06'
        elif suffix in {'.qcow2', '.img', '.vhd', '.vhdx'}:
            category, reason = 'H', 'Standalone disk/image lineage uncertain; retain locally'
        elif path == target_duplicate:
            category, group, reason = 'F', 'P01', 'Byte-identical historical APK twin already verified by TASK09C; fresh hash recheck required'
        elif '/licenses/' in lower or re.search(r'(?:^|/)(?:license|notice|ofl|copying)(?:[._/]|$)', lower):
            category, reason = 'A', 'License/attribution preserved; no license deletion'
        elif active:
            category, reason = 'B', 'Active source/test/tool name reference; retain until exact consumer review'
        elif suffix == '.apk' and 'compact_qa' not in lower:
            category, group, reason = 'C', 'P02', 'Older QA binary; archive with original hash/cert/build recipe, not needed for ordinary builds'
        elif suffix == '.apk':
            category, reason = 'B', 'Curated TASK09B QA APK/release-comparison artifact retained as current handoff'
        elif suffix in {'.mp4', '.wav', '.mp3', '.flac'} and not path.startswith('docs/'):
            category, reason = 'H', 'QA source/output media retention not decided; may serve drafts, recovery or exact output validation'
        elif path.startswith(('docs/ui/', 'docs/performance/')) and suffix in {'.png', '.jpg', '.jpeg'}:
            category, reason = 'A', 'Current curated documentation illustration'
        elif path.startswith('docs/p1/'):
            category, reason = 'C', 'P1-owned technical history; retain locally in this task, owner retention decision required'
        elif path.startswith(('docs/reports/TASK_UI_UX_', 'docs/implementation/TASK_UI_UX_')) and suffix in {'.png', '.jpg', '.jpeg', '.svg', '.mp4', '.html', '.xml'}:
            category, group, reason = 'C', 'P03', 'Older visual evidence; archive with reports and relative-path dependency closure'
        elif path.startswith('docs/') and path not in {'docs/README.md'}:
            category, group, reason = 'C', 'P04', 'Historical report/log/runner/planning material; archival cohort, not active application data'
            text = texts.get(path, '')
            if suffix in {'.txt', '.log'} and ('All tests passed' in text or 'No issues found' in text) and not re.search(r'Traceback|Some tests failed|\bFAIL\b|issue found', text):
                category, reason = 'G', 'Superseded successful tool output; no unique failure; approval still required'
            if name.endswith(('PROMPT.md', '_PLAN.md')):
                category, reason = 'G', 'Historical implementation instructions; current source/spec/contracts are canonical'
        elif path.startswith('build/verification/') and any(s in lower for s in ['/profile', '/performance', '/startup', '/g5_', '/memory/']) and suffix in {'.json', '.jsonl', '.log', '.txt', '.csv', '.py', '.png'}:
            category, group, reason = 'C', 'P05', 'Historical measured traces/counters; cannot regenerate identical observations; archive losslessly'
        if category == 'C' and not group and not path.startswith('docs/'):
            group, reason = 'P07', 'Historical QA logs, reproduction runners or old source/build snapshot; archive complete dependency cohort, retain unique FAIL facts'
        if path in duplicates and category not in {'A', 'B', 'H'}:
            category = 'F'
            reason += '; exact duplicate payload, separate provenance retained'
        tags = []
        if path in tracked and path not in dirty:
            tags.append('D recoverable from Git HEAD')
        if path in duplicates:
            tags.append('F exact duplicate')
        if category == 'G':
            tags.append('E regenerate function, not historical observations')
        exists = (ROOT / path).is_file()
        allocated_size = allocation(path) if exists and (group or row['bytes'] >= 1_000_000) else None
        item = {'path': path, 'category': category, 'secondary': '; '.join(tags),
                'logical_bytes': row['bytes'], 'allocated_bytes': allocated_size,
                'git_status': 'tracked clean' if path in tracked and path not in dirty else 'tracked dirty' if path in tracked else 'untracked' if path.startswith('docs/reports/TASK_UI_UX_05') or path.startswith(CURRENT_UI) or path.startswith('docs/reports/TASK_09C_') or path == 'docs/README.md' else 'ignored' if path.startswith('build/') else 'tracked/untracked: see Git baseline',
                'proposal': group, 'decision': 'pending separate approval; retain originals' if group else 'retain at original path',
                'reason': reason, 'referencing_documents_or_scripts': '; '.join(refs[:12]),
                'reference_count': len(refs), 'active_reference_count': len(active),
                'sha256': ('a18bdf68262e243818ef6906e0842ae5aa2f78f8127815ad80374866a6b0c3ce'
                           if path == target_duplicate else row.get('sha256', duplicates.get(path, '')))}
        rows.append(item)
        counts[category] += 1
        if group:
            groups[group].append(item)

    for name, items in [('RETENTION_DECISIONS.csv', rows), ('APPROVAL_FILES.csv', [r for r in rows if r['proposal']])]:
        with (OUT / name).open('x', encoding='utf-8', newline='') as stream:
            fields = (['path', 'proposal', 'logical_bytes', 'allocated_bytes', 'git_status',
                       'sha256', 'active_reference_count', 'referencing_documents_or_scripts']
                      if name == 'APPROVAL_FILES.csv' else list(rows[0]))
            writer = csv.DictWriter(stream, fieldnames=fields, extrasaction='ignore')
            writer.writeheader()
            writer.writerows(items)
    summary = {'historical_files_inspected': len(rows), 'categories': dict(counts),
               'reference_text_files': reference_files,
               'groups': {name: {'files': len(items), 'logical_bytes': sum(r['logical_bytes'] for r in items),
                                 'allocated_bytes': sum(r['allocated_bytes'] or 0 for r in items)}
                          for name, items in sorted(groups.items())},
               'limits': 'Reused TASK09C exact paths; no new full-tree traversal. Name references are conservative '
                         'retention evidence, not proof of dynamic reachability absence. Metadata-only allocation '
                         'reads; SHA values reused for known unchanged evidence. This classifier never performs '
                         'archive/move/delete; separate three-cache cleanup is recorded in FILES_REMOVED_MANIFEST.json.'}
    write_json('RETENTION_SUMMARY.json', summary)
    print(json.dumps(summary))


if __name__ == '__main__':
    main()
