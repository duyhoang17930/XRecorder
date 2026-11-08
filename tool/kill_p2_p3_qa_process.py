"""Kill only the verified idle-capture QA app after a real export has started."""
import json
from pathlib import Path
import subprocess
import time
import sys
import shlex

adb='C:/Users/dangh/AppData/Local/Android/Sdk/platform-tools/adb.exe'
def command(*words):return subprocess.check_output([adb,'-s','emulator-5560',*words],text=True,encoding='utf-8')
assert command('shell','getprop','ro.boot.qemu.avd_name').strip()=='ThreeHRecorder_Task021'
assert 'CaptureService' not in command('shell','dumpsys','activity','services','com.xrecorder.xrecorder'),'Capture is active; refusing process kill'
if '--publication-replay' in sys.argv:
    root=Path('build/verification/final_p2_p3/publication');root.mkdir(parents=True,exist_ok=True)
    expected=json.loads((root/'before/emulator_verification.json').read_text(encoding='utf-8'))
    raw=command('shell','run-as','com.xrecorder.xrecorder','cat','files/export_jobs.json')
    rows=json.loads(raw)
    assert all(j['state'] not in ['running','queued','finalizing'] for j in rows), 'Another export is active'
    target=next(j for j in rows if j['id']==expected['jobId'])
    assert target['project']['id']==expected['projectId'] and target['project']['title']=='publication_qa'
    assert target['state']=='completed' and target['uri']==expected['uri']
    others=json.dumps([j for j in rows if j['id']!=target['id']],sort_keys=True)
    (root/'journal_before.json').write_text(raw,encoding='utf-8')
    command('shell','am','force-stop','com.xrecorder.xrecorder')
    target['state']='finalizing';target['pending']=expected['uri'];target.pop('uri')
    assert json.dumps([j for j in rows if j['id']!=target['id']],sort_keys=True)==others
    injected=root/'journal_injected.json'
    injected.write_text(json.dumps(rows),encoding='utf-8')
    # File-sync avoids stdin truncation seen with older Android shell transports.
    stage='/data/local/tmp/3h_quality_publication.json'
    subprocess.run([adb,'-s','emulator-5560','push',str(injected),stage],check=True,capture_output=True)
    script='cp '+stage+' files/export_jobs.quality_new && mv files/export_jobs.quality_new files/export_jobs.json'
    command('shell','run-as','com.xrecorder.xrecorder','sh','-c',shlex.quote(script))
    assert json.loads(command('shell','run-as','com.xrecorder.xrecorder','cat','files/export_jobs.json'))==rows, 'Injected checkpoint read-back differs'
    (root/'injection.json').write_text(json.dumps({'jobId':target['id'],'uri':expected['uri'],'otherRowsPreserved':True,'injectedReadBackVerified':True,'action':'Simulated finalizing checkpoint for this QA job only; actual process stopped and restarted separately. Published media not modified.'},indent=2),encoding='utf-8')
    print('Publication replay checkpoint prepared; original source and published output retained')
    raise SystemExit(0)
if '--io-fault' in sys.argv:
    original=command('shell','run-as','com.xrecorder.xrecorder','stat','-c','%a','files').strip()
    assert original.isdigit() and len(original) in (3,4)
    for _ in range(1200):
        jobs=json.loads(command('shell','run-as','com.xrecorder.xrecorder','cat','files/export_jobs.json'))
        job=next((j for j in reversed(jobs) if j['project']['title']=='io_fault_qa' and j['state'] in ['queued','running']),None)
        if job:break
        time.sleep(.1)
    else:raise SystemExit('No running IO-fault QA job; permissions unchanged')
    root=Path('build/verification/p2_p3/process/io');root.mkdir(parents=True,exist_ok=True)
    record={'jobId':job['id'],'originalFilesMode':original,'injection':'EACCES on export journal parent, with device-side10s restoration watchdog','captureInactive':True}
    (root/'injection.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
    script=f'(sleep 10; chmod {original} files) >/dev/null 2>&1 & chmod 500 files'
    try:
        command('shell','run-as','com.xrecorder.xrecorder','sh','-c',shlex.quote(script))
        print('Injected journal write failure; watchdog restores permissions in10s',flush=True)
        time.sleep(12)
    finally:
        command('shell','run-as','com.xrecorder.xrecorder','chmod',original,'files')
        record['restored']=True;(root/'injection.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
    raise SystemExit(0)
for _ in range(30):
    jobs=json.loads(command('shell','run-as','com.xrecorder.xrecorder','cat','files/export_jobs.json'))
    job=next((j for j in reversed(jobs) if j['project']['title'].startswith('process_qa_')),None)
    if job and job['state']=='running':
        temporary=f"cache/export_{job['id']}.mp4"
        try:
            size=int(command('shell','run-as','com.xrecorder.xrecorder','stat','-c','%s',temporary).strip())
            if size>8192:break
        except (subprocess.CalledProcessError,ValueError):pass
    time.sleep(.5)
else:raise SystemExit('No running QA export with real encoder output; no process was killed')
root=Path('build/verification/p2_p3/process');root.mkdir(parents=True,exist_ok=True)
before={'job':job,'temporaryBytes':size,'captureInactive':True,'action':'am force-stop com.xrecorder.xrecorder on ThreeHRecorder_Task021 only'}
(root/'before_kill.json').write_text(json.dumps(before,indent=2),encoding='utf-8')
command('shell','am','force-stop','com.xrecorder.xrecorder')
print('Killed dedicated QA process with encoder output bytes:',size)
