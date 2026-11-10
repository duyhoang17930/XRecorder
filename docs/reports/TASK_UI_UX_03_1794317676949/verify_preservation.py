import qa03 as q,pathlib,hashlib,json,tarfile,subprocess,os,shutil,stat,re
root=pathlib.Path.cwd()
sha=lambda b:hashlib.sha256(b).hexdigest()
result={'head':subprocess.check_output(['git','rev-parse','HEAD']).decode().strip()}
result['protectedSource']={p:{'expected':h,'actual':sha((root/p).read_bytes())} for p,h in q.BASE['hashes'].items()}
result['protectedSourceUnchanged']=all(v['expected']==v['actual'] for v in result['protectedSource'].values())
with tarfile.open(q.ROOT/'preferences_before.tar') as backup:
 result['preferences']={}
 for member in backup.getmembers():
  if not member.isfile():continue
  before=backup.extractfile(member).read()
  after=q.adb('exec-out','run-as','com.xrecorder.xrecorder','cat',member.name)
  result['preferences'][member.name]={'byteExact':before==after,'beforeSha256':sha(before),'afterSha256':sha(after)}
  with (q.ROOT/('final_'+pathlib.Path(member.name).name)).open('xb') as f:f.write(after)
trusted=json.loads((root/'docs/reports/TASK_UI_UX_02C_1794306547967/handoff_manifest.json').read_text(encoding='utf8'))
result['fixtures']={}
for name,expected in trusted['fixtureHostHashes'].items():
 actual=q.adb('shell','sha256sum','/sdcard/Download/UI02C_1794308051935/'+name).decode().split()[0]
 result['fixtures'][name]={'expected':expected,'actual':actual,'matches':actual==expected}
project='files/projects/project_1794319906023720.json'
data=q.adb('exec-out','run-as','com.xrecorder.xrecorder','cat',project)
with (q.ROOT/'retained_QA_project.json').open('xb') as f:f.write(data)
result['retainedQAProject']={'path':project,'sha256':sha(data),'document':json.loads(data)}
result['configuration']={
 'size':q.adb('shell','wm','size').decode().strip(),
 'density':q.adb('shell','wm','density').decode().strip(),
 'rotationAuto':q.adb('shell','settings','get','system','accelerometer_rotation').decode().strip(),
 'rotation':q.adb('shell','settings','get','system','user_rotation').decode().strip(),
 'fontScale':q.adb('shell','settings','get','system','font_scale').decode().strip(),
 'animator':q.adb('shell','settings','get','global','animator_duration_scale').decode().strip(),
}
result['configurationRestored']=result['configuration']==q.BASE['configuration']
apk=root/'build/app/outputs/flutter-apk/app-debug.apk'
result['apk']={'size':apk.stat().st_size,'sha256':sha(apk.read_bytes())}
installed=q.adb('shell','pm','path','com.xrecorder.xrecorder').decode().strip().split('package:')[-1]
result['apk']['installedSha256']=q.adb('shell','sha256sum',installed).decode().split()[0]
result['apk']['installedMatches']=result['apk']['sha256']==result['apk']['installedSha256']
uri=q.adb('shell','dumpsys','uri_grants')
with (q.ROOT/'final_uri_grants.txt').open('xb') as f:f.write(uri)
pid=q.adb('shell','pidof','com.xrecorder.xrecorder').decode().strip()
if pid:
 logs=q.adb('logcat','-d','--pid='+pid,'-t','3000')
 with (q.ROOT/'final_runtime_log.txt').open('xb') as f:f.write(logs)
 result['runtimeErrors']=re.findall(r'A RenderFlex overflowed[^\r\n]*|EXCEPTION CAUGHT BY[^\r\n]*|FATAL EXCEPTION[^\r\n]*',logs.decode(errors='replace'))
result['gitStatus']=subprocess.check_output(['git','status','--short']).decode()
diff=subprocess.run(['git','diff','--check'],capture_output=True)
result['diffCheck']={'exit':diff.returncode,'stdout':diff.stdout.decode(),'stderr':diff.stderr.decode()}
def logical_size(path):
 total=0;count=0;skipped=[];stack=[path]
 while stack:
  directory=stack.pop()
  with os.scandir(directory) as entries:
   for entry in entries:
    info=entry.stat(follow_symlinks=False)
    if getattr(info,'st_file_attributes',0)&0x400:
     skipped.append(entry.path);continue
    if stat.S_ISDIR(info.st_mode):stack.append(entry.path)
    elif stat.S_ISREG(info.st_mode):total+=info.st_size;count+=1
 return {'logicalBytes':total,'files':count,'reparsePointsSkipped':skipped}
result['buildBeforeBytes']=140688905131
result['freeBeforeBytes']=31345229824
result['buildAfter']=logical_size(root/'build')
result['evidenceSize']=logical_size(q.ROOT)
result['diskFreeAfterBytes']=shutil.disk_usage(root).free
with (q.ROOT/'preservation_and_storage_final.json').open('x',encoding='utf8') as f:json.dump(result,f,ensure_ascii=False,indent=2)
print(json.dumps({k:v for k,v in result.items() if k in ['protectedSourceUnchanged','preferences','configurationRestored','apk','runtimeErrors','buildAfter','evidenceSize','diskFreeAfterBytes']},ensure_ascii=False,indent=2))
