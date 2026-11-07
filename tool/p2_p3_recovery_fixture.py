"""Inject a crash fixture only into the newly-created test draft on the dedicated AVD."""
import argparse
import json
import re
import subprocess
import time
from pathlib import Path

parser=argparse.ArgumentParser()
parser.add_argument('--log',type=Path,required=True)
parser.add_argument('--serial',default='emulator-5560')
args=parser.parse_args()

def adb(*values, check=True):
    return subprocess.run(['adb','-s',args.serial,*values],check=check,capture_output=True)

assert adb('shell','getprop','ro.boot.qemu.avd_name').stdout.decode().strip()=='ThreeHRecorder_Task021'
package='com.xrecorder.xrecorder'
assert b'.recording.CaptureService' not in adb('shell','dumpsys','activity','services',package).stdout
deadline=time.monotonic()+180
while time.monotonic()<deadline:
    raw=args.log.read_bytes() if args.log.exists() else b''
    content=raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8',errors='replace')
    match=re.search(r'P2_P3_RECOVERY_READY=(m6_recovery_[0-9]{10,20})',content)
    if match:
        break
    time.sleep(1)
else:
    raise SystemExit('Test did not produce a fresh recovery fixture; nothing changed.')
draft_id=match.group(1)
assert f'P2_P3_RECOVERY_COMPLETE={draft_id}' not in content, 'Test already completed; nothing changed.'
source=f'files/projects/{draft_id}.json'
backup=source+'.bak'
unreadable=f'files/projects/{draft_id}_unreadable.json'
data=adb('shell','run-as',package,'cat',source).stdout
assert json.loads(data)['id']==draft_id
assert adb('shell','run-as',package,'test','-e',backup,check=False).returncode==1
assert adb('shell','run-as',package,'test','-e',unreadable,check=False).returncode==1
adb('shell','run-as',package,'mv',source,backup)
# Only this run's empty fixture is unreadable; other draft/media permissions are unchanged.
adb('shell','run-as',package,'touch',unreadable)
adb('shell','run-as',package,'chmod','000',unreadable)
print(json.dumps({'fixture':draft_id,'backupOnly':True,'emptyDocumentRetained':True}))
