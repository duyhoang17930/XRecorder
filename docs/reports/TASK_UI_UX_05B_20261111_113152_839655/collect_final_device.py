"""Read-only final identity, preferences, fixture and APK checks."""
import qa05b as q
import hashlib,json,pathlib

private={name:q.adb('shell','run-as','com.xrecorder.xrecorder','sha256sum',name).decode().split()[0] for name in q.BASE['privateHashes']}
inputs={
 '/sdcard/Download/UI02C_1794308051935/slider_fixture.png':'399d4169a5a322c63d8fee240ff29c91893ccd8c854262a1afc09e2bcfd8b8ff',
 '/sdcard/Download/UI02C_1794308051935/sort_fixture.png':'c656e0de5f2ab3262b038e61ca09cbe3342f764d855e64de7ac5846b4b45eaf9',
}
retained=json.loads((q.ROOT/'retained_qa_fixture_before.json').read_text(encoding='utf8'))
inputs.update({p:sha.split()[0] for p,sha in retained.items() if p.startswith('/sdcard/')})
external=[{'path':p,'before':sha,'after':q.adb('shell','sha256sum',p).decode().split()[0]} for p,sha in inputs.items()]
packagePath=q.adb('shell','pm','path','com.xrecorder.xrecorder').decode().strip().split('package:',1)[1]
deviceApk=q.adb('shell','sha256sum',packagePath).decode().split()[0]
hostApk=hashlib.sha256(pathlib.Path('build/app/outputs/flutter-apk/app-debug.apk').read_bytes()).hexdigest()
config={key:q.adb('shell','settings','get',namespace,key).decode().strip() for namespace,key in [('system','font_scale'),('system','user_rotation'),('system','accelerometer_rotation'),('global','transition_animation_scale'),('global','animator_duration_scale')]}
config['wmSize']=q.adb('shell','wm','size').decode().strip();config['wmDensity']=q.adb('shell','wm','density').decode().strip()
result={'avd':q.adb('shell','getprop','ro.boot.qemu.avd_name').decode().strip(),'packages':q.adb('shell','cmd','package','list','packages','-U','com.xrecorder.xrecorder').decode().strip(),'privateHashes':private,'differentPrivateHashes':[name for name,sha in private.items() if sha!=q.BASE['privateHashes'][name]],'external':external,'configuration':config,'installedApkSha256':deviceApk,'hostApkSha256':hostApk,'installedApkMatches':deviceApk==hostApk}
with (q.ROOT/'final_device_preservation.json').open('x',encoding='utf8') as f:json.dump(result,f,ensure_ascii=False,indent=2)
pid=q.adb('shell','pidof','com.xrecorder.xrecorder').decode().strip()
with (q.ROOT/'final_main_process_logcat.txt').open('xb') as f:f.write(q.adb('logcat','-d','--pid='+pid,timeout=60))
print(json.dumps(result,ensure_ascii=True,indent=2))
assert result['differentPrivateHashes']==[]
assert all(item['before']==item['after'] for item in external)
assert result['installedApkMatches']
