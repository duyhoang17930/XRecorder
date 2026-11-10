import qa04 as q,json,pathlib,subprocess,hashlib
ffmpeg=str(pathlib.Path('build/task03/ffmpeg/ffmpeg.exe').resolve())
probe=str(pathlib.Path('build/task03/ffmpeg/ffprobe.exe').resolve())
job=json.loads((q.ROOT/'video_export_job.json').read_text(encoding='utf8'))
blob=q.adb('exec-out','content','read','--uri',job['uri'])
path=q.ROOT/'UI04_export_ca13829a.mp4'
with path.open('xb') as f:f.write(blob)
info=json.loads(subprocess.check_output([probe,'-v','error','-show_entries','format=duration:stream=codec_name,codec_type,width,height,sample_rate,channels','-of','json',str(path)]))
subprocess.run([ffmpeg,'-v','error','-i',str(path),'-f','null','-'],check=True,capture_output=True)
packets=json.loads(subprocess.check_output([probe,'-v','error','-select_streams','v:0','-show_packets','-show_entries','packet=dts_time','-of','json',str(path)]))['packets']
dts=[float(p['dts_time']) for p in packets if 'dts_time' in p]
assert all(a<=b for a,b in zip(dts,dts[1:]))
v=next(s for s in info['streams'] if s['codec_type']=='video')
frame=subprocess.check_output([ffmpeg,'-v','error','-ss','1','-i',str(path),'-frames:v','1','-f','rawvideo','-pix_fmt','rgb24','pipe:1'])
pixel=list(frame[(10*v['width']+10)*3:(10*v['width']+10)*3+3])
white=sum(all(c>220 for c in frame[i:i+3]) for i in range(0,len(frame),3))
assert white>20
result={'uri':job['uri'],'size':len(blob),'sha256':hashlib.sha256(blob).hexdigest(),'metadata':info,'fullDecode':True,'monotonicVideoDts':True,'cornerPixelRGB':pixel,'whiteOverlayPixelsAt1s':white}
with (q.ROOT/'video_output_validation.json').open('x',encoding='utf8') as f:json.dump(result,f,indent=2)
print(json.dumps(result,indent=2))
