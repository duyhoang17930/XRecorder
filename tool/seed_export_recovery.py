"""Only for export_recovery_test.dart on a disposable test install; adb run-as required."""
import json
import os
import subprocess
import time
from pathlib import Path

adb = Path(os.environ['LOCALAPPDATA']) / 'Android/sdk/platform-tools/adb.exe'
prefix = [str(adb), '-s', 'emulator-5556', 'shell', 'run-as', 'com.xrecorder.xrecorder']
project = {'version': 1, 'id': 'recovery_ready', 'title': 'Recovery fixture', 'clips': [], 'updatedAt': 0}
job = {'id': '00000000-0000-4000-8000-000000000001', 'state': 'running', 'progress': 20, 'project': project}
for _ in range(120):
    exists = subprocess.run(prefix + ['test', '-d', 'files/projects'], capture_output=True).returncode == 0
    if exists:
        break
    time.sleep(1)
else:
    raise SystemExit('Test install not ready')
# Abort rather than replace any existing export history.
if subprocess.run(prefix + ['test', '-f', 'files/export_jobs.json'], capture_output=True).returncode == 0:
    raise SystemExit('Existing export history: refusing to overwrite')
def write(path, content):
    subprocess.run(prefix + ['sh', '-c', f'"cat > {path}"'], input=content.encode(), check=True)
write('cache/export_' + job['id'] + '.mp4', 'incomplete test export')
write('cache/recovery_preserved.txt', 'unrelated file must survive')
write('files/export_jobs.json', json.dumps([job]))
write('files/projects/recovery_ready.json', json.dumps(project))
for _ in range(120):
    result = subprocess.run(prefix + ['cat', 'files/export_jobs.json'], capture_output=True)
    if result.returncode == 0 and json.loads(result.stdout)[0]['state'] == 'failed':
        assert subprocess.run(prefix + ['test', '-f', 'cache/export_' + job['id'] + '.mp4']).returncode != 0
        assert subprocess.run(prefix + ['cat', 'cache/recovery_preserved.txt'], capture_output=True).stdout == b'unrelated file must survive'
        print('Recovery removed only the job temporary; unrelated file preserved.')
        break
    time.sleep(.25)
else:
    raise SystemExit('Recovery not observed')
