"""Real consent/capture plus task-owned speech playback to local RTMP receiver.

Reuse the existing native dispatcher and FFmpeg; no external account/server.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import secrets
import shutil
import socket
import subprocess
from urllib.parse import urlunsplit
import xml.etree.ElementTree as ET

import device_qa as q

p = argparse.ArgumentParser()
p.add_argument('--attempt', required=True)
p.add_argument('--source', default='content://media/external/video/media/115')
p.add_argument('--observe-ms', type=int, default=7500)
p.add_argument('--repeat-source', action='store_true')
p.add_argument('--player', choices=['video', 'static'], default='video')
p.add_argument('--fail-after-playback', action='store_true')
p.add_argument('--pause-before-failure', action='store_true')
p.add_argument('--deny-first-consent', action='store_true')
args = p.parse_args()
assert not args.pause_before_failure or args.fail_after_playback
assert 7500 <= args.observe_ms <= 300000
assert re.fullmatch('[a-z0-9_]+', args.attempt)
q.identity()
assert shutil.disk_usage('D:/').free > 10 * 1024**3
# C: hosts the running AVD; this bounded <90s capture writes only a few MB.
# D: retains the owner's strict10GiB reserve. No builds/downloads are run here.
assert shutil.disk_usage('C:/').free > 5 * 1024**3
assert '.recording.CaptureService' not in q.adb('shell', 'dumpsys', 'activity', 'services', q.PACKAGE).decode()
source = args.source
assert re.fullmatch(r'content://media/external/video/media/[0-9]+', source)
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
key = secrets.token_hex(24)
receiver_url = urlunsplit(('rtmp', '127.0.0.1:19350', '/live/' + key, '', ''))
server_url = urlunsplit(('rtmp', '10.0.2.2:19350', '/live', '', ''))
receiver = None
try:
    with (q.ROOT / (stem + '_receiver.log')).open('xb') as log:
        receiver = subprocess.Popen(['build/task03/ffmpeg/ffmpeg.exe', '-loglevel', 'quiet', '-hide_banner', '-nostdin', '-n',
            '-listen', '1', '-timeout', '120', '-i', receiver_url,
            '-t', str(args.observe_ms // 1000 + 90), '-c', 'copy', '-movflags', '+faststart', str(target / 'received.mp4')],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=subprocess.CREATE_NO_WINDOW)
        q.adb('shell', 'am', 'force-stop', q.PACKAGE)
        try:
            raw = q.adb('shell', 'am', 'instrument', '-w', '-e', 'task10', 'live-capture-audio',
                '-e', 'source', source, '-e', 'attempt', args.attempt,
                '-e', 'serverUrl', server_url, '-e', 'streamKey', key,
                '-e', 'player', args.player,
                '-e', 'observeMs', str(args.observe_ms), '-e', 'repeatSource', str(args.repeat_source).lower(),
                '-e', 'failAfterPlayback', str(args.fail_after_playback).lower(),
                '-e', 'pauseBeforeFailure', str(args.pause_before_failure).lower(),
                '-e', 'denyFirstConsent', str(args.deny_first_consent).lower(),
                'com.xrecorder.xrecorder.test/com.xrecorder.xrecorder.qa.Task07AccessibilityInstrumentation', timeout=args.observe_ms // 1000 + 180)
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            raise RuntimeError('Livestream instrumentation failed or timed out; destination values withheld.') from None
        raw = raw.replace(server_url.encode(), b'[redacted]').replace(key.encode(), b'[redacted]')
        with (q.ROOT / (stem + '_runtime.txt')).open('xb') as out:
            out.write(raw)
        match = re.search(rb'TASK10_LIVE_RESULT:(\{[^\r\n]+\})', raw)
        if not match:
            raise RuntimeError('Livestream instrumentation returned no structured result; output withheld to protect destination values.')
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
