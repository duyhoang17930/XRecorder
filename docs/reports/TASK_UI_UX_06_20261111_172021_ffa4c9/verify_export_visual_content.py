import pathlib,subprocess,json
root=pathlib.Path(__file__).parent/'native_final_v2'
ff=pathlib.Path('build/task03/ffmpeg/ffmpeg.exe').resolve()
rows=[]
for index,time in enumerate(['0.4','3.0']):
    raw=subprocess.check_output([str(ff),'-v','error','-ss',time,'-i',str(root/'acceptance_output.mp4'),'-frames:v','1','-vf','scale=32:32','-pix_fmt','rgb24','-f','rawvideo','-'])
    mean=sum(raw)/len(raw);span=max(raw)-min(raw)
    assert mean>20 and span>50,(time,mean,span)
    path=root/('acceptance_export_frame_'+str(index)+'.png');assert not path.exists()
    subprocess.run([str(ff),'-v','error','-nostdin','-n','-ss',time,'-i',str(root/'acceptance_output.mp4'),'-frames:v','1',str(path)],check=True,capture_output=True)
    rows.append({'seconds':time,'meanRgbValue':mean,'channelSpan':span,'nonBlank':'PASS','image':path.name})
with (root/'acceptance_visual_content_validation.json').open('x') as f:json.dump(rows,f,indent=2)
print(json.dumps(rows))
