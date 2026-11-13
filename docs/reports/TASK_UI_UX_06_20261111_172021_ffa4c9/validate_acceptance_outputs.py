import qa06 as q
import pathlib,json,subprocess,hashlib,re,struct
ff=pathlib.Path('build/task03/ffmpeg/ffmpeg.exe').resolve();probe=ff.with_name('ffprobe.exe')
def save(name,data):
    with (q.ROOT/name).open('xb') as f:f.write(data)
def decode(path):
    result=subprocess.run([str(ff),'-v','error','-xerror','-i',str(path),'-f','null','-'],capture_output=True,timeout=90)
    assert result.returncode==0 and not result.stderr.strip(),result.stderr
jobs=json.loads(q.adb('exec-out','run-as','com.xrecorder.xrecorder','cat','files/export_jobs.json'))
projectId=json.loads((q.ROOT/'acceptance_video_project.json').read_text(encoding='utf8'))['project']['id']
job=next(j for j in jobs if j['project']['id']==projectId)
assert job['state']=='completed' and job['progress']==100
assert len(job['project']['clips'])==3 and job['project']['clips'][-1]['isImage']
row=q.adb('shell','content','query','--uri',job['uri'],'--projection','_data:is_pending').decode()
assert 'is_pending=0' in row
remote=re.search(r'_data=(.*?), is_pending',row)[1]
video=q.adb('exec-out','cat',remote);save('acceptance_output.mp4',video)
path=q.ROOT/'acceptance_output.mp4';decode(path)
info=json.loads(subprocess.check_output([str(probe),'-v','error','-count_frames','-show_streams','-show_format','-of','json',str(path)]))
expected=sum(c['outMs']-c['inMs'] for c in job['project']['clips'])/1000/job['project']['effects']['speed']
assert abs(float(info['format']['duration'])-expected)<.15
frames=json.loads(subprocess.check_output([str(probe),'-v','error','-select_streams','v:0','-show_frames','-show_entries','frame=best_effort_timestamp_time','-of','json',str(path)]))['frames']
pts=[float(f['best_effort_timestamp_time']) for f in frames]
assert len(pts)>150 and all(b>a for a,b in zip(pts,pts[1:]))
samples=[]
for when in ['0.4','3.0']:
    rgb=subprocess.check_output([str(ff),'-v','error','-ss',when,'-i',str(path),'-frames:v','1','-vf','scale=32:32','-pix_fmt','rgb24','-f','rawvideo','-'])
    difference=sum(max(rgb[i:i+3])-min(rgb[i:i+3]) for i in range(0,len(rgb),3))/(len(rgb)//3)
    assert difference<3
    samples.append({'seconds':when,'meanRgbChannelDifference':difference})
source=q.adb('exec-out','cat','/sdcard/Pictures/XRecorder/Edited_1794327406739.png')
sourceSize=struct.unpack('>II',source[16:24])
photos=[]
for file,case,prefix in [
    ('acceptance_photo_qa.json','save-copy-from-final-apk','acceptance_photo_output'),
    ('acceptance_crop_transform.json','final-apk-photo-crop-quarter-turn-save-copy','acceptance_crop_output'),
]:
    events=json.loads((q.ROOT/file).read_text(encoding='utf8'))
    event=next(e for e in events if e.get('case')==case)
    name=next(s for s in event['labels'] if re.fullmatch(r'Edited_[0-9]+\.png',s))
    remotePhoto='/sdcard/Pictures/XRecorder/'+name
    data=q.adb('exec-out','cat',remotePhoto);assert data.startswith(b'\x89PNG') and data!=source
    size=struct.unpack('>II',data[16:24]);save(prefix+'.png',data);decode(q.ROOT/(prefix+'.png'))
    if prefix=='acceptance_crop_output':assert size[0]==sourceSize[1] and 0<size[1]<sourceSize[0]
    else:assert size==sourceSize
    photos.append({'file':prefix+'.png','devicePath':remotePhoto,'dimensions':size,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'fullDecode':'PASS'})
report={'apk':json.loads((q.ROOT/'acceptance_apk_identity.json').read_text()),'video':{'file':'acceptance_output.mp4','devicePath':remote,'job':job,'expectedSeconds':expected,'decodedFrames':len(pts),'ptsStrictlyIncreasing':True,'fullDecode':'PASS','grayscaleSamples':samples,'bytes':len(video),'sha256':hashlib.sha256(video).hexdigest(),'probe':info},'photos':photos,'limitations':['Retained short synthetic QA media, not a large/long-media certification.','Full audio decode is not human listening or a complete A/V sync test.']}
with (q.ROOT/'acceptance_output_validation.json').open('x',encoding='utf8') as f:json.dump(report,f,indent=2)
print('Final APK outputs: MP4 and 2 PNG full decode, timestamps, effect/crop/rotation dimensions PASS',flush=True)
