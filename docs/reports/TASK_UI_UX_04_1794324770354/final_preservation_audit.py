"""Read-only verification; every new host artifact uses exclusive creation."""
import qa04 as q,pathlib,json,hashlib,tarfile,io,subprocess,os,shutil,datetime

def digest(data):return hashlib.sha256(data).hexdigest()
def write(name,data):
 with (q.ROOT/name).open('xb') as f:f.write(data)

b=q.BASE
hashes=[]
for name,before in b['hashes'].items():
 after=digest(pathlib.Path(name).read_bytes())
 hashes.append({'path':name,'before':before,'after':after,'equal':before==after})
allowed='android/app/src/main/kotlin/com/xrecorder/xrecorder/editor/EditorPreview.kt'
assert all(v['equal'] or v['path']==allowed for v in hashes)
private=q.adb('exec-out','run-as','com.xrecorder.xrecorder','tar','cf','-','shared_prefs','files/projects')
write('private_preferences_projects_final.tar',private)
old=tarfile.open(q.ROOT/'private_preferences_projects_before.tar')
new=tarfile.open(fileobj=io.BytesIO(private))
previous={m.name:old.extractfile(m).read() for m in old.getmembers() if m.isfile()}
current={m.name:new.extractfile(m).read() for m in new.getmembers() if m.isfile()}
comparisons=[{'path':name,'equal':data==current.get(name),'beforeSha256':digest(data),'afterSha256':digest(current[name]) if name in current else None} for name,data in previous.items()]
assert all(v['equal'] for v in comparisons if 'files/projects/' in v['path'])
media=[]
for path,expected in [('/sdcard/Download/UI02C_1794308051935/slider_fixture.png','399d4169a5a322c63d8fee240ff29c91893ccd8c854262a1afc09e2bcfd8b8ff'),('/sdcard/Download/UI02C_1794308051935/sort_fixture.png','c656e0de5f2ab3262b038e61ca09cbe3342f764d855e64de7ac5846b4b45eaf9')]:
 actual=q.adb('shell','sha256sum',path).decode().split()[0];assert actual==expected
 media.append({'path':path,'sha256':actual,'matchesBaseline':True})
write('final_saf_permissions.txt',q.adb('shell','dumpsys','activity','permissions'))
write('final_gfxinfo.txt',q.adb('shell','dumpsys','gfxinfo','com.xrecorder.xrecorder','framestats'))
write('final_meminfo.txt',q.adb('shell','dumpsys','meminfo','com.xrecorder.xrecorder'))
config={
 'size':q.adb('shell','wm','size').decode().strip(),
 'density':q.adb('shell','wm','density').decode().strip(),
 'rotationAuto':q.adb('shell','settings','get','system','accelerometer_rotation').decode().strip(),
 'rotation':q.adb('shell','settings','get','system','user_rotation').decode().strip(),
 'fontScale':q.adb('shell','settings','get','system','font_scale').decode().strip(),
 'animator':q.adb('shell','settings','get','global','animator_duration_scale').decode().strip(),
}
assert {k:v.replace('\r','') for k,v in config.items()}=={k:v.replace('\r','') for k,v in b['configuration'].items()},(config,b['configuration'])
apk=digest(pathlib.Path('build/app/outputs/flutter-apk/app-debug.apk').read_bytes())
installed=q.adb('shell','pm','path','com.xrecorder.xrecorder').decode().strip().removeprefix('package:')
installedHash=q.adb('shell','sha256sum',installed).decode().split()[0]
assert installedHash==apk
write('final_git_status.txt',subprocess.check_output(['git','status','--short']))
write('final_staged_files.txt',subprocess.check_output(['git','diff','--cached','--name-only']))
result={'time':datetime.datetime.now().isoformat(),'avd':q.adb('shell','getprop','ro.boot.qemu.avd_name').decode().strip(),'head':subprocess.check_output(['git','rev-parse','HEAD']).decode().strip(),'sourceHashes':hashes,'originalPrivateFiles':comparisons,'addedPrivateFiles':sorted(set(current)-set(previous)),'mediaHashes':media,'configuration':config,'apkSha256':apk,'installedApkSha256':installedHash}
write('final_preservation.json',json.dumps(result,ensure_ascii=False,indent=2).encode())
print(json.dumps({'sourceDifferences':[v['path'] for v in hashes if not v['equal']],'privateDifferences':[v['path'] for v in comparisons if not v['equal']],'addedPrivateFiles':result['addedPrivateFiles']},indent=2))
# One logical-size walk, excluding all reparse points; do not hash build/.
size=count=0;stack=[pathlib.Path('build')]
while stack:
 with os.scandir(stack.pop()) as entries:
  for entry in entries:
   stat=entry.stat(follow_symlinks=False)
   if stat.st_file_attributes & 1024:continue
   if entry.is_dir(follow_symlinks=False):stack.append(pathlib.Path(entry.path))
   elif entry.is_file(follow_symlinks=False):size+=stat.st_size;count+=1
evidence=sum(p.stat().st_size for p in q.ROOT.rglob('*') if p.is_file())
storage={'beforeBuildBytes':b['buildBytes'],'afterBuildBytes':size,'buildDeltaBytes':size-b['buildBytes'],'buildFiles':count,'beforeFreeBytes':b['freeBytes'],'afterFreeBytes':shutil.disk_usage('.').free,'newEvidenceBytesBeforeFinalReport':evidence,'measure':'logical bytes; excludes reparse points; allocated sparse AVD size not measured'}
write('final_storage.json',json.dumps(storage,indent=2).encode());print(json.dumps(storage,indent=2))
