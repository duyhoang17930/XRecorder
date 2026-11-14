"""Reuse TASK10 ADB runner and host FFmpeg for a loopback-only RTMP receiver.

No screen capture, account, external server, deletion or credential is involved.
The existing task-created subtitle export115 is read, never modified.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import socket
import ssl
import subprocess
import threading
import time

import device_qa as q

parser = argparse.ArgumentParser()
parser.add_argument('--attempt', required=True)
parser.add_argument('--install', action='store_true')
parser.add_argument('--cases', nargs='+', choices=['live-transport', 'live-refused', 'live-cancel', 'live-reconnect'],
                    default=['live-transport', 'live-refused', 'live-cancel'])
parser.add_argument('--untrusted-tls', action='store_true',
                    help='Loopback-only self-signed server; verify Android rejects its certificate without changing trust')
args = parser.parse_args()
assert re.fullmatch('[a-z0-9_]+', args.attempt)
assert not args.untrusted_tls or args.cases == ['live-refused']
q.identity()
assert shutil.disk_usage('D:/').free > 10 * 1024**3
# Owner's hard build reserve is10GiB on D. This already-built APK/8s loopback
# run writes <256MiB on C and keeps a separate conservative5GiB AVD reserve.
# Do not use this bound to authorize model downloads or heavy builds.
assert shutil.disk_usage('C:/').free > (5 * 1024**3 + 256 * 1024**2)
assert '.recording.CaptureService' not in q.adb('shell', 'dumpsys', 'activity', 'services', q.PACKAGE).decode()
source = 'content://media/external/video/media/115'
registry = json.loads((q.ROOT / 'task_created_media.json').read_text())
assert any(item['uri'] == source for item in registry), 'Source must be positively task-owned'
source_sha = hashlib.sha256(q.adb('exec-out', 'content', 'read', '--uri', source)).hexdigest()
journal = q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', 'shared_prefs/capture_journal.xml')
if args.install:
    q.install_main_profile_checkpoint('live_' + args.attempt, 'Loopback transport acceptance')
    apks = []
    for path in [Path('build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk')]:
        apks.append({'path': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                     'bytes': path.stat().st_size})
        print(q.adb('install', '-r', str(path), timeout=90).decode(), flush=True)
        assert shutil.disk_usage('C:/').free > 5 * 1024**3
    with (q.ROOT / ('live_' + args.attempt + '_apks.json')).open('x') as stream:
        json.dump(apks, stream, indent=2)
directory = q.ROOT / ('live_' + args.attempt + '_media')
directory.mkdir(exist_ok=False)
for port in {19350 if case in ['live-transport', 'live-reconnect'] else 19351 for case in args.cases}:
    with socket.socket() as check:
        check.bind(('127.0.0.1', port))
results = []
key = 'task10_secret_probe_' + args.attempt


class UntrustedTlsReceiver:
    """Task-only CA-negative fixture. Never installs a certificate or changes Android trust."""
    def __init__(self):
        openssl = Path('C:/Program Files/Git/usr/bin/openssl.exe')
        assert openssl.is_file(), 'Reuse existing OpenSSL; do not download a toolchain'
        cert, private_key = directory / 'untrusted-cert.pem', directory / 'fixture-key.pem'
        subprocess.run([str(openssl), 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
                        '-days', '1', '-subj', '/CN=10.0.2.2', '-addext', 'subjectAltName=IP:10.0.2.2',
                        '-keyout', str(private_key), '-out', str(cert)], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
        self.cert_sha256 = hashlib.sha256(cert.read_bytes()).hexdigest()
        self.context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        self.context.load_cert_chain(cert, private_key)
        self.listener = socket.socket()
        self.listener.bind(('127.0.0.1', 19351))
        self.listener.listen(4)
        self.listener.settimeout(.25)
        self.stopped = threading.Event()
        self.handshakes = []
        self.worker = threading.Thread(target=self.serve, name='task10-untrusted-tls', daemon=True)
        self.worker.start()

    def serve(self):
        while not self.stopped.is_set():
            try:
                connection, _ = self.listener.accept()
            except socket.timeout:
                continue
            with connection:
                connection.settimeout(5)
                try:
                    with self.context.wrap_socket(connection, server_side=True):
                        self.handshakes.append({'accepted': True})
                except ssl.SSLError as error:
                    self.handshakes.append({'accepted': False, 'reason': error.reason})
                except OSError as error:
                    self.handshakes.append({'accepted': False, 'reason': type(error).__name__})

    def finish(self):
        self.stopped.set()
        self.worker.join(6)
        self.listener.close()
        assert not self.worker.is_alive(), 'TLS fixture must stop before the next Android workflow'
        proof = {'certificateSha256': self.cert_sha256, 'certificateSan': 'IP:10.0.2.2',
                 'androidTrustModified': False, 'handshakes': self.handshakes,
                 'scope': 'Untrusted CA rejection, not trusted RTMPS success or hostname mismatch acceptance'}
        with (q.ROOT / ('live_' + args.attempt + '_tls_server.json')).open('x') as out:
            json.dump(proof, out, indent=2)
        assert len(self.handshakes) == 3, self.handshakes
        assert all(not h['accepted'] and h['reason'] in
                   ['SSLV3_ALERT_CERTIFICATE_UNKNOWN', 'TLSV1_ALERT_UNKNOWN_CA', 'SSLV3_ALERT_BAD_CERTIFICATE']
                   for h in self.handshakes), self.handshakes


class RestartingRtmpReceiver:
    """Close the task listener after2s of media, then accept a fresh connection."""
    def __init__(self, key):
        self.key = key
        self.stopped = threading.Event()
        self.processes = []
        self.errors = []
        self.first = self.start('rtmp_received', 2)
        self.worker = threading.Thread(target=self.restart, name='task10-rtmp-receiver-restart', daemon=True)
        self.worker.start()

    def start(self, name, seconds):
        with (directory / (name + '.log')).open('xb') as log:
            process = subprocess.Popen([
                'build/task03/ffmpeg/ffmpeg.exe', '-hide_banner', '-nostdin', '-n',
                '-listen', '1', '-timeout', '30', '-i', 'rtmp://127.0.0.1:19350/live/' + self.key,
                '-t', str(seconds), '-c', 'copy', '-movflags', '+faststart', str(directory / (name + '.mp4'))],
                stdout=log, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        self.processes.append(process)
        return process

    def restart(self):
        try:
            self.first.wait(35)
            if not self.stopped.is_set():
                self.start('rtmp_reconnected', 40)
        except Exception as error:
            self.errors.append(type(error).__name__)

    def finish(self):
        self.stopped.set()
        for process in self.processes:
            try:
                process.wait(10)
            except subprocess.TimeoutExpired:
                process.terminate()
                process.wait(5)
        self.worker.join(5)
        assert not self.worker.is_alive() and not self.errors, self.errors


for case in args.cases:
    receiver = None
    tls_receiver = None
    restarting_receiver = None
    port = 19350 if case in ['live-transport', 'live-reconnect'] else 19351
    log_stream = None
    try:
        if args.untrusted_tls:
            tls_receiver = UntrustedTlsReceiver()
        if case == 'live-reconnect':
            restarting_receiver = RestartingRtmpReceiver(key)
        if case == 'live-transport':
            log_stream = (q.ROOT / ('live_' + args.attempt + '_receiver.txt')).open('xb')
            receiver = subprocess.Popen([
                'build/task03/ffmpeg/ffmpeg.exe', '-hide_banner', '-nostdin', '-n',
                '-listen', '1', '-timeout', '20', '-i', f'rtmp://127.0.0.1:{port}/live/{key}',
                '-t', '12', '-c', 'copy', '-movflags', '+faststart', str(directory / 'rtmp_received.mp4')],
                stdout=log_stream, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
            time.sleep(.5)
            assert receiver.poll() is None, 'Receiver failed to start; log retained'
        q.adb('shell', 'am', 'force-stop', q.PACKAGE)
        scheme = 'rtmps' if args.untrusted_tls else 'rtmp'
        log = q.adb('shell', 'am', 'instrument', '-w', '-e', 'task10', case,
                    '-e', 'source', source, '-e', 'server', f'{scheme}://10.0.2.2:{port}/live',
                    '-e', 'attempt', args.attempt,
                    'com.xrecorder.xrecorder.test/com.xrecorder.xrecorder.qa.Task07AccessibilityInstrumentation', timeout=60)
        with (q.ROOT / ('live_' + args.attempt + '_' + case + '.txt')).open('xb') as stream:
            stream.write(log)
        match = re.search(rb'TASK10_LIVE_RESULT:(\{[^\r\n]+\})', log)
        assert match, log.decode(errors='replace')
        result = json.loads(match.group(1))
        results.append(result)
        with (q.ROOT / ('live_' + args.attempt + '_' + case + '.json')).open('x') as stream:
            json.dump(result, stream, indent=2)
        print(json.dumps(result), flush=True)
        assert result['status'] == 'PASS', result
        if case == 'live-reconnect':
            assert len(restarting_receiver.processes) == 2
            assert all((directory / (n + '.mp4')).stat().st_size > 10000
                       for n in ['rtmp_received', 'rtmp_reconnected'])
    finally:
        q.adb('shell', 'am', 'force-stop', q.PACKAGE)
        if receiver:
            try:
                receiver.wait(timeout=10)
            except subprocess.TimeoutExpired:
                receiver.terminate()
                receiver.wait(timeout=5)
        if log_stream:
            log_stream.close()
        if tls_receiver:
            tls_receiver.finish()
        if restarting_receiver:
            restarting_receiver.finish()
assert source_sha == hashlib.sha256(q.adb('exec-out', 'content', 'read', '--uri', source)).hexdigest()
assert journal == q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', 'shared_prefs/capture_journal.xml')
logcat = q.adb('logcat', '-d', '-t', '3000')
with (q.ROOT / ('live_' + args.attempt + '_logcat.txt')).open('xb') as stream:
    stream.write(logcat)
assert key.encode() not in logcat, 'Synthetic key leaked into Android logs'
with (q.ROOT / ('live_' + args.attempt + '_summary.json')).open('x') as stream:
    json.dump({'results': results, 'sourceByteExact': True, 'liveJournalByteExact': True,
               'syntheticKeyAbsentFromLogcat': True, 'sourceSha256': source_sha,
               'receiver': str(directory / 'rtmp_received.mp4') if any(c in args.cases for c in ['live-transport', 'live-reconnect']) else None,
               'untrustedTlsRejected': args.untrusted_tls, 'status': 'PASS'}, stream, indent=2)
