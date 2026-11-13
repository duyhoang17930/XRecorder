import pathlib,subprocess,json,sys
root=pathlib.Path(sys.argv[1]) if len(sys.argv)>1 else pathlib.Path(__file__).parent
ff=pathlib.Path('build/task03/ffmpeg/ffmpeg.exe').resolve();probe=ff.with_name('ffprobe.exe')
rows=[]
for short,file in [('video','UI06_acceptance_video_interactions.mp4'),('photo','UI06_acceptance_photo_interactions.mp4'),('general','UI06_acceptance_general_interactions.mp4')]:
    path=root/file
    info=json.loads(subprocess.check_output([str(probe),'-v','error','-show_format','-of','json',str(path)]))
    duration=float(info['format']['duration']);times=[duration*f for f in [.02,.2,.4,.6,.8,.97]]
    target=root/('acceptance_'+short+'_video_keyframes.jpg');assert not target.exists()
    args=[str(ff),'-v','error','-nostdin','-n']
    for time in times:args+=['-ss',str(time),'-i',str(path)]
    filters=[f'[{i}:v]scale=140:-1[v{i}]' for i in range(6)]
    filters+=[''.join(f'[v{i}]' for i in range(6))+'hstack=inputs=6[out]']
    subprocess.run(args+['-filter_complex',';'.join(filters),'-map','[out]','-frames:v','1','-q:v','3',str(target)],check=True,capture_output=True,timeout=60)
    rows.append({'file':file,'seconds':duration,'keyframeTimes':times,'contactSheet':target.name,'reviewScope':'Representative keyframes plus Android screenshots and assertion logs, not human continuous-playback usability acceptance.'})
with (root/'video_keyframe_review.json').open('x',encoding='utf8') as f:json.dump(rows,f,indent=2)
print(json.dumps(rows),flush=True)
