"""TASK10 bounded ADB QA, adapted from retained UI05B/06 helpers.

Explicit runtime identity replaces their historical hardcoded QA serial.
Normal Android UI only; no uninstall, clear, grant, model or media deletion.
"""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

ROOT = Path(__file__).parent
ADB = [r'C:\Users\dangh\AppData\Local\Android\sdk\platform-tools\adb.exe', '-s', 'emulator-5554']
PACKAGE = 'com.xrecorder.xrecorder'


def adb(*args, timeout=30):
    return subprocess.check_output(ADB + list(args), timeout=timeout)


def identity():
    actual = adb('emu', 'avd', 'name').decode().splitlines()[0].strip()
    if actual != 'Pixel_7':
        raise RuntimeError('Wrong AVD: ' + actual)
    return actual


def tree():
    for _ in range(3):
        result = adb('shell', 'uiautomator', 'dump', '/sdcard/task10_hierarchy.xml')
        if b'dumped to:' in result:
            raw = adb('exec-out', 'cat', '/sdcard/task10_hierarchy.xml')
            return raw, list(ET.fromstring(raw).iter('node'))
        time.sleep(1)
    raise RuntimeError('UIAutomator did not produce a fresh hierarchy')


def labels(nodes):
    return [n.get('content-desc') or n.get('text') for n in nodes
            if n.get('content-desc') or n.get('text')]


def tap(x, y):
    adb('shell', 'input', 'tap', str(x), str(y))
    time.sleep(.6)


def click(label):
    _, nodes = tree()
    parents = {child: parent for parent in nodes for child in parent}
    candidates = [n for n in nodes if label in
                  ((n.get('content-desc') or '').splitlines() + [n.get('text', '')])]
    candidates.sort(key=lambda n: n.get('clickable') != 'true')
    for n in candidates:
        target = n
        while target.get('clickable') != 'true' and target in parents:
            target = parents[target]
        if target.get('clickable') != 'true' or target.get('enabled') == 'false':
            continue  # A section title is not an actionable control.
        x1, y1, x2, y2 = map(int, re.findall(r'-?\d+', n.get('bounds', '')))
        if x2 > x1 and y2 > y1 and n.get('enabled') != 'false':
            tap((x1 + x2) // 2, (y1 + y2) // 2)
            return
    raise RuntimeError('Control not reachable: ' + label + '; labels=' + repr(labels(nodes)))


def save(name):
    if not re.fullmatch(r'[a-z0-9_]+', name):
        raise ValueError('Unsafe artifact name')
    raw, nodes = tree()
    for suffix, content in [('.xml', raw), ('.png', adb('exec-out', 'screencap', '-p'))]:
        with (ROOT / (name + suffix)).open('xb') as stream:
            stream.write(content)
    return labels(nodes)


def retained_capture_inputs(session_id):
    """Read/hash only an identified task session; never alter recovery files."""
    if not re.fullmatch('[a-f0-9-]{36}', session_id):
        raise ValueError('Invalid task capture session')
    relative = 'files/capture_recovery/' + session_id + '.json'
    checkpoint = adb('exec-out', 'run-as', PACKAGE, 'cat', relative)
    assert len(checkpoint) < 256*1024
    document = json.loads(checkpoint)
    assert document['session']['id'] == session_id
    result = {'sessionId': session_id, 'checkpointSha256': hashlib.sha256(checkpoint).hexdigest(),
              'checkpoint': document, 'inputs': {}}
    for field, suffix in [('videoPath', '.mp4'), ('audioPath', '.m4a')]:
        path = document[field]
        assert path == '/data/user/0/' + PACKAGE + '/cache/capture_' + session_id + suffix
        size = int(adb('exec-out', 'run-as', PACKAGE, 'stat', '-c', '%s', path))
        assert 0 < size < 16*1024**2, 'Bounded task fixture only'
        raw = adb('exec-out', 'run-as', PACKAGE, 'cat', path)
        assert len(raw) == size
        result['inputs'][field] = {'bytes': size, 'sha256': hashlib.sha256(raw).hexdigest()}
    return result


def install_main_profile_checkpoint(name, purpose):
    """Small, exclusive metadata snapshot/update; never copy installed weights.

    This reuses the successful TASK10 bounded-install checks. C5GiB is for a
    short cached APK update; D retains the owner's strict10GiB reserve.
    """
    import io
    import shutil
    import tarfile
    if not re.fullmatch('[a-z0-9_]+', name):
        raise ValueError('Unsafe checkpoint name')
    identity()
    assert shutil.disk_usage('C:/').free > 5 * 1024**3
    assert shutil.disk_usage('D:/').free > 10 * 1024**3
    assert '.recording.CaptureService' not in adb('shell', 'dumpsys', 'activity', 'services', PACKAGE).decode()
    assert all(j['state'] not in ['queued', 'running'] for j in
               json.loads(adb('exec-out', 'run-as', PACKAGE, 'cat', 'files/export_jobs.json')))
    args = ['exec-out', 'run-as', PACKAGE, 'tar', '--exclude=no_backup/speech_models', '-cf', '-',
            'shared_prefs', 'files/projects', 'files/export_jobs.json', 'files/media_transfer.json', 'no_backup']
    def files(raw):
        with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
            return {m.name: archive.extractfile(m).read() for m in archive.getmembers() if m.isfile()}
    raw = adb(*args)
    assert len(raw) < 2 * 1024**2, 'Metadata grew; inspect before further copies'
    with (ROOT / (name + '_before_install.tar')).open('xb') as out:
        out.write(raw)
    before = files(raw)
    original = files((ROOT / 'private_state_before_install.tar').read_bytes())
    drafts = {p: b for p, b in original.items() if p.startswith('files/projects/')}
    assert len(drafts) == 8 and all(before.get(p) == b for p, b in drafts.items())
    apk = Path('build/app/outputs/flutter-apk/app-profile.apk')
    print(adb('install', '-r', str(apk), timeout=90).decode(), flush=True)
    assert before == files(adb(*args)), 'Saved metadata changed during installation'
    model = adb('exec-out', 'run-as', PACKAGE, 'sha256sum', 'no_backup/speech_models/ggml-tiny.bin').split()[0].decode()
    assert model == 'be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21'
    result = {'status': 'PASS', 'apkSha256': hashlib.sha256(apk.read_bytes()).hexdigest(),
              'apkBytes': apk.stat().st_size, 'avd': identity(), 'serial': ADB[-1],
              'metadataFilesByteExact': len(before), 'originalDraftsByteExact': 8,
              'tinySha256': model, 'purpose': purpose,
              'freeBytes': {p: shutil.disk_usage(p).free for p in ['C:/', 'D:/']}}
    with (ROOT / (name + '_profile_install.json')).open('x') as out:
        json.dump(result, out, indent=2)
    print(json.dumps(result), flush=True)
    return result


def baseline():
    info = {'avd': identity(), 'serial': ADB[-1], 'package': PACKAGE,
            'identity': adb('shell', 'cmd', 'package', 'list', 'packages', '-U', PACKAGE).decode(),
            'sdk': adb('shell', 'getprop', 'ro.build.version.sdk').decode().strip(),
            'fingerprint': adb('shell', 'getprop', 'ro.build.fingerprint').decode().strip(),
            'configuration': {key: adb('shell', 'settings', 'get', 'system', key).decode().strip()
                              for key in ['user_rotation', 'accelerometer_rotation', 'font_scale']},
            'wm_size': adb('shell', 'wm', 'size').decode(),
            'wm_density': adb('shell', 'wm', 'density').decode()}
    services = adb('shell', 'dumpsys', 'activity', 'services', PACKAGE).decode()
    if '.recording.CaptureService' in services:
        raise RuntimeError('Existing capture active; no install permitted')
    sizes = adb('shell', 'run-as', PACKAGE, 'du', '-sk', 'shared_prefs', 'files', 'no_backup').decode()
    info['private_sizes_kib'] = sizes
    if sum(int(row.split()[0]) for row in sizes.splitlines()) > 8192:
        raise RuntimeError('Private data exceeds bounded backup; inspect before copying models')
    # This AVD has no large installed models; exact app state is only ~144KiB.
    archive = adb('exec-out', 'run-as', PACKAGE, 'tar', '-cf', '-', 'shared_prefs', 'files', 'no_backup')
    with (ROOT / 'private_state_before_install.tar').open('xb') as stream:
        stream.write(archive)
    info['private_backup_sha256'] = hashlib.sha256(archive).hexdigest()
    info['private_backup_bytes'] = len(archive)
    with (ROOT / 'device_baseline.json').open('x', encoding='utf8') as stream:
        json.dump(info, stream, ensure_ascii=False, indent=2)
    return info


def run(steps):
    identity()
    for step in steps:
        result = {'step': step, 'time': time.time()}
        try:
            if 'click' in step:
                click(step['click'])
            if 'tap' in step:
                tap(*step['tap'])
            if 'key' in step:
                adb('shell', 'input', 'keyevent', str(step['key']))
                time.sleep(.6)
            if 'swipe' in step:
                adb('shell', 'input', 'swipe', *map(str, step['swipe']))
                time.sleep(.5)
            if 'wait' in step:
                time.sleep(min(step['wait'], 30))
            current = save(step['save']) if 'save' in step else labels(tree()[1])
            result['labels'] = current
            if 'expect' in step:
                assert all(any(label in item for item in current) for label in step['expect']), current
            result['status'] = 'PASS'
            print(json.dumps(result, ensure_ascii=True))
        except Exception as error:
            result.update(status='FAIL', error=str(error))
            raise
        finally:
            with (ROOT / 'device_events.jsonl').open('a', encoding='utf8') as stream:
                stream.write(json.dumps(result, ensure_ascii=False) + '\n')


if __name__ == '__main__':
    if sys.argv[1] == 'baseline':
        print(json.dumps(baseline(), ensure_ascii=True))
    else:
        run(json.loads(sys.argv[1]))
