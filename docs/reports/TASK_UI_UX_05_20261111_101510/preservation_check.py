import qa05 as q
import json,hashlib,tarfile,pathlib,shutil,os,stat

baseline=json.loads((q.ROOT/'device_baseline.json').read_text(encoding='utf8'))
checks={}
for name,sha in baseline['privateHashes'].items():
    data=q.adb('exec-out','run-as','com.xrecorder.xrecorder','cat',name)
    checks[name]={'before':sha,'after':hashlib.sha256(data).hexdigest(),'exact':hashlib.sha256(data).hexdigest()==sha}
fixtures={
 '/sdcard/Download/UI02C_1794308051935/slider_fixture.png':'399d4169a5a322c63d8fee240ff29c91893ccd8c854262a1afc09e2bcfd8b8ff',
 '/sdcard/Download/UI02C_1794308051935/sort_fixture.png':'c656e0de5f2ab3262b038e61ca09cbe3342f764d855e64de7ac5846b4b45eaf9',
}
for name,sha in fixtures.items():
    current=q.adb('shell','sha256sum',name).decode().split()[0]
    checks[name]={'before':sha,'after':current,'exact':current==sha}
configuration={
 'size':q.adb('shell','wm','size').decode().strip(),
 'density':q.adb('shell','wm','density').decode().strip(),
 'rotationAuto':q.adb('shell','settings','get','system','accelerometer_rotation').decode().strip(),
 'rotation':q.adb('shell','settings','get','system','user_rotation').decode().strip(),
 'fontScale':q.adb('shell','settings','get','system','font_scale').decode().strip(),
 'animator':q.adb('shell','settings','get','global','animator_duration_scale').decode().strip(),
}
identity=q.adb('shell','cmd','package','list','packages','-U','com.xrecorder.xrecorder').decode().strip()
result={'hashes':checks,'allExact':all(v['exact'] for v in checks.values()),'configuration':configuration,'configurationRestored':configuration==baseline['configuration'],'packageIdentity':identity,'identityUnchanged':identity==baseline['identity'],'transitionScale':q.adb('shell','settings','get','global','transition_animation_scale').decode().strip()}
with (q.ROOT/'device_preservation_final.json').open('x',encoding='utf8') as f:json.dump(result,f,indent=2)
print(json.dumps(result))

root=pathlib.Path.cwd();build_bytes=0;build_files=0;skipped=[]
for folder,dirs,files in os.walk(root/'build',followlinks=False):
    kept=[]
    for name in dirs:
        path=pathlib.Path(folder)/name
        if path.lstat().st_file_attributes&stat.FILE_ATTRIBUTE_REPARSE_POINT:skipped.append(str(path))
        else:kept.append(name)
    dirs[:]=kept
    for name in files:
        info=(pathlib.Path(folder)/name).lstat()
        if info.st_file_attributes&stat.FILE_ATTRIBUTE_REPARSE_POINT:continue
        build_bytes+=info.st_size;build_files+=1
evidence=sum(f.stat().st_size for f in q.ROOT.rglob('*') if f.is_file())
b=json.loads((q.ROOT/'baseline.json').read_text(encoding='utf8'))
storage={'buildBeforeBytes':b['buildBytes'],'buildAfterBytes':build_bytes,'buildGrowthBytes':build_bytes-b['buildBytes'],'buildFilesAfter':build_files,'freeBeforeBytes':b['freeBytes'],'freeAfterBytes':shutil.disk_usage(root).free,'evidenceBytes':evidence,'skippedReparseDirectories':skipped,'measurement':'logical size, not allocated size; drive free may include unrelated activity'}
with (q.ROOT/'storage_final.json').open('x',encoding='utf8') as f:json.dump(storage,f,indent=2)
print(json.dumps(storage))
