"""Reuse the existing native media/preview harness with new TASK10-only fixtures.

Three small existing host media files, two new drafts, no schema migration or
personal media changes. Legacy harness names are required by its safety guards.
"""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import time
from urllib.parse import quote

import device_qa as q

q.identity()
assert shutil.disk_usage('D:/').free > 10 * 1024**3
assert shutil.disk_usage('C:/').free > 10 * 1024**3
assert '.recording.CaptureService' not in q.adb('shell', 'dumpsys', 'activity', 'services', q.PACKAGE).decode()
stamp = str(int(time.time() * 1000))
directory = '/sdcard/Download/TASK10_20261113/audio_' + stamp
q.adb('shell', 'mkdir', directory)
assets = []
for name in ['p2_p3_audio_video.mp4', 'p2_p3_tone_440.wav', 'p2_p3_tone_880.wav']:
    source = Path('build/verification/p2_p3/audio') / name
    destination = directory + '/' + name
    assert source.stat().st_size < 1024 * 1024
    q.adb('push', str(source), destination)
    sha = hashlib.sha256(source.read_bytes()).hexdigest()
    assert sha == q.adb('exec-out', 'sha256sum', destination).split()[0].decode()
    assets.append({'source': str(source), 'path': destination, 'bytes': source.stat().st_size, 'sha256': sha})


def uri(name):
    path = directory.replace('/sdcard/', 'primary:') + '/' + name
    return 'content://com.android.externalstorage.documents/tree/primary%3ADownload%2FTASK10_20261113/document/' + quote(path, safe='')


def create(path, data):
    # All paths are generated constants; noclobber protects even a collision.
    assert re.fullmatch(r'files/(projects/)?[a-zA-Z0-9_]+\.json', path)
    subprocess.run(q.ADB + ['shell', 'run-as', q.PACKAGE, 'sh', '-c',
                   "'set -C; cat > " + path + "'"], input=data, check=True, capture_output=True)
    assert q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', path) == data


projects = {}
manifest = {}
clip = {'mediaId': uri('p2_p3_audio_video.mp4'), 'title': 'TASK10 audio source',
        'inMs': 0, 'outMs': 4000, 'sourceDurationMs': 4000, 'rotation': 0, 'isImage': False,
        'flipH': False, 'flipV': False, 'cropLeft': 0.0, 'cropTop': 0.0, 'cropRight': 1.0, 'cropBottom': 1.0}
for name in ['baseline', 'eightTrackMix']:
    identifier = 'audio_' + stamp + '_' + name
    effects = {}
    if name == 'eightTrackMix':
        effects = {'volume': 0.0, 'audioTracks': [
            {'id': 'task10_track_' + str(i), 'title': 'TASK10 tone ' + str(i),
             'uri': uri('p2_p3_tone_' + ('440' if i % 2 == 0 else '880') + '.wav'),
             'inMs': 0, 'outMs': 4000, 'sourceDurationMs': 4000, 'offsetMs': i * 100,
             'volume': 0.5, 'fadeInMs': 200, 'fadeOutMs': 200, 'pitch': 1.0,
             'voice': 'none', 'noiseReduction': False} for i in range(8)]}
    project = {'version': 1, 'id': identifier, 'title': 'TASK10_AUDIO_' + name,
               'updatedAt': int(stamp), 'clips': [clip], 'effects': effects}
    data = json.dumps(project, ensure_ascii=False).encode()
    create('files/projects/' + identifier + '.json', data)
    projects[identifier] = hashlib.sha256(data).hexdigest()
    manifest[name] = identifier
filename = 'task08_media_input_' + stamp + '.json'
create('files/' + filename, json.dumps(manifest).encode())
registry = {'stamp': stamp, 'assets': assets, 'projects': projects, 'manifest': filename,
            'scope': 'TASK10 new fixtures; reuse production native export/preview; main UI tested separately'}
with (q.ROOT / 'editor_audio_gate1_fixtures.json').open('x') as out:
    json.dump(registry, out, indent=2)
print(json.dumps(registry), flush=True)
for case, extra in [('media', []), ('preview', ['-e', 'previewCycles', '10'])]:
    q.adb('shell', 'am', 'force-stop', q.PACKAGE)
    raw = q.adb('shell', 'am', 'instrument', '-w', '-e', 'task08', case,
                '-e', 'mediaInput', filename, *extra,
                'com.xrecorder.xrecorder.test/com.xrecorder.xrecorder.qa.Task07AccessibilityInstrumentation', timeout=240)
    with (q.ROOT / ('editor_audio_gate1_' + case + '_runtime.txt')).open('xb') as out:
        out.write(raw)
    print(raw.decode(errors='replace'), flush=True)
    match = re.search(rb'TASK08_(?:MEDIA_REGRESSION|PREVIEW)_PASS:[^\r\n]*report=([a-zA-Z0-9_]+\.json)', raw)
    assert match, 'Native failure retained; fixtures preserved'
    report = q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', 'files/' + match.group(1).decode())
    with (q.ROOT / ('editor_audio_gate1_' + case + '_result.json')).open('xb') as out:
        out.write(report)
    if case == 'media':
        results = json.loads(report)
        target = q.ROOT / 'editor_audio_gate1_media'
        target.mkdir(exist_ok=False)
        owned = json.loads((q.ROOT / 'task_created_media.json').read_text())
        for name, content_uri in results['outputs'].items():
            with (target / (name + '.mp4')).open('xb') as out:
                out.write(q.adb('exec-out', 'content', 'read', '--uri', content_uri))
            owned.append({'uri': content_uri, 'case': 'editor_audio_' + name, 'sessionId': None,
                          'source': 'TASK10 audio gate new fixture', 'evidence': 'editor_audio_gate1_media_result.json'})
        (q.ROOT / 'task_created_media.json').write_text(json.dumps(owned, indent=2))
    q.adb('shell', 'am', 'force-stop', q.PACKAGE)
for identifier, sha in projects.items():
    assert hashlib.sha256(q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', 'files/projects/' + identifier + '.json')).hexdigest() == sha
print('PASS: two native exports, ten real-surface preview reloads; draft bytes preserved.', flush=True)
