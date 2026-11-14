"""Bounded real-main R6 acceptance; stop this task's capture even after a failed step."""
import hashlib
import argparse
import json
from pathlib import Path
import re
import time
import xml.etree.ElementTree as ET

import device_qa as q

parser = argparse.ArgumentParser()
parser.add_argument('--attempt', default='final')
parser.add_argument('--skip-install', action='store_true')
args = parser.parse_args()
assert re.fullmatch(r'[a-z0-9_]+', args.attempt)
prefix = 'r6_' + args.attempt

q.identity()


def journal():
    raw = q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', 'shared_prefs/capture_journal.xml')
    return raw, json.loads(ET.fromstring(raw).find("string[@name='session']").text)


def bounds(title):
    block = next(b for b in q.adb('shell', 'dumpsys', 'window', 'windows').decode().split('Window #') if title in b)
    return tuple(map(int, re.search(r'Frames:.*? frame=\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', block).groups()))


def save(name):
    # XML from the focused app excludes non-focusable overlay nodes. Keep actual PNGs.
    q.save(prefix + '_' + name)
    print(name, flush=True)


assert '.recording.CaptureService' not in q.adb('shell', 'dumpsys', 'activity', 'services', q.PACKAGE).decode()
old_id = journal()[1]['id']
backup = q.adb('exec-out', 'run-as', q.PACKAGE, 'tar', '--exclude=no_backup/speech_models', '-cf', '-', 'shared_prefs', 'files/projects',
               'files/export_jobs.json', 'files/capture_recovery', 'no_backup')
with (q.ROOT / (prefix + '_private_before.tar')).open('xb') as f:
    f.write(backup)
apk = Path('build/app/outputs/flutter-apk/app-profile.apk')
identity = {'path': str(apk), 'sha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
            'bytes': apk.stat().st_size, 'avd': q.identity(), 'serial': q.ADB[-1]}
if not args.skip_install:
    print(q.adb('install', '-r', str(apk), timeout=90).decode(), flush=True)
with (q.ROOT / (prefix + '_apk.json')).open('x') as f:
    json.dump(identity, f, indent=2)
report = {'apk': identity, 'actions': {}}
task_session = None
try:
    q.adb('shell', 'am', 'start', '-n', q.PACKAGE + '/.MainActivity')
    time.sleep(2)
    for label in ['Create', 'Record screen', 'Start Recording', 'Share screen']:
        q.click(label)
    task_session = journal()[1]['id']
    assert task_session != old_id
    for _ in range(40):
        state = journal()[1]
        if state['state'] in ['recording', 'failed']: break
        time.sleep(.25)
    assert state['state'] == 'recording', state
    q.adb('shell', 'cmd', 'statusbar', 'expand-notifications')
    q.click('Show controls in video')
    q.adb('shell', 'cmd', 'statusbar', 'collapse')
    q.adb('shell', 'input', 'keyevent', '3')
    time.sleep(.5)
    save('toolbar')
    x, y, right, _ = bounds('3HRecorder floating controls')
    q.tap(right - 200, y + 63)  # Draw/Exit, 48dp target at the current verified density.
    q.adb('shell', 'input', 'swipe', '220', '1050', '690', '1300', '600')
    save('stroke')
    q.tap(x + 63, y + 189)
    save('undo')
    q.adb('shell', 'input', 'swipe', '220', '1050', '690', '1300', '600')
    # Deliberately no wait for the old250ms timer: toolbar must update on stroke completion.
    q.tap(x + 189, y + 189)
    save('clear')
    q.adb('shell', 'input', 'swipe', '220', '1050', '690', '1300', '600')
    q.tap(right - 200, y + 63)
    save('pass_through')
    q.tap(945, 2020)  # The positively identified3HRecorder launcher icon, outside overlays.
    assert any('Video Library' in text for text in q.labels(q.tree()[1]))
    report['actions']['passThroughLaunch'] = True
    q.adb('shell', 'input', 'keyevent', '3')
    original = bounds('3HRecorder Facecam Overlay')
    x, y, right, _ = bounds('3HRecorder floating controls')
    q.tap(x + 63, y + 189); q.click('Small')
    small = bounds('3HRecorder Facecam Overlay')
    assert abs((small[2] - small[0]) - (original[2] - original[0]) * .75) < 3, (original, small)
    q.tap(x + 63, y + 189); q.click('Large')
    large = bounds('3HRecorder Facecam Overlay')
    assert abs((large[2] - large[0]) - (original[2] - original[0]) * 1.5) < 3, (original, large)
    save('large_camera')
    report['actions']['cameraBounds'] = {'original': original, 'small': small, 'large': large}
    q.tap(x + 63, y + 189); q.click('Switch camera')
    time.sleep(1)
    save('switched_camera')
    q.tap(right - 326, y + 63)
    raw, state = journal(); assert state['state'] == 'paused', state
    with (q.ROOT / (prefix + '_paused.xml')).open('xb') as f: f.write(raw)
    q.tap(right - 326, y + 63)
    raw, state = journal(); assert state['state'] == 'recording', state
    with (q.ROOT / (prefix + '_resumed.xml')).open('xb') as f: f.write(raw)
    report['actions']['pauseResume'] = True
    q.tap(right - 74, y + 63)
    report['actions']['floatingStop'] = True
finally:
    raw, state = journal()
    if task_session and state['id'] == task_session and state['state'] in ['recording', 'paused', 'countdown', 'starting']:
        q.adb('shell', 'cmd', 'statusbar', 'expand-notifications')
        q.click('Stop')
        q.adb('shell', 'cmd', 'statusbar', 'collapse')
    for _ in range(20):
        raw, state = journal()
        if state['state'] in ['completed', 'failed', 'idle']: break
        time.sleep(.5)
    with (q.ROOT / (prefix + '_journal.xml')).open('xb') as f: f.write(raw)
    report['session'] = state
    if state['id'] != old_id and state.get('outputUri'):
        p = q.ROOT / 'task_created_media.json'
        registry = json.loads(p.read_text())
        registry.append({'uri': state['outputUri'], 'source': 'R6 main acceptance ' + args.attempt, 'evidence': prefix + '_journal.xml'})
        p.write_text(json.dumps(registry, indent=2))
    with (q.ROOT / (prefix + '_actions.json')).open('x') as f: json.dump(report, f, indent=2)
assert state['state'] == 'completed', state
print(json.dumps({'state': state['state'], 'uri': state['outputUri'], 'actions': report['actions']}))
