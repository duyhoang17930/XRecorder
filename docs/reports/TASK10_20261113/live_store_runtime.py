"""Bounded install and actual Keystore QA, preserving original drafts/models/state.

Reuse device_qa; only new TASK10 store fixtures are written. No data clearing.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import shutil
import tarfile
import xml.etree.ElementTree as ET

import device_qa as q

parser = argparse.ArgumentParser()
parser.add_argument('--attempt', required=True)
args = parser.parse_args()
assert re.fullmatch('[a-z0-9_]+', args.attempt)
stem = 'live_store_' + args.attempt

q.identity()
assert shutil.disk_usage('D:/').free > 10 * 1024**3
assert shutil.disk_usage('C:/').free > 10 * 1024**3
assert '.recording.CaptureService' not in q.adb('shell', 'dumpsys', 'activity', 'services', q.PACKAGE).decode()
assert q.adb('shell', 'run-as', q.PACKAGE, 'sh', '-c',
             "'test ! -e no_backup/live_destination_v1.enc && echo absent'").strip() == b'absent', 'Existing destination must be preserved; inspect instead'


def metadata():
    return q.adb('exec-out', 'run-as', q.PACKAGE, 'tar', '--exclude=no_backup/speech_models',
                 '-cf', '-', 'shared_prefs', 'files/projects', 'files/export_jobs.json',
                 'files/media_transfer.json', 'no_backup')


def files(archive):
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        return {m.name: tar.extractfile(m).read() for m in tar.getmembers() if m.isfile()}


before = metadata()
with (q.ROOT / (stem + '_before_install.tar')).open('xb') as out:
    out.write(before)
original = files((q.ROOT / 'private_state_before_install.tar').read_bytes())
current = files(before)
original_drafts = {p: b for p, b in original.items() if p.startswith('files/projects/')}
assert len(original_drafts) == 8
assert all(current.get(p) == b for p, b in original_drafts.items())
config = Path(r'C:\Users\dangh\.android\avd\Pixel_7.avd\config.ini')
config_evidence = (q.ROOT / 'asr_avd_config_before_ram.json').read_bytes()
config_record = json.loads(config_evidence.decode('utf-16' if config_evidence.startswith(b'\xff\xfe') else 'utf-8-sig'))
assert hashlib.sha256(config.read_bytes()).hexdigest().upper() == config_record['Hash']
model = 'no_backup/speech_models/ggml-tiny.bin'
model_sha = q.adb('exec-out', 'run-as', q.PACKAGE, 'sha256sum', model).split()[0].decode()
assert model_sha == 'be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21'
apks = []
for path in [Path('build/app/outputs/flutter-apk/app-profile.apk'),
             Path('build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk')]:
    apks.append({'path': str(path), 'bytes': path.stat().st_size,
                 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    print(q.adb('install', '-r', str(path), timeout=90).decode(), flush=True)
    assert shutil.disk_usage('D:/').free > 10 * 1024**3
after = files(metadata())
assert all(after.get(p) == b for p, b in current.items()), 'Install changed saved metadata'
log = q.adb('shell', 'am', 'instrument', '-w', '-e', 'task10', 'live-store',
            '-e', 'attempt', args.attempt,
            'com.xrecorder.xrecorder.test/com.xrecorder.xrecorder.qa.Task07AccessibilityInstrumentation', timeout=60)
with (q.ROOT / (stem + '_keystore_runtime.txt')).open('xb') as out:
    out.write(log)
match = re.search(rb'TASK10_LIVE_RESULT:(\{[^\r\n]+\})', log)
assert match, log.decode(errors='replace')
result = json.loads(match.group(1))
with (q.ROOT / (stem + '_keystore_result.json')).open('x') as out:
    json.dump(result, out, indent=2)
print(json.dumps(result), flush=True)
assert result['status'] == 'PASS', result
q.adb('shell', 'am', 'force-stop', q.PACKAGE)
after = files(metadata())
assert all(after.get(p) == b for p, b in current.items())
assert model_sha == q.adb('exec-out', 'run-as', q.PACKAGE, 'sha256sum', model).split()[0].decode()
summary = {'status': 'PASS', 'originalDraftsByteExact': 8, 'allBeforeInstallMetadataByteExact': True,
           'tinyModelSha256Unchanged': model_sha, 'avdConfigByteExact': True, 'apks': apks,
           'diskFreeBytes': {p: shutil.disk_usage(p).free for p in ['C:/', 'D:/']}}
with (q.ROOT / (stem + '_install_preservation.json')).open('x') as out:
    json.dump(summary, out, indent=2)
print(json.dumps(summary), flush=True)
