import qa06 as q
import json,hashlib,struct,subprocess,pathlib
source='/sdcard/Pictures/XRecorder/Edited_1794327406739.png'
remote='/sdcard/Pictures/XRecorder/Edited_1794398254111.png'
sourceBytes=q.adb('exec-out','cat',source);data=q.adb('exec-out','cat',remote)
baseline=json.loads((q.ROOT/'retained_media_baseline.json').read_text())
assert hashlib.sha256(sourceBytes).hexdigest()==baseline[source]
assert sourceBytes.startswith(b'\x89PNG') and data.startswith(b'\x89PNG')
sourceSize=struct.unpack('>II',sourceBytes[16:24])
size=struct.unpack('>II',data[16:24])
assert size[0]==sourceSize[1] and 0<size[1]<sourceSize[0],(sourceSize,size)
assert data!=sourceBytes
with (q.ROOT/'UI06_photo_copy_verified.png').open('xb') as f:f.write(data)
ff=pathlib.Path('build/task03/ffmpeg/ffmpeg.exe').resolve()
decoded=subprocess.run([str(ff),'-v','error','-xerror','-i',str(q.ROOT/'UI06_photo_copy_verified.png'),'-f','null','-'],capture_output=True,timeout=30)
assert decoded.returncode==0 and not decoded.stderr.strip(),decoded.stderr
mode='PNG color type '+str(data[25])
report={'source':source,'sourceDimensions':sourceSize,'sourceSha256':baseline[source],'sourceUnchanged':True,'output':remote,'uri':'content://media/external/images/media/2319','dimensions':size,'mode':mode,'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data),'fullPngDecode':'PASS','cropAndQuarterTurnDimensions':'PASS','visualMarksEvidence':['final_v2_photo_text_applied.png','final_v2_photo_drawing.png','final_v2_photo_after_resume.png'],'limitation':'Pixel decode and dimensions are verified; user visual acceptance remains pending.'}
with (q.ROOT/'native_photo_output_validation.json').open('x',encoding='utf8') as f:json.dump(report,f,indent=2)
print(json.dumps(report),flush=True)
