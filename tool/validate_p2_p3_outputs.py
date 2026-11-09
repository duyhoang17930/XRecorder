"""Independent fixture validation; never touches device media or deletes outputs."""
import argparse
import array
import hashlib
import json
import math
import re
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('directory', type=Path)
parser.add_argument('--ffmpeg-directory', type=Path, required=True)
parser.add_argument('--native-report',type=Path)
parser.add_argument('--serial',default='emulator-5560')
parser.add_argument('--check-subtitle-speed',action='store_true')
parser.add_argument('--check-input-matrix',action='store_true')
args = parser.parse_args()
probe = args.ffmpeg_directory / 'ffprobe.exe'
ffmpeg = args.ffmpeg_directory / 'ffmpeg.exe'
args.directory.mkdir(parents=True,exist_ok=True)
if (args.directory/'validation.json').exists():
    raise FileExistsError('Use a new validation directory; preserve earlier evidence.')
if args.native_report:
    adb='C:/Users/dangh/AppData/Local/Android/Sdk/platform-tools/adb.exe'
    allowed={'emulator-5560':'ThreeHRecorder_Task021','emulator-5562':'ThreeHRecorder_Final_API34'}
    assert args.serial in allowed
    def device(*words):return subprocess.check_output([adb,'-s',args.serial,*words],text=True).strip()
    assert device('shell','getprop','ro.boot.qemu.avd_name')==allowed[args.serial]
    data=json.loads(args.native_report.read_text(encoding='utf-8'))
    for name,uri in data['outputs'].items():
        assert re.fullmatch(r'[A-Za-z0-9_-]+',name)
        assert re.fullmatch(r'content://media/(external|external_primary)/(video|images)/media/[0-9]+',uri)
        row=device('shell','content','query','--uri',uri,'--projection','_data')
        source=re.search(r'_data=(.*)',row)[1].strip()
        subprocess.run([adb,'-s',args.serial,'pull',source,str(args.directory/(name+'.mp4'))],check=True,capture_output=True)
results = []
for path in sorted(args.directory.iterdir()):
    if path.suffix not in ('.mp4', '.gif'):
        continue
    info = json.loads(subprocess.check_output([str(probe), '-v', 'error', '-count_frames', '-show_streams', '-show_format', '-of', 'json', str(path)]))
    frames = json.loads(subprocess.check_output([str(probe), '-v', 'error', '-select_streams', 'v:0', '-show_frames', '-show_entries', 'frame=best_effort_timestamp_time', '-of', 'json', str(path)]))['frames']
    times = [float(frame['best_effort_timestamp_time']) for frame in frames if 'best_effort_timestamp_time' in frame]
    assert times and all(b > a for a, b in zip(times, times[1:])), path
    decoded = subprocess.run([str(ffmpeg), '-v', 'error', '-i', str(path), '-f', 'null', '-'], capture_output=True, timeout=90)
    assert decoded.returncode == 0 and not decoded.stderr.strip(), decoded.stderr.decode(errors='replace')
    audio = next((s for s in info['streams'] if s['codec_type'] == 'audio'), None)
    rms = None
    if audio:
        samples = array.array('f', subprocess.check_output([str(ffmpeg), '-v', 'error', '-i', str(path), '-t', '15', '-vn', '-ac', '1', '-ar', '16000', '-f', 'f32le', '-']))
        rms = math.sqrt(sum(v*v for v in samples) / len(samples)) if samples else 0
    results.append({'file': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'bytes': path.stat().st_size, 'streams': info['streams'], 'format': info['format'], 'decodedVideoFrames': len(times), 'ptsStrictlyIncreasing': True, 'fullDecode': 'PASS', 'audioRms': rms})
assert results, 'No media fixtures found'
report = {'ffprobeVersion': subprocess.check_output([str(probe), '-version'], text=True).splitlines()[0], 'results': results, 'limitations': 'Synthetic short clips; RMS is not human listening or A/V sync certification.'}
if args.check_subtitle_speed:
    def pixels(name,time):return subprocess.check_output([str(ffmpeg),'-v','error','-ss',str(time),'-i',str(args.directory/(name+'.mp4')),'-frames:v','1','-pix_fmt','rgb24','-f','rawvideo','-'])
    differences={}
    for time in [.1,.4,.65,1.0,1.5]:
        a=pixels('fastBase',time);b=pixels('fastSubtitles',time)
        differences[str(time)]=sum(max(abs(a[i+c]-b[i+c]) for c in range(3))>32 for i in range(0,len(a),3))
        assert differences[str(time)]>150 if time in [.4,.65] else differences[str(time)]<100,(time,differences)
    report['speed2SubtitlePixelDifferences']=differences
if args.check_input_matrix:
    checks={}
    for item in results:
        name=Path(item['file']).stem
        video=next(s for s in item['streams'] if s['codec_type']=='video')
        audio=next(s for s in item['streams'] if s['codec_type']=='audio')
        assert abs(float(video['duration'])-float(audio['duration']))<.08
        if name=='short200':
            assert abs(float(video['duration'])-.2)<.001
            continue
        path=args.directory/item['file']
        frames=json.loads(subprocess.check_output([str(probe),'-v','error','-select_streams','v:0','-show_frames','-show_entries','frame=best_effort_timestamp_time','-of','json',str(path)]))['frames']
        pts=[float(f['best_effort_timestamp_time']) for f in frames]
        gray=subprocess.check_output([str(ffmpeg),'-v','error','-i',str(path),'-vf','scale=1:1,format=gray','-fps_mode','passthrough','-f','rawvideo','-'])
        assert len(gray)==len(pts)
        flashes=[pts[i] for i,x in enumerate(gray) if x>200 and (i==0 or gray[i-1]<=200)]
        samples=array.array('f',subprocess.check_output([str(ffmpeg),'-v','error','-i',str(path),'-vn','-ac','1','-ar','48000','-f','f32le','-']))
        envelopes=[math.sqrt(sum(x*x for x in samples[i:i+480])/480) for i in range(0,len(samples)-480,480)]
        pulses=[i*.01 for i,x in enumerate(envelopes) if x>.05 and (i==0 or envelopes[i-1]<=.05)]
        assert len(flashes)==3,(name,flashes)
        if name=='noAudio':
            assert max(envelopes)<.0001
        else:
            assert len(pulses)==3,(name,pulses)
            assert all(abs(a-v)<=.05 for a,v in zip(pulses,flashes)),(name,pulses,flashes)
        checks[name]={'videoFlashOnsets':flashes,'audioPulseOnsets10msWindows':pulses,'avOnsetDifferenceMs':[round((a-v)*1000,3) for a,v in zip(pulses,flashes)],'channels':audio['channels'],'sampleRate':audio['sample_rate']}
        if name=='fps60_cap24':
            assert len(pts)==144 and all(b-a>=1/60-.00001 for a,b in zip(pts,pts[1:]))
        if name=='rotation90':
            rotation=next((s.get('rotation',0) for s in video.get('side_data_list',[]) if 'rotation' in s),0)
            assert (video['width'],video['height'],abs(rotation))==(320,180,90)
            checks[name]['displaySize']=[180,320]
        if name=='stereo441':
            assert audio['channels']==2 and audio['sample_rate']=='44100'
            stereo=array.array('f',subprocess.check_output([str(ffmpeg),'-v','error','-i',str(path),'-vn','-ac','2','-ar','44100','-f','f32le','-']))
            def amplitude(channel,freq):
                values=stereo[round(.54*44100)*2+channel:round(.62*44100)*2:2]
                return 2*math.hypot(sum(v*math.cos(2*math.pi*freq*i/44100) for i,v in enumerate(values)),sum(v*math.sin(2*math.pi*freq*i/44100) for i,v in enumerate(values)))/len(values)
            assert amplitude(0,440)>amplitude(0,880)*10
            assert amplitude(1,880)>amplitude(1,440)*10
            checks[name]['distinctStereoTonesPreserved']=True
    report['inputMatrix']=checks
with (args.directory/'validation.json').open('x',encoding='utf8') as stream:
    json.dump(report,stream,indent=2)
print(json.dumps([{'file':r['file'],'frames':r['decodedVideoFrames'],'bytes':r['bytes'],'fullDecode':r['fullDecode'],'audioRms':r['audioRms']} for r in results], indent=2))
