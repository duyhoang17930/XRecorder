"""Run the tiny framework-only test APK on the isolated16KB QA AVD."""
import argparse, json, re, subprocess, time
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, help='New evidence directory; existing results are preserved.')
args = parser.parse_args()
ROOT = args.output or Path(f'build/verification/task07/native_accessibility_{int(time.time()*1000)}')
ROOT.mkdir(parents=True, exist_ok=False)
ADB = str(Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe')
PKG = 'com.xrecorder.xrecorder'
TB = 'com.google.android.marvin.talkback'
def device(*args):
    return subprocess.check_output([ADB,'-s','emulator-5564',*args],timeout=80,stderr=subprocess.PIPE)
assert device('shell','getprop','ro.boot.qemu.avd_name').decode().strip() == 'ThreeHRecorder_TASK07_16KB'
assert device('shell','getconf','PAGESIZE').decode().strip() == '16384'
keys=['enabled_accessibility_services','accessibility_enabled','touch_exploration_enabled']
def flags(): return {key:device('shell','settings','get','secure',key).decode().strip() for key in keys}
def permission():
    state=device('shell','dumpsys','package',TB).decode()
    return re.search(r'android.permission.POST_NOTIFICATIONS: granted=\w+, flags=\[[^\]]*\]',state).group(0)
original,notification=flags(),permission()
assert original[keys[0]] in ('null','')
before=device('exec-out','run-as',PKG,'cat','files/transcription_jobs.json')
assert not any(job['state'] in ('queued','running') for job in json.loads(before)), 'Pre-existing speech work is active'
assert 'CaptureService' not in device('shell','dumpsys','activity','services',PKG).decode(), 'Pre-existing capture service is active'
result={'original':original,'notificationOriginal':notification,'pageSize':16384}
device('install','-r','-t','build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk')
try:
    if 'granted=false' in notification: device('shell','pm','grant',TB,'android.permission.POST_NOTIFICATIONS')
    device('shell','settings','put','secure',keys[0],TB+'/'+TB+'.TalkBackService')
    device('shell','settings','put','secure',keys[1],'1')
    device('shell','settings','put','secure',keys[2],'1')
    time.sleep(5)
    active=device('shell','dumpsys','accessibility').decode()
    (ROOT/'service_before.txt').write_text(active,encoding='utf8')
    assert 'Bound services:{Service[label=TalkBack' in active
    output=device('shell','am','instrument','-w',PKG+'.test/'+PKG+'.qa.Task07AccessibilityInstrumentation').decode(errors='replace')
    (ROOT/'instrumentation.txt').write_text(output,encoding='utf8')
    match=re.search(r'TASK07_NATIVE_ACCESSIBILITY=(\{[^\n]+\})',output)
    assert match, output
    report=json.loads(match.group(1));assert report['passed']
    folder=report['evidenceDirectory'];assert re.fullmatch(r'/data/user/0/com\.xrecorder\.xrecorder/files/task07_native_a11y_\d+',folder)
    for filename in ['result.json',*[f'focus_{i}.png' for i in range(4)]]:
        (ROOT/filename).write_bytes(device('exec-out','run-as',PKG,'cat',folder+'/'+filename))
    active=device('shell','dumpsys','accessibility').decode()
    (ROOT/'service_after.txt').write_text(active,encoding='utf8')
    result.update(report)
    result['talkBackRemainedBound']='Bound services:{Service[label=TalkBack' in active
    result['touchExplorationStillEnabled']='touchExplorationEnabled=true' in active
    assert result['talkBackRemainedBound'] and result['touchExplorationStillEnabled']
    assert device('exec-out','run-as',PKG,'cat','files/transcription_jobs.json') == before
    result['oldJobJournalByteExact']=True
finally:
    for key,value in original.items():
        if value=='null':device('shell','settings','delete','secure',key)
        else:device('shell','settings','put','secure',key,value)
    if 'granted=false' in notification:device('shell','pm','revoke',TB,'android.permission.POST_NOTIFICATIONS')
    result['restored']=flags();result['notificationRestored']=permission()
    result['flagsRestoredExactly']=result['restored']==original
    result['notificationRestoredExactly']=result['notificationRestored']==notification
    (ROOT/'host_result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
    assert result['flagsRestoredExactly'] and result['notificationRestoredExactly']
print(f'Native main/TalkBack4 actual focus targets PASS; journal and exact flags/permission retained. Report: {ROOT}/host_result.json')
