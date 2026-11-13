"""Read-only comparison with the UI06 archive and retained-source manifest."""
import qa06 as q
import pathlib,json,tarfile,hashlib,subprocess,re,sys
suffix=sys.argv[1] if len(sys.argv)>1 else 'acceptance'
manifest=pathlib.Path('build/verification/uiux06/baseline_profile_20261111_1756/backup_private_manifest_v1.json')
archive=tarfile.open(json.loads(manifest.read_text())['hostPath'],'r:')
rows=[];oldQueue=None
for member in archive.getmembers():
    name=member.name.removeprefix('./')
    if not member.isfile() or not name.startswith(('shared_prefs/','files/projects/')) and name!='files/export_jobs.json':continue
    before=archive.extractfile(member).read()
    after=q.adb('exec-out','run-as','com.xrecorder.xrecorder','cat',name)
    if name=='files/export_jobs.json':
        oldQueue=json.loads(before);newQueue=json.loads(after)
        rows.append({'path':name,'oldRecordsPreserved':all(old in newQueue for old in oldQueue),'oldCount':len(oldQueue),'currentCount':len(newQueue),'addedJobIds':[j['id'] for j in newQueue if j['id'] not in {old['id'] for old in oldQueue}]})
    else:
        rows.append({'path':name,'baselineSha256':hashlib.sha256(before).hexdigest(),'currentSha256':hashlib.sha256(after).hexdigest(),'unchanged':before==after})
sources=[]
for name,digest in json.loads((q.ROOT/'retained_media_baseline.json').read_text()).items():
    assert re.fullmatch(r'/sdcard/(Pictures|Movies)/XRecorder/[A-Za-z0-9_.-]+',name)
    actual=q.adb('shell','sha256sum',name).decode().split()[0]
    sources.append({'path':name,'baselineSha256':digest,'currentSha256':actual,'unchanged':digest==actual})
initial=json.loads((q.ROOT/'device_baseline.json').read_text())
config={k:q.adb('shell','settings','get','system' if k in ['font_scale','user_rotation','accelerometer_rotation'] else 'global',k).decode().strip() for k in initial['configuration']}
uid=q.adb('shell','cmd','package','list','packages','-U','com.xrecorder.xrecorder').decode()
apk=q.adb('shell','pm','path','com.xrecorder.xrecorder').decode().strip().removeprefix('package:')
assert apk.startswith('/data/app/') and apk.endswith('/base.apk') and re.fullmatch(r'[A-Za-z0-9_./=~+-]+',apk)
installedSha=q.adb('shell','sha256sum',apk).decode().split()[0]
expectedManifest=sys.argv[2] if len(sys.argv)>2 else 'acceptance_apk_identity.json'
expectedSha=json.loads((q.ROOT/expectedManifest).read_text())['debug']['sha256']
projectPaths=q.adb('shell','run-as','com.xrecorder.xrecorder','find','files/projects','-name','*.json').decode().splitlines()
oldProjects={r['path'] for r in rows if r['path'].startswith('files/projects/')}
created=[]
for path in projectPaths:
    if path in oldProjects:continue
    value=json.loads(q.adb('exec-out','run-as','com.xrecorder.xrecorder','cat',path))
    created.append({'file':path,'title':value['title'],'clips':len(value['clips'])})
pid=q.adb('shell','pidof','com.xrecorder.xrecorder').decode().strip();assert pid.isdigit()
with (q.ROOT/(suffix+'_app_logcat.txt')).open('xb') as f:f.write(q.adb('logcat','-d','--pid='+pid,'-t','1800'))
with (q.ROOT/(suffix+'_uri_permissions.txt')).open('xb') as f:f.write(q.adb('shell','dumpsys','activity','uri-permissions'))
report={'avd':q.adb('shell','getprop','ro.boot.qemu.avd_name').decode().strip(),'serial':'emulator-5570','uid':uid,'uidUnchanged':uid==initial['packages'],'privateData':rows,'retainedMedia':sources,'newQaProjects':created,'configuration':config,'configurationMatchesBaseline':config==initial['configuration'],'display':q.adb('shell','wm','size').decode(),'density':q.adb('shell','wm','density').decode(),'installedApkSha256':installedSha,'expectedApkSha256':expectedSha,'correctApkInstalled':installedSha==expectedSha,'scope':'12 immutable private records including capture journal, plus original export queue rows and four retained public sources. No complete hashing claim for all public device media. No SAF grant requests/revocations; existing SAF project preview tested separately.'}
report['scope']='11 immutable private files, original queue rows and four public sources. P1 journal runtime countdown delta is recorded separately and is NOT byte-identical.'
report['journalByteIdentity']=next(r['unchanged'] for r in rows if r['path']=='shared_prefs/capture_journal.xml')
report['journalReviewEvidence']='capture_journal_runtime_comparison.json'
with (q.ROOT/('data_preservation_'+suffix+'.json')).open('x',encoding='utf8') as f:json.dump(report,f,indent=2)
assert all(r.get('unchanged',r.get('oldRecordsPreserved',False)) for r in rows if r['path']!='shared_prefs/capture_journal.xml')
assert all(r['unchanged'] for r in sources)
assert report['uidUnchanged'] and report['configurationMatchesBaseline'] and report['correctApkInstalled']
assert report['display']==initial['size'] and report['density']==initial['density']
print('Original drafts/settings/onboarding/media/queue, UID, APK and configuration PASS; P1 journal byte identity',report['journalByteIdentity'],'new QA projects',len(created),flush=True)
