"""Bounded profile upgrade and three process-cold/three warm Android launches.

No cache/data clearing. Android launch timing is not Flutter frame-time or
physical-device performance certification. Existing task fixtures remain.
"""
import hashlib
import argparse
import io
import json
from pathlib import Path
import re
import shutil
import statistics
import tarfile
import time

import device_qa as q

parser = argparse.ArgumentParser()
parser.add_argument('--attempt', default='profile_startup_gate')
parser.add_argument('--skip-install', action='store_true')
options = parser.parse_args()
assert re.fullmatch('[a-z0-9_]+', options.attempt)
stem = options.attempt
q.identity()
assert '.recording.CaptureService' not in q.adb('shell', 'dumpsys', 'activity', 'services', q.PACKAGE).decode()
jobs = json.loads(q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', 'files/export_jobs.json'))
assert all(j['state'] not in ['queued', 'running'] for j in jobs)
# Bounded six-launch observation, no stress/cache clearing/downloads. D keeps
# the owner's10GiB reserve; C keeps5GiB as in the existing short ADB gates.
assert shutil.disk_usage('D:/').free > 10 * 1024**3 and shutil.disk_usage('C:/').free > 5 * 1024**3


def files(raw):
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        return {m.name: archive.extractfile(m).read() for m in archive.getmembers() if m.isfile()}


args = ['exec-out', 'run-as', q.PACKAGE, 'tar', '--exclude=no_backup/speech_models', '-cf', '-',
        'shared_prefs', 'files/projects', 'files/export_jobs.json', 'files/media_transfer.json', 'no_backup']
before = files(q.adb(*args))
apk = Path('build/app/outputs/flutter-apk/app-profile.apk')
if not options.skip_install:
    q.install_main_profile_checkpoint(stem, 'Bounded profile startup measurement')
installed = q.adb('shell', 'pm', 'path', q.PACKAGE).decode().strip()
assert installed.startswith('package:') and '\n' not in installed
installed_sha = q.adb('shell', 'sha256sum', installed[len('package:'):]).split()[0].decode()
assert installed_sha == hashlib.sha256(apk.read_bytes()).hexdigest()
assert before == files(q.adb(*args))
original = files((q.ROOT / 'private_state_before_install.tar').read_bytes())
drafts = {p: b for p, b in original.items() if p.startswith('files/projects/')}
assert len(drafts) == 8 and all(before.get(p) == b for p, b in drafts.items())
identity = {'status': 'PASS', 'apkSha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
            'apkBytes': apk.stat().st_size, 'avd': q.identity(), 'serial': q.ADB[-1],
            'metadataFilesByteExact': len(before), 'originalDraftsByteExact': 8,
            'scope': 'Installed main.dart profile identity verified; no data/cache clear'}
results = []
for kind in ['process_cold', 'warm_resume']:
    for index in range(3):
        q.adb('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP')
        power = q.adb('shell', 'dumpsys', 'power').decode()
        assert 'mWakefulness=Awake' in power, 'Startup observation requires an awake device'
        policy = q.adb('shell', 'dumpsys', 'window', 'policy').decode()
        assert 'showing=true' not in policy, 'Use the normal unlock flow before measuring startup'
        if kind == 'process_cold':
            q.adb('shell', 'am', 'force-stop', q.PACKAGE)
        else:
            previous = q.adb('shell', 'pidof', q.PACKAGE).strip()
            q.adb('shell', 'input', 'keyevent', '3')
            time.sleep(.5)
        # Preserve the original30s timeout as evidence. Let this observation
        # return Android's actual duration even if startup is slow; a larger
        # command timeout is not a performance acceptance threshold.
        raw = q.adb('shell', 'am', 'start', '-W', '-n', q.PACKAGE + '/.MainActivity', timeout=60).decode()
        if kind == 'warm_resume':
            assert q.adb('shell', 'pidof', q.PACKAGE).strip() == previous
        values = {k: int(v) for k, v in re.findall(r'^(TotalTime|WaitTime|ThisTime):\s*(\d+)', raw, re.M)}
        results.append({'kind': kind, 'index': index + 1, 'timesMs': values, 'raw': raw})
        time.sleep(2)
        print(json.dumps(results[-1]), flush=True)
memory = q.adb('shell', 'dumpsys', 'meminfo', q.PACKAGE)
with (q.ROOT / (stem + '_meminfo.txt')).open('xb') as out:
    out.write(memory)
text = memory.decode()
mem = {key: int(value) for key, value in re.findall(r'(TOTAL PSS|TOTAL RSS|TOTAL SWAP PSS):\s+(\d+)', text)}
q.save(stem + '_final_root')
assert 'Video Library' in q.labels(q.tree()[1])
assert before == files(q.adb(*args)), 'Bounded saved metadata changed during startup observation'
summary = {'status': 'PASS', 'apk': identity, 'launches': results, 'memoryKiB': mem,
           'deviceAwakeAndKeyguardAbsent': True,
           'medianTotalTimeMs': {kind: statistics.median([x['timesMs']['TotalTime'] for x in results
               if x['kind'] == kind and 'TotalTime' in x['timesMs']])
               for kind in ['process_cold', 'warm_resume'] if any(x['kind'] == kind and 'TotalTime' in x['timesMs'] for x in results)},
           'diskFreeBytes': {p: shutil.disk_usage(p).free for p in ['C:/', 'D:/']},
           'limitations': 'Pixel_7 AVD runtime3GiB; cached OS and task-enriched library. Android am start timing only; no Flutter frame, thermal, battery, leak or physical-device acceptance.'}
with (q.ROOT / (stem + '_result.json')).open('x') as out:
    json.dump(summary, out, indent=2)
print(json.dumps(summary), flush=True)
