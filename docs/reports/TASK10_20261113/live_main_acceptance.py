"""Normal main.dart UI + Android consent -> real screen RTMP + local backup.

Reuse device_qa and existing FFmpeg. During capture, avoid UIAutomator's idle
wait: it can consume30s while a legitimate recording timer updates every second.
Use the verified fixed footer only after checking this exact live session.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import socket
import subprocess
import time
import xml.etree.ElementTree as ET

import device_qa as q

parser = argparse.ArgumentParser()
parser.add_argument('--attempt', required=True)
args = parser.parse_args()
assert re.fullmatch('[a-z0-9_]+', args.attempt)
q.identity()
assert shutil.disk_usage('D:/').free > 10 * 1024**3
assert shutil.disk_usage('C:/').free > 5 * 1024**3
assert '.recording.CaptureService' not in q.adb('shell', 'dumpsys', 'activity', 'services', q.PACKAGE).decode()
stem = 'live_' + args.attempt
key = 'task10_live_' + args.attempt


def journal():
    raw = q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', 'shared_prefs/capture_journal.xml')
    return raw, json.loads(ET.fromstring(raw).find("string[@name='session']").text)


def box(node):
    return list(map(int, re.findall(r'\d+', node.get('bounds'))))


def fill(index, value):
    _, nodes = q.tree()
    fields = [n for n in nodes if n.get('class') == 'android.widget.EditText']
    assert len(fields) == 2
    assert not fields[index].get('text'), 'Use a fresh task setup; never overwrite an existing key'
    x, y, right, bottom = box(fields[index])
    q.tap(x + 70, (y + bottom) // 2)
    q.adb('shell', 'input', 'text', value)


fill(0, 'rtmp://10.0.2.2:19350/live')
fill(1, key)
q.adb('shell', 'input', 'keyevent', '4')
_, nodes = q.tree()
fields = [n for n in nodes if n.get('class') == 'android.widget.EditText']
assert fields[0].get('text') == 'rtmp://10.0.2.2:19350/live'
assert fields[1].get('password') == 'true' and len(fields[1].get('text', '')) == len(key)
footer = next(n for n in nodes if n.get('content-desc') == 'Start livestream' and n.get('enabled') == 'true')
x, y, right, bottom = box(footer)
footer_point = ((x + right) // 2, (y + bottom) // 2)
assert key not in q.labels(nodes), 'QA key must be obscured before capture'
directory = q.ROOT / (stem + '_receiver_media')
directory.mkdir(exist_ok=False)
with socket.socket() as check:
    check.bind(('127.0.0.1', 19350))
session_id = None
receiver = None
result = {'attempt': args.attempt, 'avd': q.identity(), 'serial': q.ADB[-1], 'status': 'FAIL'}
with (q.ROOT / (stem + '_receiver.log')).open('xb') as log:
    try:
        receiver = subprocess.Popen([
            'build/task03/ffmpeg/ffmpeg.exe', '-hide_banner', '-nostdin', '-n',
            '-listen', '1', '-timeout', '90', '-i',
            'rtmp://127.0.0.1:19350/live/' + key,
            '-t', '45', '-c', 'copy', '-movflags', '+faststart',
            str(directory / 'received.mp4')], stdout=log, stderr=subprocess.STDOUT,
            creationflags=subprocess.CREATE_NO_WINDOW)
        time.sleep(.3)
        assert receiver.poll() is None
        previous = journal()[1]['id']
        q.click('Start livestream')
        for _ in range(40):
            _, state = journal()
            if state['id'] != previous:
                break
            time.sleep(.1)
        assert state['id'] != previous and state['state'] == 'awaitingPermission' and state['config']['liveRequested']
        session_id = state['id']
        _, nodes = q.tree()
        if 'Share one app' in q.labels(nodes):
            q.click('Share one app')
            q.click('Share entire screen')
        q.save(stem + '_consent')
        q.click('Share screen')
        print('Approved normal full-screen consent; session=' + session_id, flush=True)
        for _ in range(75):
            raw, state = journal()
            assert state['id'] == session_id
            if state['state'] == 'recording':
                break
            assert state['state'] not in ['failed', 'completed'], state
            time.sleep(.2)
        else:
            raise RuntimeError('Capture did not reach recording')
        time.sleep(8)
        assert receiver.poll() is None, 'Receiver ended before capture was stopped'
        q.adb('shell', 'am', 'start', '-n', q.PACKAGE + '/.MainActivity')
        time.sleep(1)
        with (q.ROOT / (stem + '_active.png')).open('xb') as stream:
            stream.write(q.adb('exec-out', 'screencap', '-p'))
        _, state = journal()
        assert state['id'] == session_id and state['state'] == 'recording'
        q.tap(*footer_point)
        print('Tapped the verified End livestream footer for this active session', flush=True)
        for _ in range(125):
            raw, state = journal()
            assert state['id'] == session_id
            if state['state'] in ['completed', 'failed']:
                break
            time.sleep(.2)
        with (q.ROOT / (stem + '_final_journal.xml')).open('xb') as stream:
            stream.write(raw)
        assert state['state'] == 'completed' and state.get('outputUri'), state
        result['session'] = state
        payload = q.adb('exec-out', 'content', 'read', '--uri', state['outputUri'])
        local = q.ROOT / (stem + '_local_media')
        local.mkdir(exist_ok=False)
        with (local / 'local_backup.mp4').open('xb') as stream:
            stream.write(payload)
        registry_path = q.ROOT / 'task_created_media.json'
        registry = json.loads(registry_path.read_text())
        registry.append({'uri': state['outputUri'], 'source': 'real main screen livestream local backup',
                         'sessionId': session_id, 'bytes': len(payload),
                         'sha256': hashlib.sha256(payload).hexdigest(),
                         'evidence': stem + '_final_journal.xml'})
        registry_path.write_text(json.dumps(registry, indent=2))
        assert key.encode() not in raw
        receiver.wait(timeout=10)
        assert state['live']['state'] == 'stopped', state['live']
        assert (directory / 'received.mp4').stat().st_size > 10000
        q.save(stem + '_ended')
        result.update(status='PASS', journalContainsNoKey=True,
                      localSha256=hashlib.sha256(payload).hexdigest(), localBytes=len(payload),
                      receiverExit=receiver.returncode)
        print(json.dumps(result), flush=True)
    finally:
        _, current = journal()
        if session_id and current['id'] == session_id and current['state'] in ['recording', 'paused', 'countdown', 'starting']:
            q.adb('shell', 'am', 'start', '-n', q.PACKAGE + '/.MainActivity')
            try:
                q.click('End livestream')
            except Exception:
                # Receiver is bounded45s; native failed-connection handling then
                # terminates this session. Never stop another session or clear data.
                result['cleanup'] = 'Normal End control not reachable; bounded receiver retained'
        if receiver and receiver.poll() is None:
            receiver.terminate()
            receiver.wait(timeout=5)
        with (q.ROOT / (stem + '_ui_result.json')).open('x') as stream:
            json.dump(result, stream, indent=2)
