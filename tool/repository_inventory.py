"""Read-only repository inventory; writes one new JSON report, never deletes files.

Does not follow junctions/symlinks or hash large build/AVD images. Use an output
outside protected data. Existing reports are never overwritten.
"""

import argparse
import collections
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess


def git(root, *args):
    return subprocess.check_output(
        ['git', '-C', str(root), *args], encoding='utf-8'
    )


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def inventory(root):
    """Collect metadata once; hashes cover source, tools, assets and evidence."""
    groups = collections.defaultdict(lambda: {'files': 0, 'bytes': 0})
    files, errors, links = [], [], []
    hash_roots = {'lib', 'android', 'assets', 'docs', 'image', 'test',
                  'integration_test', 'test_driver', 'tool', '.github'}
    stack = [root]
    while stack:
        directory = stack.pop()
        try:
            with os.scandir(directory) as entries:
                for entry in entries:
                    path = Path(entry.path)
                    relative = path.relative_to(root).as_posix()
                    stat = entry.stat(follow_symlinks=False)
                    if entry.is_symlink() or getattr(stat, 'st_file_attributes', 0) & 1024:
                        links.append(relative)
                        continue
                    if entry.is_dir(follow_symlinks=False):
                        stack.append(path)
                        continue
                    parts = relative.split('/')
                    keys = [parts[0] if len(parts) > 1 else '(root files)']
                    if len(parts) > 2:
                        keys.append('/'.join(parts[:2]))
                    if len(parts) > 3 and parts[0] == 'build':
                        keys.append('/'.join(parts[:3]))
                    for key in keys:
                        groups[key]['files'] += 1
                        groups[key]['bytes'] += stat.st_size
                    row = {'path': relative, 'bytes': stat.st_size,
                           'mtime_ns': stat.st_mtime_ns}
                    generated = any(p in {'.gradle', '.cxx', '.kotlin', '__pycache__',
                                         'generated'} for p in parts)
                    if (len(parts) == 1 or parts[0] in hash_roots) and not generated:
                        row['sha256'] = sha256(path)
                    files.append(row)
        except OSError as error:
            errors.append({'directory': str(directory), 'error': str(error)})
    status = git(root, 'status', '--porcelain=v1', '-uall')
    disk = shutil.disk_usage(root)
    return {
        'captured_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'root': str(root), 'head': git(root, 'rev-parse', 'HEAD').strip(),
        'branch': git(root, 'branch', '--show-current').strip(),
        'upstream': git(root, 'rev-parse', '--abbrev-ref', '@{upstream}').strip(),
        'status_porcelain': status,
        'status_counts': dict(collections.Counter(line[:2] for line in status.splitlines())),
        'tracked': git(root, 'ls-files', '-z').split('\0')[:-1],
        'ignored': git(root, 'ls-files', '--others', '--ignored',
                       '--exclude-standard', '-z').split('\0')[:-1],
        'staged_diff': git(root, 'diff', '--cached', '--name-status'),
        'groups': dict(sorted(groups.items())), 'files': files,
        'logical_bytes': sum(row['bytes'] for row in files),
        'disk': {'total': disk.total, 'used': disk.used, 'free': disk.free},
        'links_not_followed': links, 'errors': errors,
        'limits': 'Logical sizes, not allocated clusters. Build/AVD contents not hashed. '
                  'No external SDK/cache/AVD directories inspected. Metadata is not a backup.',
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error('Output already exists; choose a new report path')
    data = inventory(args.root.resolve())
    with args.output.open('x', encoding='utf-8') as stream:
        json.dump(data, stream, indent=2, ensure_ascii=False)
        stream.write('\n')
    print(json.dumps({k: data[k] for k in ['head', 'branch', 'upstream',
                     'status_counts', 'logical_bytes', 'disk', 'errors']}))
    print(f'Files: {len(data["files"])}; report: {args.output}')


if __name__ == '__main__':
    main()
