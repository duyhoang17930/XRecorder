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
parser.add_argument('--check-subtitle-speed',action='store_true')
args = parser.parse_args()
probe = args.ffmpeg_directory / 'ffprobe.exe'
ffmpeg = args.ffmpeg_directory / 'ffmpeg.exe'
args.directory.mkdir(parents=True,exist_ok=True)
if args.native_report:
    adb='C:/Users/dangh/AppData/Local/Android/Sdk/platform-tools/adb.exe'
    def device(*words):return subprocess.check_output([adb,'-s','emulator-5560',*words],text=True).strip()
    assert device('shell','getprop','ro.boot.qemu.avd_name')=='ThreeHRecorder_Task021'
    data=json.loads(args.native_report.read_text(encoding='utf-8'))
    for name,uri in data['outputs'].items():
        assert re.fullmatch(r'[A-Za-z0-9_-]+',name)
        assert re.fullmatch(r'content://media/(external|external_primary)/(video|images)/media/[0-9]+',uri)
        row=device('shell','content','query','--uri',uri,'--projection','_data')
        source=re.search(r'_data=(.*)',row)[1].strip()
        subprocess.run([adb,'-s','emulator-5560','pull',source,str(args.directory/(name+'.mp4'))],check=True,capture_output=True)
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
(args.directory / 'validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps([{'file':r['file'],'frames':r['decodedVideoFrames'],'bytes':r['bytes'],'fullDecode':r['fullDecode'],'audioRms':r['audioRms']} for r in results], indent=2))
