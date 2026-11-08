"""Operate only DocumentsUI on the dedicated QA emulator, retaining outputs."""
import argparse
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

p=argparse.ArgumentParser();p.add_argument('--folder',required=True);p.add_argument('--seconds',type=int,default=180);p.add_argument('--log',type=Path);p.add_argument('--copy-only',action='store_true');args=p.parse_args()
adb='C:/Users/dangh/AppData/Local/Android/Sdk/platform-tools/adb.exe'
def run(*words):return subprocess.check_output([adb,'-s','emulator-5560',*words],text=True,stderr=subprocess.DEVNULL,timeout=15)
assert run('shell','getprop','ro.boot.qemu.avd_name').strip()=='ThreeHRecorder_Task021'
assert re.fullmatch(r'P2P3_QA_[A-Za-z0-9_]+',args.folder)
run('shell','mkdir','-p','/sdcard/Documents/'+args.folder)
if not args.copy_only:
    run('shell','mkdir','-p','/sdcard/Movies/XRecorder/'+args.folder)
    run('push','build/verification/p2_p3/audio/p2_p3_tone_440.wav','/sdcard/Movies/XRecorder/'+args.folder+'/p2_p3_audio_pick.wav')
end=time.monotonic()+args.seconds
stage='tree';last='';entered=False;creating=False
while time.monotonic()<end:
    time.sleep(1)
    if args.log and args.log.exists():
        raw=args.log.read_bytes();content=raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8',errors='replace')
        if 'All tests passed' in content:
            print('Native assertions completed; picker helper stopped',flush=True);break
        if 'Some tests failed' in content:raise SystemExit('Native test failed; picker helper stopped')
    try:
        run('shell','uiautomator','dump','/data/local/tmp/3h_qa_documents.xml')
        tree=ET.fromstring(run('shell','cat','/data/local/tmp/3h_qa_documents.xml'))
    except (subprocess.CalledProcessError,subprocess.TimeoutExpired,ET.ParseError):continue
    allowed=['com.google.android.documentsui','com.android.documentsui','android']
    if stage=='pin':allowed+=['com.google.android.apps.nexuslauncher','com.android.launcher3']
    nodes=[n for n in tree.iter('node') if n.get('package') in allowed]
    if not nodes:continue
    texts=[n.get('text') or n.get('content-desc') for n in nodes]
    signature='|'.join(t for t in texts if t)
    if signature!=last:print(signature[:700],flush=True);last=signature
    def choose(predicate):
        node=next((n for n in nodes if predicate(n) and n.get('enabled')=='true'),None)
        if node is None:return False
        bounds=re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]',node.get('bounds',''))
        if not bounds:return False
        x,y,r,b=map(int,bounds.groups());run('shell','input','tap',str((x+r)//2),str((y+b)//2));return True
    if choose(lambda n:n.get('text')=='ALLOW'):
        if args.copy_only:
            print('New QA folder consent selected; native copy/disconnect assertions continue.',flush=True);break
        stage='audio';continue
    if stage=='audio':
        if choose(lambda n:n.get('text')=='p2_p3_audio_pick.wav'):stage='srt'
        continue
    if stage=='srt':
        if choose(lambda n:n.get('text') in ['SAVE','Save']):print('SRT Save clicked',flush=True);stage='pin'
        continue
    if stage=='pin':
        if choose(lambda n:n.get('clickable')=='true' and n.get('text','').casefold() in ['add','add to home screen','add automatically']):
            print('Launcher pin confirmation clicked',flush=True);break
        continue
    if creating or 'New folder' in texts and any(n.get('class')=='android.widget.EditText' for n in nodes):
        creating=True
        field=next((n for n in nodes if n.get('class')=='android.widget.EditText'),None)
        if field is not None:
            if field.get('text')==args.folder:
                if choose(lambda n:n.get('text') in ['OK','CREATE','Create']):creating=False
            else:
                choose(lambda n:n.get('class')=='android.widget.EditText')
                run('shell','input','keycombination','KEYCODE_CTRL_LEFT','KEYCODE_A')
                run('shell','input','text',args.folder)
        continue
    if entered and choose(lambda n:n.get('text') in ['USE THIS FOLDER','Use this folder']):continue
    if choose(lambda n:n.get('text')==args.folder):entered=True;continue
    if choose(lambda n:n.get('text')=='Documents'):continue
    if choose(lambda n:n.get('text')=='XRecorder' and n.get('resource-id')=='android:id/title'):continue
    if choose(lambda n:n.get('text') in ['Internal storage','sdk_gphone64_x86_64']):continue
    if choose(lambda n:n.get('content-desc') in ['Show roots','Show navigation drawer']):continue
    if choose(lambda n:n.get('content-desc')=='New folder'):creating=True
else:raise SystemExit('Picker automation timeout; no arbitrary UI was clicked')
