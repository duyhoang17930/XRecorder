"""Control the microphone contribution before comparing capture to source115.

Uncontrolled Mixed sums a second, unknown microphone signal: its correlation
alone cannot establish playback-capture fidelity. Keep prior failed evidence.
Set mic gain0 through real UI, preserve internal100%, restore prefs in finally.
"""
import argparse
import json
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
import device_qa as q

q.identity()
parser = argparse.ArgumentParser()
parser.add_argument('--attempt', default='audio9')
parser.add_argument('--player', choices=['video', 'static'], default='video')
parser.add_argument('--deny-first-consent', action='store_true')
args = parser.parse_args()
assert re.fullmatch('[a-z0-9_]+', args.attempt)
stem = 'live_audio_' + args.attempt
original = (q.ROOT / 'mixed_zero_mic_settings_before.xml').read_bytes()


def preferences():
    return q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', 'shared_prefs/app_settings.xml')


def values(raw):
    return json.loads(ET.fromstring(raw).find("string[@name='document']").text)['values']


def microphone(value):
    _, nodes = q.tree()
    parent = next(n for n in nodes if n.get('content-desc') == 'Microphone volume')
    x1, y1, x2, y2 = map(int, re.findall(r'\d+', parent.get('bounds')))
    q.tap(x1 + 2 if value == 0 else (x1+x2)//2, (y1+y2)//2)
    assert values(preferences())['gain'] == value


assert preferences() == original, 'Preferences changed since fixture setup; preserve current work'
assert values(original)['gain'] == 100 and values(original)['internalGain'] == 100
changed = False
process = None
try:
    changed = True  # Also restore if a post-tap assertion fails.
    microphone(0)
    adjusted = preferences()
    expected = values(original).copy(); expected['gain'] = 0
    assert values(adjusted) == expected
    active_path = q.ROOT / 'mixed_zero_mic_settings_active.xml'
    if active_path.exists():
        assert active_path.read_bytes() == adjusted  # Reuse identical fixture state.
    else:
        with active_path.open('xb') as out:
            out.write(adjusted)
    if not (q.ROOT / 'mixed_zero_mic_active_ui.xml').exists():
        q.save('mixed_zero_mic_active_ui')
    q.click('Back')
    with (q.ROOT / (stem + '_host.txt')).open('xb') as log:
        process = subprocess.run([sys.executable, str(q.ROOT / 'live_capture_audio_gate.py'),
            '--attempt', args.attempt, '--player', args.player] +
            (['--deny-first-consent'] if args.deny_first_consent else []),
            stdout=log, stderr=subprocess.STDOUT, timeout=240)
finally:
    if changed:
        assert '.recording.CaptureService' not in q.adb('shell', 'dumpsys', 'activity', 'services', q.PACKAGE).decode(), 'Own session still active; inspect before restarting'
        q.adb('shell', 'am', 'force-stop', q.PACKAGE)
        q.adb('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP')
        q.adb('shell', 'am', 'start', '-W', '-n', q.PACKAGE + '/.MainActivity', timeout=60)
        # Android launch completion precedes Flutter's first actionable frame.
        # Wait for the real control; never tap a stale/empty hierarchy.
        deadline = time.monotonic() + 30
        while 'Settings' not in q.labels(q.tree()[1]):
            if time.monotonic() >= deadline:
                raise RuntimeError('Main Flutter controls not ready for preference restoration')
            time.sleep(.5)
        q.click('Settings'); q.click('Recording settings')
        q.adb('shell', 'input', 'swipe', '550', '1800', '550', '850', '400')
        microphone(100)
        restored = preferences()
        restored_path = q.ROOT / 'mixed_zero_mic_settings_restored.xml'
        if restored_path.exists():
            assert restored_path.read_bytes() == restored
        else:
            with restored_path.open('xb') as out:
                out.write(restored)
        assert values(restored) == values(original)
        assert restored == original
        q.click('Back')
        result = {'preferencesByteExact': True, 'microphoneGainDuringTest': 0,
                  'internalGainDuringTest': 100, 'restoredMicrophoneGain': 100,
                  'nativeRunnerExit': process.returncode if process else None,
                  'scope': 'Controlled Mixed contribution; waveform validation is separate'}
        report_path = stem + ('_controlled_settings_verified.json' if process else '_controlled_settings.json')
        with (q.ROOT / report_path).open('x') as out:
            json.dump(result, out, indent=2)
        print(json.dumps(result), flush=True)
assert process is not None and process.returncode == 0
