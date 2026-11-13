"""Read-only source/storage inventory; outputs are created exclusively."""
import hashlib,json,os,shutil,subprocess,struct,stat
from pathlib import Path

root=Path(__file__).parent
base=json.loads((root/'baseline.json').read_text(encoding='utf8'))
def digest(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
missing=[];changed=[];protected=[]
for name,old in base['hashes'].items():
    p=Path(name)
    if not p.exists():missing.append(name);continue
    same=digest(p)==old
    if not same:changed.append(name)
    if name.startswith(('lib/features/recording/','android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/')) or p.name in ['settings_controller.dart','recording_settings_form.dart','audio_video_settings_screen.dart','MainActivity.kt','EditorPreview.kt']:
        protected.append({'path':name,'unchanged':same})
def inventory(directory):
    total=count=0;skipped=[]
    for here,dirs,files in os.walk(directory,followlinks=False):
        keep=[]
        for d in dirs:
            p=Path(here)/d
            if p.lstat().st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT:skipped.append(str(p))
            else:keep.append(d)
        dirs[:]=keep
        for f in files:
            p=Path(here)/f
            if p.is_symlink():skipped.append(str(p));continue
            try:total+=p.stat().st_size;count+=1
            except FileNotFoundError:skipped.append(str(p))
    return {'logicalBytes':total,'fileCount':count,'skipped':skipped,'allocatedBytes':'NOT MEASURED'}
images=[]
for tab in ['video','photo','edit','settings']:
    p=root/('final_header_'+tab+'_light.png');size=struct.unpack('>II',p.read_bytes()[16:24])
    pixels=subprocess.check_output(['build/task03/ffmpeg/ffmpeg.exe','-v','error','-i',str(p),'-frames:v','1','-f','rawvideo','-pix_fmt','rgb24','pipe:1'])
    pts=[(x,y) for y in range(55,100) for x in range(0,300) if (lambda c:c[0]>100 and c[0]>c[1]+40 and c[0]>c[2]+40)(pixels[(y*size[0]+x)*3:(y*size[0]+x)*3+3])]
    images.append({'tab':tab,'size':size,'brandBoundingBox':([min(x for x,y in pts),min(y for x,y in pts),max(x for x,y in pts)+1,max(y for x,y in pts)+1] if pts else None)})
result={'head':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'branch':subprocess.check_output(['git','branch','--show-current'],text=True).strip(),'status':subprocess.check_output(['git','status','--short'],text=True),'baselineFileCount':len(base['hashes']),'missingBaselineFiles':missing,'changedSinceUI05BStart':changed,'protectedSource':protected,'buildAfter':inventory('build'),'taskEvidence':inventory(root),'taskInstallBackups':inventory('build/verification/uiux05b'),'freeBytesAfter':shutil.disk_usage('D:/').free,'freeBytesBefore':base['freeBytes'],'headerPixels':images,'debugApkSha256':digest('build/app/outputs/flutter-apk/app-debug.apk'),'profileApkSha256':digest('build/app/outputs/flutter-apk/app-profile.apk')}
with (root/'final_host_storage_preservation.json').open('x',encoding='utf8') as f:json.dump(result,f,ensure_ascii=False,indent=2)
print(json.dumps({k:v for k,v in result.items() if k not in ['status','changedSinceUI05BStart','protectedSource']},ensure_ascii=True,indent=2))
