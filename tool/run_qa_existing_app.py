"""Install with adb's non-destructive update, then attach a host Dart driver.

Never use Flutter's install fallback: it may uninstall on insufficient storage.
No build, uninstall, clear-data, root, permission grants or file cleanup here.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import tarfile
import threading
import time
import uuid

PACKAGE = 'com.xrecorder.xrecorder'


def redact(line):
    return re.sub(r'(?:https?|wss?)://[^\s"<>]+', '[local service address withheld]', line)


def write_new(path, data):
    """Atomic create: a collision must leave the earlier evidence untouched."""
    with path.open('xb') as stream:
        stream.write(data)


def package_identity(text):
    return next((line.strip() for line in text.splitlines()
                 if line.split(' ', 1)[0] == 'package:' + PACKAGE), '')


def validate_offline_checkpoint(path, root, serial, avd, identity):
    path = path.resolve(strict=True)
    path.relative_to(root / 'build' / 'verification' / 'task08')
    manifest = json.loads(path.read_text(encoding='utf8'))
    if (manifest.get('kind') != 'offline_avd_checkpoint' or manifest.get('serial') != serial
            or manifest.get('avd') != avd or manifest.get('qemuExitedBeforeCopy') is not True
            or manifest.get('allSourceAndCopySha256Exact') is not True
            or package_identity(manifest.get('packageIdentity', '')) != identity):
        raise RuntimeError('Offline checkpoint identity/consistency mismatch; no install.')
    snapshot = Path(manifest['snapshotDirectory']).resolve(strict=True)
    snapshot.relative_to(path.parent)
    claim = snapshot.parent / (snapshot.name + '.install_claim_v1.json')
    if claim.exists():
        raise RuntimeError('Offline checkpoint already used for an update; create a fresh checkpoint.')
    required = {'config.ini', 'userdata-qemu.img.qcow2', 'encryptionkey.img'}
    names = {row['relativePath'] for row in manifest['files']}
    if not required.issubset(names):
        raise RuntimeError('Offline checkpoint lacks data/encryption files; no install.')
    for row in manifest['files']:
        file = (snapshot / row['relativePath']).resolve(strict=True)
        file.relative_to(snapshot)
        with file.open('rb') as stream:
            digest = hashlib.file_digest(stream, 'sha256').hexdigest()
        if digest != row['sha256'] or file.stat().st_size != row['bytes']:
            raise RuntimeError('Offline checkpoint file changed; no install.')
    return {'manifest': str(path), 'installClaim': str(claim), 'filesVerified': len(manifest['files']),
            'bytesVerified': sum(row['bytes'] for row in manifest['files']),
            'scope': 'whole offline AVD including app data/MediaStore/OS permissions'}


def validate_tar(path):
    size = path.stat().st_size
    if size < 1024 or size % 512:
        raise RuntimeError('Incomplete QA archive; install is forbidden.')
    with path.open('rb') as stream:
        stream.seek(-1024, 2)
        if stream.read() != bytes(1024):
            raise RuntimeError('Missing tar end markers; install is forbidden.')
    try:
        with tarfile.open(path, 'r:') as archive:
            members = archive.getmembers()
            return {'members': len(members),
                    'regularFileBytes': sum(item.size for item in members if item.isfile())}
    except tarfile.TarError:
        raise RuntimeError('Truncated QA archive; install is forbidden.') from None


def receive_chunks(adb, stage, destination, size, output, label):
    """Bound each raw ADB connection; retain failed payloads, never replace them."""
    block = 16 * 1024 * 1024
    records = []
    with destination.open('xb') as stream:
        for index, offset in enumerate(range(0, size, block)):
            wanted = min(block, size - offset)
            for attempt in range(3):
                reply = adb('exec-out', 'dd', 'if=' + stage, 'bs=1048576',
                            'skip=' + str(offset // 1048576),
                            'count=' + str((wanted + 1048575) // 1048576),
                            'status=none', check=False)
                record = {'index': index, 'offset': offset, 'attempt': attempt,
                          'expectedBytes': wanted, 'receivedBytes': len(reply.stdout),
                          'exitCode': reply.returncode}
                records.append(record)
                if reply.returncode == 0 and len(reply.stdout) == wanted:
                    stream.write(reply.stdout)
                    break
                write_new(output / f'{label}_chunk_{index}_attempt_{attempt}.partial', reply.stdout)
                write_new(output / f'{label}_chunk_{index}_attempt_{attempt}.log', reply.stderr)
                if attempt < 2:
                    time.sleep(0.5)
            else:
                write_new(output / f'{label}_chunk_failure_v1.json', json.dumps(records, indent=2).encode())
                raise RuntimeError('Archive chunk incomplete; no install performed.')
    write_new(output / f'{label}_chunks_v1.json', json.dumps(records, indent=2).encode())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--serial', required=True)
    parser.add_argument('--avd', required=True)
    parser.add_argument('--apk', type=Path)
    parser.add_argument('--driver', default='test_driver/task08_driver.dart')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--adb', default=os.environ.get('ADB', 'adb'))
    parser.add_argument('--dart', default=os.environ.get('DART', 'dart'))
    parser.add_argument('--sample-memory', action='store_true',
                        help='Read dumpsys PSS every five seconds; use identically in A/B.')
    parser.add_argument('--attach-running', action='store_true',
                        help='Attach to an already paused QA process without restarting it.')
    parser.add_argument('--install-only', action='store_true',
                        help='Safely update and preserve the app without launching its entrypoint.')
    parser.add_argument('--offline-checkpoint', type=Path,
                        help='Fresh verified offline whole-AVD checkpoint, after a clean restart with app still stopped.')
    args = parser.parse_args()
    if args.attach_running and args.apk:
        raise RuntimeError('Attach-only cannot install an APK.')
    if args.install_only and not args.apk:
        raise RuntimeError('Install-only requires an APK.')
    if args.serial == 'emulator-5554' or not args.avd.startswith('ThreeHRecorder_'):
        raise RuntimeError('A dedicated, named 3HRecorder QA AVD is required.')
    root = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.relative_to(root / 'build' / 'verification')
    if output.exists():
        raise RuntimeError('Use a new output directory; preserve previous evidence.')
    output.mkdir(parents=True)

    def adb(*command, check=True):
        return subprocess.run([args.adb, '-s', args.serial, *command],
                              check=check, capture_output=True)

    def shell(*command):
        return adb('shell', *command).stdout.decode('utf8', errors='replace').strip()

    name = adb('emu', 'avd', 'name').stdout.decode().splitlines()[0]
    if name != args.avd:
        raise RuntimeError('AVD identity mismatch; no install/launch performed.')
    services = shell('dumpsys', 'activity', 'services', PACKAGE)
    if '.recording.CaptureService' in services:
        raise RuntimeError('Capture service active; no stop/install permitted.')
    before = package_identity(shell('cmd', 'package', 'list', 'packages', '-U', PACKAGE))
    if before and not args.attach_running:
        for journal in ['transcription_jobs.json', 'export_jobs.json']:
            probe = adb('shell', 'run-as', PACKAGE, 'test', '-f', 'files/' + journal, check=False)
            if probe.returncode:
                if probe.stderr:
                    raise RuntimeError('Cannot inspect existing QA journal; no stop/install performed.')
                continue
            raw = adb('exec-out', 'run-as', PACKAGE, 'cat', 'files/' + journal).stdout
            try:
                rows = json.loads(raw)
                if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
                    raise ValueError('Unrecognized journal')
                if any(row.get('state') in ['queued', 'running', 'finalizing'] for row in rows):
                    raise RuntimeError('Existing QA job is active; no stop/install performed.')
            except (ValueError, UnicodeError):
                raise RuntimeError('Existing QA journal needs inspection; no stop/install performed.') from None
    if args.apk:
        apk = args.apk.resolve(strict=True)
        free = int(shell('df', '-k', '/data').splitlines()[-1].split()[3]) * 1024
        required = 4 * apk.stat().st_size + 512 * 1024 * 1024
        if free < required:
            raise RuntimeError(f'Insufficient safe install margin: {free} < {required}; stopped.')
        if before:
            # Include no_backup models and all current private state, not just
            # files/preferences. Existing APK signature/UID is kept by install -r.
            if args.offline_checkpoint:
                package_dump = shell('dumpsys', 'package', PACKAGE)
                users = [line for line in package_dump.splitlines() if 'User 0:' in line]
                age = time.time() - args.offline_checkpoint.stat().st_mtime
                if not users or 'stopped=true' not in users[0] or not 0 <= age <= 1800:
                    raise RuntimeError('Checkpoint requires a fresh restart and still-stopped app; no install.')
                verified = validate_offline_checkpoint(args.offline_checkpoint, root, args.serial, name, before)
                # One update per snapshot, even if that update fails. A stopped
                # app alone cannot prove its data hasn't changed since backup.
                write_new(Path(verified['installClaim']), json.dumps({
                    'output': str(output), 'apk': str(apk),
                    'utc': datetime.now(timezone.utc).isoformat(),
                }, indent=2).encode('utf8'))
                write_new(output / 'offline_checkpoint_verified_v1.json', json.dumps(verified, indent=2).encode())
            adb('shell', 'am', 'force-stop', PACKAGE)
            for label, command in ([] if args.offline_checkpoint else [
                ('private', ['run-as', PACKAGE, 'tar', '-cf', '-', '.']),
                ('external', ['tar', '-cf', '-', '-C',
                              f'/sdcard/Android/data/{PACKAGE}', '.']),
            ]):
                # Avoid exec-out's large raw stream: this host/AVD transport
                # disconnected mid-tar yet once returned exit0. The shell opens
                # a fresh shell-owned stage before run-as changes UID; no root,
                # chmod, file replacement or user-data destination is involved.
                stage = f'/data/local/tmp/task08_backup_v1_{uuid.uuid4().hex}.tar'
                remote = 'set -C; ' + shlex.join(command) + ' > ' + shlex.quote(stage)
                result = adb('shell', remote, check=False)
                write_new(output / f'backup_{label}.log', result.stdout + result.stderr)
                if result.returncode:
                    raise RuntimeError(f'{label} backup failed; no install performed.')
                expected = shell('sha256sum', stage).split()[0]
                expected_size = int(shell('stat', '-c', '%s', stage))
                # Both the parent directory and the UUID stage basename are new.
                # Pull into a fresh directory; never target any existing file.
                pull_directory = output / ('archive_' + label + '_v1')
                pull_directory.mkdir()
                archive_path = pull_directory / stage.rsplit('/', 1)[1]
                if expected_size > 32 * 1024 * 1024:
                    receive_chunks(adb, stage, archive_path, expected_size, output, label)
                else:
                    pulled = adb('pull', '-Z', stage, str(pull_directory), check=False)
                    write_new(output / f'pull_{label}.log', pulled.stdout + pulled.stderr)
                    write_new(output / f'pull_{label}_result_v1.json', json.dumps({
                        'exitCode': pulled.returncode, 'compressionDisabled': True,
                        'deviceStage': stage,
                        'receivedBytes': archive_path.stat().st_size if archive_path.is_file() else None,
                    }, indent=2).encode('utf8'))
                    if pulled.returncode or not archive_path.is_file():
                        raise RuntimeError(f'{label} pull failed; no install performed.')
                with archive_path.open('rb') as stream:
                    actual = hashlib.file_digest(stream, 'sha256').hexdigest()
                if actual != expected:
                    raise RuntimeError(f'{label} archive SHA mismatch; no install performed.')
                manifest = validate_tar(archive_path)
                write_new(output / f'backup_{label}_manifest_v1.json', json.dumps({
                    **manifest, 'hostPath': str(archive_path), 'deviceStage': stage,
                    'bytes': archive_path.stat().st_size, 'sha256': actual,
                    'deviceAndHostExact': True, 'deviceStageRetained': True,
                }, indent=2).encode('utf8'))
            remaining = int(shell('df', '-k', '/data').splitlines()[-1].split()[3]) * 1024
            if remaining < required:
                raise RuntimeError('Safe install margin exhausted after backup; no install performed.')
        result = adb('install', '-r', str(apk), check=False)
        write_new(output / 'install.log', result.stdout + result.stderr)
        if result.returncode or b'Success' not in result.stdout:
            raise RuntimeError('adb update failed; aborted without uninstall or retry.')
        after = package_identity(shell('cmd', 'package', 'list', 'packages', '-U', PACKAGE))
        if not after:
            raise RuntimeError('Expected QA package missing after install; no launch performed.')
        if before and before != after:
            raise RuntimeError('Package UID changed unexpectedly; stop and inspect.')
    if args.install_only:
        write_new(output / 'runner.json', json.dumps({
            'serial': args.serial, 'avd': name, 'installedWith': 'adb install -r',
            'sdkInstallUsed': False, 'appLeftInstalled': True, 'launched': False,
        }, indent=2).encode('utf8'))
        return 0

    if not args.attach_running:
        adb('shell', 'am', 'force-stop', PACKAGE)
        launch = adb('shell', 'am', 'start', '-n', f'{PACKAGE}/.MainActivity',
                     '-a', 'android.intent.action.MAIN', '--ez', 'enable-dart-profiling', 'true',
                     '--ez', 'start-paused', 'true')
        write_new(output / 'launch.log', redact(launch.stdout.decode()).encode('utf8'))
    pid = ''
    for _ in range(40):
        pid = adb('shell', 'pidof', PACKAGE, check=False).stdout.decode().strip()
        if pid.isdigit():
            break
        time.sleep(0.25)
    if not pid.isdigit():
        raise RuntimeError('App process not found.')
    vm = None
    for _ in range(60):
        logs = shell('logcat', '-d', '--pid=' + pid, '-v', 'brief')
        match = re.search(r'(?:VM Service|Dart VM service) is listening on (http://[^\s]+)', logs)
        if match:
            vm = match.group(1)
            break
        time.sleep(0.5)
    if vm is None:
        raise RuntimeError('No profile/debug VM service discovered; app preserved.')
    from urllib.parse import urlsplit, urlunsplit
    uri = urlsplit(vm)
    port = adb('forward', 'tcp:0', f'tcp:{uri.port}').stdout.decode().strip()
    service = urlunsplit(('http', f'127.0.0.1:{port}', uri.path, '', ''))
    env = dict(os.environ, VM_SERVICE_URL=service,
               UI_ARTIFACT_DIRECTORY=str(output))
    start = datetime.now(timezone.utc).isoformat()
    stopped = threading.Event()

    def memory_samples():
        tick_result = adb('shell', 'getconf', 'CLK_TCK', check=False)
        tick_text = tick_result.stdout.decode().strip()
        ticks_per_second = int(tick_text) if tick_text.isdigit() else None
        with (output / 'memory.jsonl').open('x', encoding='utf8') as stream:
            while not stopped.is_set():
                begin = time.monotonic()
                result = adb('shell', 'dumpsys', 'meminfo', PACKAGE, '-s', check=False)
                raw = result.stdout.decode('utf8', errors='replace')
                pss = re.search(r'TOTAL PSS:\s*([0-9,]+)', raw)
                status = adb('shell', 'cat', f'/proc/{pid}/status', check=False).stdout.decode(errors='replace')
                stat = adb('shell', 'cat', f'/proc/{pid}/stat', check=False).stdout.decode(errors='replace')
                fields = stat[stat.rfind(')') + 2:].split() if stat.startswith(pid + ' ') else []
                threads = re.search(r'^Threads:\s*(\d+)', status, re.M)
                rss = re.search(r'^VmRSS:\s*(\d+)', status, re.M)
                hwm = re.search(r'^VmHWM:\s*(\d+)', status, re.M)
                stream.write(json.dumps({
                    'utcMs': round(time.time() * 1000), 'queryMs': round((time.monotonic() - begin) * 1000),
                    'pssKiB': int(pss[1].replace(',', '')) if pss else None,
                    'threadCount': int(threads[1]) if threads else None,
                    'vmRssKiB': int(rss[1]) if rss else None,
                    'vmHwmKiB': int(hwm[1]) if hwm else None,
                    'cpuUserTicks': int(fields[11]) if len(fields) > 12 else None,
                    'cpuSystemTicks': int(fields[12]) if len(fields) > 12 else None,
                    'cpuTicksPerSecond': ticks_per_second,
                    'hostMonotonicSeconds': time.monotonic(),
                    'raw': raw,
                }) + '\n')
                stream.flush()
                stopped.wait(5)

    sampler = threading.Thread(target=memory_samples, daemon=True) if args.sample_memory else None
    if sampler:
        sampler.start()
    try:
        with (output / 'driver.log').open('x', encoding='utf8') as log:
            process = subprocess.Popen([args.dart, '--packages=.dart_tool/package_config.json',
                                        args.driver], cwd=root, env=env,
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       text=True, encoding='utf8', errors='replace')
            for line in process.stdout:
                safe = redact(line)
                log.write(safe)
                log.flush()
                print(safe, end='', flush=True)
            code = process.wait()
    finally:
        stopped.set()
        if sampler:
            sampler.join(timeout=15)
        adb('forward', '--remove', 'tcp:' + port, check=False)
    write_new(output / 'runner.json', json.dumps({
        'serial': args.serial, 'avd': name, 'pid': pid, 'startUtc': start,
        'driverExit': code, 'installedWith': 'adb install -r' if args.apk else None,
        'sdkInstallUsed': False, 'appLeftInstalled': True,
    }, indent=2).encode('utf8'))
    return code


if __name__ == '__main__':
    raise SystemExit(main())
