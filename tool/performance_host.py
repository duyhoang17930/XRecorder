"""Task 03 host measurements/consent. Stdlib only; never clear data or delete media."""
import argparse
import json
import pathlib
import re
import subprocess
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent.parent
properties = (ROOT / 'android/local.properties').read_text(encoding='utf8')
sdk = next(s.split('=', 1)[1] for s in properties.splitlines() if s.startswith('sdk.dir=')).replace('\\\\', '\\').replace('\\:', ':')
ADB = str(pathlib.Path(sdk) / 'platform-tools/adb.exe')
SERIAL = 'emulator-5560'
APP = 'com.xrecorder.xrecorder'
AVD = 'ThreeHRecorder_Task021'

def adb(*args, check=True, timeout=20):
    p = subprocess.run([ADB, '-s', SERIAL, *args], capture_output=True, timeout=timeout)
    if check and p.returncode:
        raise RuntimeError(p.stderr.decode(errors='replace'))
    return p.stdout.decode('utf8', errors='replace')

def identity():
    assert adb('shell', 'getprop', 'ro.boot.qemu.avd_name').strip() == AVD, 'Refusing another AVD'

def inactive():
    identity()
    assert '.recording.CaptureService' not in adb('shell', 'dumpsys', 'activity', 'services', APP), 'Capture already active; do not stop/install'
    assert APP not in adb('shell', 'dumpsys', 'media_projection'), 'Projection already active'

def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2), encoding='utf8')

def environment():
    return {k: adb('shell', 'getprop', k).strip() for k in ['ro.boot.qemu.avd_name', 'ro.build.version.sdk', 'ro.product.model', 'ro.product.cpu.abi', 'ro.build.fingerprint']} | {
        'serial': SERIAL, 'wmSize': adb('shell', 'wm', 'size'), 'wmDensity': adb('shell', 'wm', 'density'),
        'meminfo': adb('shell', 'cat', '/proc/meminfo').splitlines()[:3], 'cores': adb('shell', 'getconf', '_NPROCESSORS_ONLN').strip(),
        'thermal': adb('shell', 'dumpsys', 'thermalservice'), 'battery': adb('shell', 'dumpsys', 'battery'),
    }

def startup(args, out):
    inactive()
    apk = (ROOT / args.apk).resolve()
    assert apk.is_relative_to(ROOT / 'build/task03') and apk.is_file()
    adb('install', '-r', str(apk), timeout=90)
    trials = []
    for i in range(3):
        inactive()
        adb('shell', 'am', 'force-stop', APP)
        cold = adb('shell', 'am', 'start', '-W', '-n', APP + '/' + APP + '.MainActivity')
        time.sleep(3)
        memory = adb('shell', 'dumpsys', 'meminfo', '-s', APP)
        adb('shell', 'input', 'keyevent', 'KEYCODE_HOME')
        time.sleep(1)
        warm = adb('shell', 'am', 'start', '-W', '-n', APP + '/' + APP + '.MainActivity')
        time.sleep(1)
        def times(text):
            return {k: int(v) for k, v in re.findall(r'(ThisTime|TotalTime|WaitTime):\s*(\d+)', text)}
        trials.append({'iteration': i, 'processCold': times(cold), 'warmResume': times(warm), 'coldRaw': cold, 'warmRaw': warm, 'memory': memory})
    write(out / 'startup.json', {'phase': args.phase, 'note': 'ActivityManager timings; process cold with retained shader/storage caches, not first-install TTID.', 'trials': trials, 'environment': environment()})
    print('Startup measurements complete:', args.phase, flush=True)

def startup_pair(out, resources=False):
    """Crossover after media generation: both versions see identical retained media."""
    inactive()
    trials = {'before': [], 'after': []}
    for iteration in range(3):
        for phase in (['before', 'after'] if iteration % 2 == 0 else ['after', 'before']):
            inactive()
            apk = ROOT / 'build/task03' / (phase + '-main-profile.apk')
            adb('install', '-r', str(apk), timeout=90)
            time.sleep(2)
            adb('shell', 'am', 'force-stop', APP)
            cold = adb('shell', 'am', 'start', '-W', '-n', APP + '/' + APP + '.MainActivity')
            time.sleep(3)
            adb('shell', 'input', 'keyevent', 'KEYCODE_HOME')
            time.sleep(1)
            warm = adb('shell', 'am', 'start', '-W', '-n', APP + '/' + APP + '.MainActivity')
            time.sleep(1)
            def times(raw):
                return {k: int(v) for k, v in re.findall(r'(ThisTime|TotalTime|WaitTime):\s*(\d+)', raw)}
            row = {'iteration': iteration, 'processCold': times(cold), 'warmResume': times(warm), 'coldRaw': cold, 'warmRaw': warm}
            if resources:
                time.sleep(5)
                row['memoryRaw'] = adb('shell', 'dumpsys', 'meminfo', '-s', APP)
                pid = adb('shell', 'pidof', APP).strip()
                row['top'] = adb('shell', 'top', '-b', '-n', '2', '-d', '1', '-p', pid)
            trials[phase].append(row)
    OUT_PAIR = out.parent / ('resource_crossover.json' if resources else 'startup_crossover.json')
    write(OUT_PAIR, {'note': 'Same retained media, alternating APK order; process cold with warm storage/shader caches, not first-install TTID.', 'trials': trials, 'environment': environment()})
    print('Startup crossover complete:', OUT_PAIR, flush=True)

def benchmark(args, out):
    identity()
    log_path = args.scratch_directory / (args.phase + '-run.log')
    scratch = args.scratch_directory / args.phase
    scratch.mkdir(parents=True, exist_ok=True)
    write(out / 'environment.json', environment())
    markers = [m for i in range(3) for m in [f'PERF03_RECORD_{i}', f'PERF03_SCREENSHOT_{i}', f'PERF03_RETURN_SHOT_{i}']] + ['PERF03_FINISHED']
    handled, copied = set(), set()
    memory = []
    last_sample = 0
    vm_url = None
    isolate = None
    deadline = time.monotonic() + 700
    def rpc(method, **params):
        url = vm_url.rstrip('/') + '/' + method + ('?' + urllib.parse.urlencode(params) if params else '')
        with urllib.request.urlopen(url, timeout=3) as r:
            result = json.load(r)
            if 'error' in result: raise RuntimeError(result['error'])
            return result.get('result', result)
    def snapshot(phase):
        pids = adb('shell', 'pidof', APP, check=False).strip().split()
        if not pids: return
        pid = pids[0]
        mem = adb('shell', 'dumpsys', 'meminfo', '-s', pid)
        cpu = adb('shell', 'top', '-b', '-n', '2', '-d', '1', '-p', pid, timeout=6)
        row = {'phase': phase, 'atHostMonotonic': time.monotonic(), 'pid': pid,
               'pssKiB': next((int(v) for v in re.findall(r'TOTAL PSS:\s*(\d+)', mem)), None),
               'rssKiB': next((int(v) for v in re.findall(r'TOTAL RSS:\s*(\d+)', mem)), None),
               'top': cpu, 'memoryRaw': mem}
        if vm_url:
            try:
                nonlocal isolate
                if isolate is None:
                    isolate = rpc('getVM')['isolates'][0]['id']
                row['dart'] = rpc('getMemoryUsage', isolateId=isolate)
            except Exception as error:
                row['dartUnavailable'] = str(error)[:100]
        memory.append(row)
        write(out / 'resource_samples.json', memory)
    while time.monotonic() < deadline:
        raw = log_path.read_bytes() if log_path.exists() else b''
        log = raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf8', errors='replace')
        if not vm_url:
            match = re.search(r'http://127\.0\.0\.1:\d+/[A-Za-z0-9_=-]+/?', log)
            if match: vm_url = match.group(0)
        for text in re.findall(r'PERF03_OUTPUT=(\{[^\r\n]+\})', log):
            item = json.loads(text)
            if item['uri'] in copied: continue
            name = item['name']
            assert re.fullmatch(r'(Recording_[0-9]+\.mp4|Screenshot_[0-9]+\.png|Edited_[a-f0-9-]+\.(mp4|gif))', name), name
            directory = 'Pictures' if name.endswith('.png') else 'Movies'
            destination = scratch / 'outputs' / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            adb('pull', '/sdcard/' + directory + '/XRecorder/' + name, str(destination), timeout=60)
            copied.add(item['uri'])
            print('Copied verified test output:', name, flush=True)
        pending = next((m for m in markers if m in log and m not in handled), None)
        if pending and ('RETURN' in pending or 'FINISHED' in pending):
            for _ in range(30):
                services = adb('shell', 'dumpsys', 'activity', 'services', APP)
                projection = adb('shell', 'dumpsys', 'media_projection')
                if '.recording.CaptureService' not in services and APP not in projection: break
                time.sleep(.2)
            assert '.recording.CaptureService' not in services, services
            assert APP not in projection, projection
            write(out / (pending.lower() + '_cleanup.json'), {'serviceAbsent': True, 'projectionReleased': True})
            if 'RETURN' in pending: adb('shell', 'am', 'start', '-n', APP + '/' + APP + '.MainActivity')
            handled.add(pending)
        elif pending:
            adb('shell', 'uiautomator', 'dump', '/sdcard/task03-ui.xml')
            rows = list(ET.fromstring(adb('shell', 'cat', '/sdcard/task03-ui.xml')).iter('node'))
            system = [n for n in rows if n.get('package') == 'com.android.systemui']
            if any('3HRecorder' in n.get('text', '') for n in system):
                node = next((n for n in system if n.get('text') in ['Share screen', 'Start now', 'Start'] and n.get('enabled') == 'true'), None)
                if node is not None:
                    a, b, c, d = map(int, re.findall(r'\d+', node.get('bounds')))
                    adb('shell', 'input', 'tap', str((a+c)//2), str((b+d)//2))
                    handled.add(pending)
                    print('Approved fresh system consent:', pending, flush=True)
            else:
                permissions = [n for n in rows if 'permissioncontroller' in n.get('package', '')]
                if any('3HRecorder' in n.get('text', '') for n in permissions):
                    node = next((n for n in permissions if n.get('text') in ['Allow', 'While using the app']), None)
                    if node is not None:
                        a, b, c, d = map(int, re.findall(r'\d+', node.get('bounds')))
                        adb('shell', 'input', 'tap', str((a+c)//2), str((b+d)//2))
        if time.monotonic() - last_sample > 5 and 'PERF03_PHASE=' in log:
            phase = re.findall(r'PERF03_PHASE=([^\r\n]+)', log)[-1]
            try: snapshot(phase)
            except Exception as error: print('Sampler unavailable:', str(error)[:100], flush=True)
            last_sample = time.monotonic()
        if 'All tests passed.' in log or 'Some tests failed.' in log or '[E]' in log:
            if vm_url:
                try: write(scratch / 'vm-timeline.json', rpc('getVMTimeline'))
                except Exception as error: print('Timeline unavailable:', str(error)[:100], flush=True)
            break
        time.sleep(.3)
    write(out / 'host_status.json', {'handled': sorted(handled), 'copiedOutputUris': sorted(copied), 'testMediaPreserved': True})
    print('Host measurements complete:', args.phase, flush=True)

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('mode', choices=['startup', 'startup-pair', 'resources-pair', 'benchmark'])
    p.add_argument('--phase', required=True, choices=['before', 'after'])
    p.add_argument('--apk')
    p.add_argument('--scratch-directory', type=pathlib.Path, default=ROOT / '.claude-local/scratchpad/task03')
    p.add_argument('--artifact-directory', type=pathlib.Path)
    args = p.parse_args()
    args.scratch_directory = args.scratch_directory.resolve()
    assert args.scratch_directory.is_relative_to(ROOT / '.claude-local/scratchpad')
    out = (args.artifact_directory or ROOT / 'build/verification/performance/task03' / args.phase).resolve()
    assert out.is_relative_to(ROOT / 'docs') or out.is_relative_to(ROOT / 'build/verification')
    out.mkdir(parents=True, exist_ok=True)
    if args.mode in ['startup-pair', 'resources-pair']:
        startup_pair(out, resources=args.mode == 'resources-pair')
    else:
        (startup if args.mode == 'startup' else benchmark)(args, out)
