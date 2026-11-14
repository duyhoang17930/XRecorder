"""Run the existing native instrumentation on bounded TASK10 fixtures only."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import tarfile

import device_qa as q

parser = argparse.ArgumentParser()
parser.add_argument('--install', action='store_true')
parser.add_argument('--install-test', action='store_true')
parser.add_argument('--suite', choices=['recovery', 'region'], default='recovery')
parser.add_argument('--attempt', required=True)
parser.add_argument('--cases', nargs='+', required=True)
args = parser.parse_args()
assert re.fullmatch(r'[a-z0-9_]+', args.attempt)
allowed = ({'region-red', 'region-green', 'region-blue', 'region-yellow', 'region-portrait'}
           if args.suite == 'region' else {
               'recording-audio-lead', 'recording-pending', 'recording-partial', 'recording-png',
               'recording-remux', 'recording-remux-retry', 'recording-bad-audio',
               'recording-wrong-session', 'recording-session-isolation', 'recording-published-retry'})
if not set(args.cases) <= allowed:
    parser.error('Unknown case for this suite: ' + ', '.join(sorted(set(args.cases) - allowed)))
q.identity()
assert '.recording.CaptureService' not in q.adb('shell', 'dumpsys', 'activity', 'services', q.PACKAGE).decode()
manifest = json.loads((q.ROOT / 'r5_fixtures_manifest.json').read_text())
prefix = 'r4' if args.suite == 'region' else 'r5'
commands = []
if args.install_test:
    path = Path('build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk')
    print(q.adb('install', '-r', str(path), timeout=90).decode(), flush=True)
    with (q.ROOT / ('r5_test_apk_' + args.attempt + '.json')).open('x') as output:
        json.dump({'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}, output)
for key, fixture in (manifest['fixtures'].items() if args.suite == 'recovery' else []):
    path = q.ROOT / fixture['path']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == fixture['sha256']
    remote = '/data/local/tmp/task10_r5_' + key + path.suffix
    if subprocess.run(q.ADB + ['shell', 'test', '-e', remote], capture_output=True).returncode == 0:
        assert q.adb('shell', 'sha256sum', remote).decode().split()[0] == fixture['sha256']
    else:
        q.adb('push', str(path), remote)
    commands += ['-e', key, remote, '-e', key + 'Sha', fixture['sha256']]
if args.install:
    services = q.adb('shell', 'dumpsys', 'activity', 'services', q.PACKAGE).decode()
    assert '.recording.CaptureService' not in services
    raw = q.adb('exec-out', 'run-as', q.PACKAGE, 'tar', '--exclude=no_backup/speech_models', '-cf', '-', 'shared_prefs', 'files/projects',
                'files/export_jobs.json', 'files/media_transfer.json', 'files/capture_recovery', 'no_backup')
    with (q.ROOT / (prefix + '_private_before_' + args.attempt + '.tar')).open('xb') as stream:
        stream.write(raw)
    identities = []
    for path in [Path('build/app/outputs/apk/debug/app-debug.apk'),
                 Path('build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk')]:
        identities.append({'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                           'bytes': path.stat().st_size})
        print(q.adb('install', '-r', str(path), timeout=90).decode(), flush=True)
    with (q.ROOT / (prefix + '_apk_' + args.attempt + '.json')).open('x') as stream:
        json.dump(identities, stream, indent=2)
for case in args.cases:
    assert re.fullmatch(r'(recording|region)-[a-z-]+', case)
    log = q.adb('shell', 'am', 'instrument', '-w', '-e', 'task10', case,
                '-e', 'durationUs', str(manifest['durationUs']), '-e', 'leadDurationUs', str(manifest.get('leadDurationUs', 0)), *commands,
                'com.xrecorder.xrecorder.test/com.xrecorder.xrecorder.qa.Task07AccessibilityInstrumentation', timeout=60)
    # Do not let the test process's isolated singletons survive a later main launch.
    q.adb('shell', 'am', 'force-stop', q.PACKAGE)
    stem = prefix + '_' + args.attempt + '_' + case.replace('-', '_')
    with (q.ROOT / (stem + '.txt')).open('xb') as stream:
        stream.write(log)
    match = re.search(rb'TASK10_(?:RECORDING|REGION)_RESULT:(\{[^\r\n]+\})', log)
    assert match, log.decode(errors='replace')
    result = json.loads(match.group(1))
    with (q.ROOT / (stem + '.json')).open('x', encoding='utf8') as stream:
        json.dump(result, stream, indent=2)
    print(json.dumps(result), flush=True)
    registry_path = q.ROOT / 'task_created_media.json'
    registry = json.loads(registry_path.read_text())
    for uri in result.get('fixturePendingUris', []):
        if not any(item['uri'] == uri for item in registry):
            registry.append({'uri': uri, 'case': case, 'sessionId': result['sessionId'],
                             'source': 'isolated native R5 fixture', 'evidence': stem + '.json'})
    if result.get('uri') and not any(item['uri'] == result['uri'] for item in registry):
        registry.append({'uri': result['uri'], 'case': case, 'sessionId': result.get('sessionId'),
                         'source': 'production ' + args.suite + ' output', 'evidence': stem + '.json'})
    registry_path.write_text(json.dumps(registry, indent=2))
    assert result['status'] == 'PASS', result
