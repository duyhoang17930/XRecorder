"""Normal system consent + bounded observation of newly requested task screenshots."""
import argparse
import json
import re
import subprocess
import time
import xml.etree.ElementTree as ET

import device_qa as q

parser = argparse.ArgumentParser()
parser.add_argument('--delay', type=int, choices=[1, 3, 5, 10], required=True)
parser.add_argument('--attempt', required=True)
parser.add_argument('--cancel-countdown', action='store_true')
parser.add_argument('--cancel-in-app', action='store_true')
args = parser.parse_args()
assert re.fullmatch('[a-z0-9_]+', args.attempt)
q.identity()


def journal():
    raw = q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', 'shared_prefs/capture_journal.xml')
    return raw, json.loads(ET.fromstring(raw).find("string[@name='session']").text)


def preferences():
    raw = q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', 'shared_prefs/app_settings.xml')
    return json.loads(ET.fromstring(raw).find("string[@name='document']").text)['values']


def box(node):
    return list(map(int, re.findall(r'-?\d+', node.get('bounds'))))


before = preferences()
assert journal()[1]['state'] in ['idle', 'completed', 'failed']
q.adb('shell', 'am', 'start', '-n', q.PACKAGE + '/.MainActivity')
q.click('Create'); q.click('Recording settings')
q.adb('shell', 'input', 'swipe', '550', '1880', '550', '400', '500')
_, nodes = q.tree()
heading = next(n for n in nodes if n.get('content-desc') == 'Screenshot delay')
option = next(n for n in nodes if n.get('content-desc') == str(args.delay) + 's'
              and n.get('clickable') == 'true' and box(n)[1] >= box(heading)[3])
x, y, right, bottom = box(option)
q.tap((x + right) // 2, (y + bottom) // 2)
after = preferences()
assert after['screenshotDelay'] == str(args.delay) + 's'
assert {k: v for k, v in before.items() if k != 'screenshotDelay'} == {k: v for k, v in after.items() if k != 'screenshotDelay'}
q.adb('shell', 'input', 'keyevent', '4'); q.click('Screenshot')
_, state = journal(); session = state['id']
_, nodes = q.tree()
confirm = next(n for n in nodes if n.get('text') == 'Share screen')
x, y, right, bottom = box(confirm)
start = time.monotonic()
q.adb('shell', 'input', 'tap', str((x + right) // 2), str((y + bottom) // 2))
samples = []
if args.cancel_countdown:
    assert args.delay == 10
    for _ in range(10):
        _, current = journal()
        if current['state'] == 'countdown': break
        time.sleep(.1)
    assert current['state'] == 'countdown'
    # The projection consent/minimize transition closes system dialogs; let it
    # finish before opening the shade so Android does not collapse it again.
    time.sleep(1.2)
    if args.cancel_in_app:
        q.adb('shell', 'am', 'start', '-n', q.PACKAGE + '/.MainActivity')
    else:
        q.adb('shell', 'cmd', 'statusbar', 'expand-notifications')
    time.sleep(.7)
    # UIAutomator waits for idle; an updating countdown can consume the whole10s.
    # Use the visible action's text pixels on this verified1080x2400 Pixel_7 instead.
    png = q.adb('exec-out', 'screencap', '-p')
    with (q.ROOT / (args.attempt + '_visible.png')).open('xb') as f: f.write(png)
    width, height, origin_x, origin_y = (180, 150, 850, 1980) if args.cancel_in_app else (200, 190, 230, 850)
    rgb = subprocess.check_output(['build/task03/ffmpeg/ffmpeg.exe', '-v', 'error', '-i', 'pipe:0',
        '-vf', f'crop={width}:{height}:{origin_x}:{origin_y}', '-frames:v', '1', '-pix_fmt', 'rgb24', '-f', 'rawvideo', '-'], input=png)
    pixels = [(i // 3 % width, i // 3 // width) for i in range(0, len(rgb), 3)
              if (140 < rgb[i] < 200 and 35 < rgb[i+1] < 100 and rgb[i+2] < 60) if args.cancel_in_app] if args.cancel_in_app else [
              (i // 3 % width, i // 3 // width) for i in range(0, len(rgb), 3)
              if 65 < rgb[i] < 115 and 75 < rgb[i+1] < 130 and rgb[i+2] - rgb[i] > 40]
    assert len(pixels) > 30, 'No visible notification action; evidence retained, no guessed tap'
    left, right = min(x for x, _ in pixels), max(x for x, _ in pixels)
    top, bottom = min(y for _, y in pixels), max(y for _, y in pixels)
    assert bottom - top < 65
    q.tap(origin_x + (left + right) // 2, origin_y + (top + bottom) // 2)
    q.adb('shell', 'cmd', 'statusbar', 'collapse')
for _ in range(60):
    raw, state = journal()
    assert state['id'] == session
    samples.append({'seconds': time.monotonic() - start, 'state': state['state'], 'remaining': state['countdownRemaining']})
    if state['state'] in ['completed', 'failed', 'idle']: break
    time.sleep(.2)
if args.cancel_countdown:
    assert state['state'] == 'idle' and not state.get('outputUri'), state
else:
    assert state['state'] == 'completed' and state['config']['countdown'] == args.delay, state
    assert samples[-1]['seconds'] >= args.delay - .5
    with (q.ROOT / (args.attempt + '.png')).open('xb') as f:
        f.write(q.adb('exec-out', 'content', 'read', '--uri', state['outputUri']))
    registry = q.ROOT / 'task_created_media.json'
    entries = json.loads(registry.read_text())
    entries.append({'uri': state['outputUri'], 'source': f'configured{args.delay}s screenshot', 'evidence': args.attempt + '_timeline.json'})
    registry.write_text(json.dumps(entries, indent=2))
with (q.ROOT / (args.attempt + '_journal.xml')).open('xb') as f: f.write(raw)
with (q.ROOT / (args.attempt + '_timeline.json')).open('x') as f:
    json.dump({'status': 'PASS', 'requestedDelay': args.delay, 'cancelled': args.cancel_countdown,
               'session': state, 'samples': samples, 'otherPreferencesUnchanged': True}, f, indent=2)
print(json.dumps({'status': 'PASS', 'delay': args.delay, 'state': state['state'], 'uri': state.get('outputUri'), 'seconds': samples[-1]['seconds']}))
