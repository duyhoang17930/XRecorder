"""Real consent/capture plus task-owned speech playback to local RTMP receiver.

Reuse the existing native dispatcher and FFmpeg; no external account/server.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import socket
import subprocess
import xml.etree.ElementTree as ET

import device_qa as q

p = argparse.ArgumentParser()
p.add_argument('--attempt', required=True)
p.add_argument('--player', choices=['video', 'static'], default='video')
p.add_argument('--fail-after-playback', action='store_true')
p.add_argument('--pause-before-failure', action='store_true')
p.add_argument('--deny-first-consent', action='store_true')
args = p.parse_args()
assert not args.pause_before_failure or args.fail_after_playback
assert re.fullmatch('[a-z0-9_]+', args.attempt)
q.identity()
assert shutil.disk_usage('D:/').free > 10 * 1024**3
# C: hosts the running AVD; this bounded <90s capture writes only a few MB.
# D: retains the owner's strict10GiB reserve. No builds/downloads are run here.
assert shutil.disk_usage('C:/').free > 5 * 1024**3
assert '.recording.CaptureService' not in q.adb('shell', 'dumpsys', 'activity', 'services', q.PACKAGE).decode()
source = 'content://media/external/video/media/115'
registry = json.loads((q.ROOT / 'task_created_media.json').read_text())
assert any(x['uri'] == source for x in registry)
assert hashlib.sha256(q.adb('exec-out', 'content', 'read', '--uri', source)).hexdigest() == '8925ac2f0764e8bcdbcf1b70f5f28b373b4653f7a7aa0c8b163ebfa00001c34f'
preferences = q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', 'shared_prefs/app_settings.xml')
journal = q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', 'shared_prefs/capture_journal.xml')
previous_id = json.loads(ET.fromstring(journal).find("string[@name='session']").text)['id']
stem = 'live_audio_' + args.attempt
target = q.ROOT / (stem + '_media')
target.mkdir(exist_ok=False)
test = Path('build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk')
print(q.adb('install', '-r', str(test), timeout=60).decode(), flush=True)
with socket.socket() as port:
    port.bind(('127.0.0.1', 19350))
key = 'task10_capture_audio_' + args.attempt
receiver = None
try:
    with (q.ROOT / (stem + '_receiver.log')).open('xb') as log:
        receiver = subprocess.Popen(['build/task03/ffmpeg/ffmpeg.exe', '-hide_banner', '-nostdin', '-n',
            '-listen', '1', '-timeout', '120', '-i', 'rtmp://127.0.0.1:19350/live/' + key,
            '-t', '90', '-c', 'copy', '-movflags', '+faststart', str(target / 'received.mp4')],
            stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        q.adb('shell', 'am', 'force-stop', q.PACKAGE)
        raw = q.adb('shell', 'am', 'instrument', '-w', '-e', 'task10', 'live-capture-audio',
            '-e', 'source', source, '-e', 'attempt', args.attempt,
            '-e', 'player', args.player,
            '-e', 'failAfterPlayback', str(args.fail_after_playback).lower(),
            '-e', 'pauseBeforeFailure', str(args.pause_before_failure).lower(),
            '-e', 'denyFirstConsent', str(args.deny_first_consent).lower(),
            'com.xrecorder.xrecorder.test/com.xrecorder.xrecorder.qa.Task07AccessibilityInstrumentation', timeout=180)
        with (q.ROOT / (stem + '_runtime.txt')).open('xb') as out:
            out.write(raw)
        match = re.search(rb'TASK10_LIVE_RESULT:(\{[^\r\n]+\})', raw)
        assert match, raw.decode(errors='replace')
        result = json.loads(match.group(1))
        with (q.ROOT / (stem + '_result.json')).open('x') as out:
            json.dump(result, out, indent=2)
        print(json.dumps(result), flush=True)
        if result.get('sourcePcmBytes'):
            pcm = q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', 'files/task10_audio_' + args.attempt + '_source.pcm')
            assert len(pcm) == result['sourcePcmBytes'] and hashlib.sha256(pcm).hexdigest() == result['sourcePcmSha256']
            with (q.ROOT / (stem + '_source.pcm')).open('xb') as out:
                out.write(pcm)
        # Register any created output even if a later validation fails.
        capture = result.get('capture') or result.get('cleanupCapture') or result.get('captureAtFailure') or {}
        if args.fail_after_playback and capture.get('id') == result.get('sessionId') and capture.get('id') != previous_id:
            retained = q.retained_capture_inputs(capture['id'])
            with (q.ROOT / (stem + '_retained_inputs.json')).open('x') as out:
                json.dump(retained, out, indent=2)
        uri = capture.get('outputUri')
        if uri and capture.get('id') == result.get('sessionId') and capture.get('id') != previous_id:
            registry.append({'uri': uri, 'sessionId': capture['id'], 'case': 'live_capture_speech',
                             'source': 'real production capture + task115 playback', 'evidence': stem + '_result.json'})
            (q.ROOT / 'task_created_media.json').write_text(json.dumps(registry, indent=2))
            with (target / 'local.mp4').open('xb') as out:
                out.write(q.adb('exec-out', 'content', 'read', '--uri', uri))
        for kind in ['denied', 'consent', 'player', 'failure']:
            name = 'task10_audio_' + args.attempt + '_' + kind + '.png'
            if result.get(kind + 'Screenshot'):
                with (q.ROOT / (stem + '_' + kind + '.png')).open('xb') as out:
                    out.write(q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', 'files/' + name))
        assert result['status'] == 'PASS', result
        receiver.wait(timeout=20)
        assert (target / 'received.mp4').stat().st_size > 10000
        assert preferences == q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', 'shared_prefs/app_settings.xml')
        result['preferencesByteExact'] = True
        result['testApkSha256'] = hashlib.sha256(test.read_bytes()).hexdigest()
        with (q.ROOT / (stem + '_summary.json')).open('x') as out:
            json.dump(result, out, indent=2)
finally:
    if receiver and receiver.poll() is None:
        receiver.terminate()
        receiver.wait(timeout=5)
