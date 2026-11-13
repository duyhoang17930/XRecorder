import qa06 as q
import pathlib,json,re,subprocess,hashlib
jobs=json.loads((q.ROOT/'queue_after_video_export.json').read_text(encoding='utf8'))
before=json.loads((q.ROOT/'queue_before_ui06_outputs.json').read_text(encoding='utf8'))
assert all(any(old==now for now in jobs) for old in before),'Old queue record changed'
job=next(j for j in jobs if j['project']['title']=='UI06_Final_Video_V2')
assert job['state']=='completed' and job['progress']==100
row=q.adb('shell','content','query','--uri',job['uri'],'--projection','_data:is_pending').decode()
assert 'is_pending=0' in row,row
remote=re.search(r'_data=(.*?), is_pending',row)[1]
data=q.adb('exec-out','cat',remote)
path=q.ROOT/'UI06_export_verified.mp4'
with path.open('xb') as f:f.write(data)
ff=pathlib.Path('build/task03/ffmpeg/ffmpeg.exe').resolve();probe=ff.with_name('ffprobe.exe')
info=json.loads(subprocess.check_output([str(probe),'-v','error','-count_frames','-show_streams','-show_format','-of','json',str(path)]))
decoded=subprocess.run([str(ff),'-v','error','-xerror','-i',str(path),'-f','null','-'],capture_output=True,timeout=60)
assert decoded.returncode==0 and not decoded.stderr.strip(),decoded.stderr
video=next(s for s in info['streams'] if s['codec_type']=='video')
assert int(video['nb_read_frames'])>150
assert abs(float(info['format']['duration'])-6.593)<.15,info['format']
# Confirm the grayscale effect reaches both video and still-image portions.
differences=[]
for when in ['0.4','3.0']:
    raw=subprocess.check_output([str(ff),'-v','error','-ss',when,'-i',str(path),'-frames:v','1','-vf','scale=32:32','-pix_fmt','rgb24','-f','rawvideo','-'])
    difference=sum(max(raw[i:i+3])-min(raw[i:i+3]) for i in range(0,len(raw),3))/(len(raw)//3)
    assert difference<3,difference
    differences.append({'seconds':when,'meanRgbChannelDifference':difference})
report={'job':job,'uriRow':row,'path':remote,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'fullDecode':'PASS','probe':info,'grayscaleSamples':differences,'oldQueueRowsUnchanged':True,'limitations':'Short retained synthetic QA sources; not audible listening, A/V sync or all export-format certification.'}
with (q.ROOT/'native_video_output_validation.json').open('x',encoding='utf8') as f:json.dump(report,f,indent=2)
print('MP4 full decode, duration, frames, grayscale and original queue preservation PASS',flush=True)
