"""Validate real Android editor outputs. No files are removed from the device."""
import argparse
import array
import json
import math
from pathlib import Path
import re
import subprocess

p=argparse.ArgumentParser()
p.add_argument('--adb',default='C:/Users/dangh/AppData/Local/Android/Sdk/platform-tools/adb.exe')
p.add_argument('--serial',default='emulator-5560')
p.add_argument('--directory',default='build/verification/p2_p3/audio')
p.add_argument('--check-preview-parity',action='store_true')
p.add_argument('--offline',action='store_true',help='Validate already-pulled native outputs without accessing a device.')
p.add_argument('--exclude-capture-outline',action='store_true',help='Exclude the capture-only outer1px at320x180; reject fixtures with expected media on that border.')
args=p.parse_args()
root=Path(args.directory)
ffmpeg=Path('build/task03/ffmpeg/ffmpeg.exe').resolve()
ffprobe=ffmpeg.with_name('ffprobe.exe')
def adb(*words):
    return subprocess.check_output([args.adb,'-s',args.serial,*words],text=True).strip()
if not args.offline:
    assert adb('shell','getprop','ro.boot.qemu.avd_name')=='ThreeHRecorder_Task021'
uris=json.loads((root/'native/emulator_verification.json').read_text())['outputs']
files={}
for name,uri in uris.items():
    assert re.fullmatch(r'[A-Za-z0-9_-]+',name)
    path=root/f'{name}.mp4'
    if not args.offline:
        row=adb('shell','content','query','--uri',uri,'--projection','_data')
        match=re.search(r'_data=(.*)',row)
        assert match,row
        subprocess.run([args.adb,'-s',args.serial,'pull',match[1].strip(),str(path)],check=True,capture_output=True)
    assert path.is_file() and path.stat().st_size>0,path
    files[name]=path
def pcm(path):
    data=subprocess.check_output([str(ffmpeg),'-v','error','-i',str(path),'-vn','-ac','1','-ar','48000','-f','f32le','-'])
    values=array.array('f');values.frombytes(data)
    return values
audio={name:pcm(path) for name,path in files.items()}
def window(name,start,end):return audio[name][round(start*48000):round(end*48000)]
def rms(name,start,end):
    values=window(name,start,end)
    return math.sqrt(sum(x*x for x in values)/len(values))
def amplitude(name,start,end,freq):
    values=window(name,start,end)
    real=sum(x*math.cos(2*math.pi*freq*i/48000) for i,x in enumerate(values))
    imag=sum(x*math.sin(2*math.pi*freq*i/48000) for i,x in enumerate(values))
    return 2*math.hypot(real,imag)/len(values)
result={'files':{},'signals':{}}
for name,path in files.items():
    probe=json.loads(subprocess.check_output([str(ffprobe),'-v','error','-show_streams','-show_format','-of','json',str(path)],text=True))
    streams=probe['streams'];v=next(s for s in streams if s['codec_type']=='video');a=next(s for s in streams if s['codec_type']=='audio')
    drift=abs(float(v['duration'])-float(a['duration']))
    assert drift<.08,(name,drift)
    assert abs(float(probe['format']['duration'])-4)<.12,(name,probe)
    subprocess.run([str(ffmpeg),'-v','error','-xerror','-i',str(path),'-f','null','-'],check=True,capture_output=True)
    result['files'][name]={'avDurationDifferenceMs':round(drift*1000,3),'duration':probe['format']['duration'],'samples':len(audio[name]),'rmsMiddle':rms(name,1.2,2.8)}
assert rms('baseline',1.2,2.8)>.1
if 'gain' in audio:
    assert rms('gain',1.2,2.8)>rms('baseline',1.2,2.8)*1.5
    # Boosting must saturate rather than wrapping signed PCM16 through zero.
    base=window('baseline',1.5,2);boost=window('gain',1.5,2)
    signErrors=sum(a*b<0 for a,b in zip(base,boost))/len(base)
    assert signErrors<.02,signErrors
if 'trackTrim' in audio:
    assert rms('trackTrim',.1,.4)<.002
    assert amplitude('trackTrim',.7,.9,660)>.3
    assert amplitude('trackTrim',1.7,1.9,880)>.3
    assert amplitude('trackTrim',.7,.9,440)<.01
    assert rms('trackTrim',2.7,3.7)<.002
fadeRatios={str(t):rms('fades',t,t+.1)/rms('baseline',t,t+.1) for t in [.2,.7,3.1,3.7]}
assert .1<fadeRatios['0.2']<.4 and .6<fadeRatios['0.7']<.9,fadeRatios
assert .7<fadeRatios['3.1']<1 and .1<fadeRatios['3.7']<.4,fadeRatios
assert amplitude('mix',.7,.9,880)<.01
assert amplitude('mix',1.4,1.8,440)>.1 and amplitude('mix',1.4,1.8,880)>.1
assert rms('mix',3.3,3.8)<.002
assert amplitude('robot',1.5,2,405)>.1 and amplitude('robot',1.5,2,475)>.1
assert amplitude('deep',1.5,2,330)>.1
if 'bright' in audio:assert amplitude('bright',1.5,2,594)>.1
if 'mixedLegacy' in audio:
    assert .25<amplitude('mixedLegacy',1.4,1.8,440)<.35
    assert .25<amplitude('mixedLegacy',1.4,1.8,880)<.35
assert rms('noise',.2,.7)<rms('baseline',.2,.7)*.4
if 'speechDenoised' in audio:
    clean=pcm(root/'p2_p3_speech_clean.wav')
    def si_sdr(name):
        # Account for codec and RNNoise look-ahead; gain-invariant residual test.
        x=clean[24000:168000:6]
        best=(-1,None)
        xx=sum(v*v for v in x)
        for shift in range(-400,401,2):
            a=24000+shift*6;b=168000+shift*6
            y=audio[name][a:b:6]
            xy=sum(u*v for u,v in zip(x,y));yy=sum(v*v for v in y)
            score=xy*xy/max(1e-15,xx*yy)
            if xy>0 and score>best[0]:best=(score,shift)
        shift=best[1]*6
        x=clean[24000:168000];y=audio[name][24000+shift:168000+shift]
        scale=sum(u*v for u,v in zip(x,y))/sum(v*v for v in x)
        signal=sum((scale*v)**2 for v in x)
        residual=sum((v-scale*u)**2 for u,v in zip(x,y))
        return {'siSdrDb':10*math.log10(signal/max(residual,1e-15)),'alignmentMs':shift/48}
    before=si_sdr('speechNoisy');after=si_sdr('speechDenoised')
    result['speechNoiseReduction']={'before':before,'after':after,'improvementDb':after['siSdrDb']-before['siSdrDb']}
    assert after['siSdrDb']>before['siSdrDb']+1,result['speechNoiseReduction']
result['signals']={'fadeRmsRatios':fadeRatios,'mix440Hz':amplitude('mix',1.4,1.8,440),'mix880Hz':amplitude('mix',1.4,1.8,880),
    'robot405Hz':amplitude('robot',1.5,2,405),'robot475Hz':amplitude('robot',1.5,2,475),'deep330Hz':amplitude('deep',1.5,2,330),
    'quietNoiseRmsRatio':rms('noise',.2,.7)/rms('baseline',.2,.7)}
def pixels(name,time):return subprocess.check_output([str(ffmpeg),'-v','error','-ss',str(time),'-i',str(files[name]),'-frames:v','1','-pix_fmt','rgb24','-f','rawvideo','-'])
result['layerDifferences']={}
for time in [.2,.8,1.8,2.5,3.5]:
    a=pixels('baseline',time);b=pixels('mix',time)
    difference=sum(max(abs(a[i+c]-b[i+c]) for c in range(3))>32 for i in range(0,len(a),3))
    result['layerDifferences'][str(time)]=difference
    assert difference>150 if time in [.8,2.5,3.5] else difference<100,(time,difference)
result['passed']=True
flash=Path(args.directory)/'flash_fixture.json'
if flash.exists():
    # The source flashes white and starts a loud tone at exactly1s.
    luma=subprocess.check_output([str(ffmpeg),'-v','error','-i',str(files['baseline']),'-vf','scale=1:1,format=gray','-f','rawvideo','-'])
    first=next(i for i,v in enumerate(luma) if v>200)
    videoOnset=first/30
    audioOnset=next(i/100 for i in range(350) if rms('baseline',i/100,(i+1)/100)>.05)
    result['flashToneSync']={'videoSeconds':videoOnset,'audioSeconds':audioOnset,'differenceMs':abs(videoOnset-audioOnset)*1000}
    assert abs(videoOnset-audioOnset)<.07,result['flashToneSync']
result['scope']='Signal, timing, full decode and pixel checks on AVD; no claim of human listening or lip-sync testing.'
if args.check_preview_parity:
    import io
    from PIL import Image
    rows=json.loads((root/'native/emulator_verification.json').read_text(encoding='utf-8'))['previewParity']
    assert [r['timeMs'] for r in rows]==[800,1800,2500,3500]
    parity=[]
    for row in rows:
        time_ms=row['timeMs']
        screen=Image.open(root/f'preview_{time_ms}.png').convert('RGB')
        left,top,width,height=[round(row[k]*row['dpr']) for k in ('left','top','width','height')]
        preview=screen.crop((left,top,left+width,top+height)).resize((320,180))
        raw=subprocess.check_output([str(ffmpeg),'-v','error','-ss',str(time_ms/1000),'-i',str(files['mix']),'-frames:v','1','-f','image2pipe','-vcodec','png','-'])
        exported=Image.open(io.BytesIO(raw)).convert('RGB')
        assert exported.size==(320,180)
        def mask(img):
            found=set()
            for i,(r,g,b) in enumerate(img.getdata()):
                x,y=i%320,i//320
                # Flutter's QA debug banner is not part of native media output.
                if x>270 and y<50:continue
                selected=(r>100 and g>100 and b<min(r,g)*.6) if time_ms==800 else (r>100 and max(g,b)<r*.6) if time_ms==2500 else (g>100 and max(r,b)<g*.6) if time_ms==3500 else ((r>120 and g>120 and b<100) or (r>120 and max(g,b)<100) or (g>120 and max(r,b)<100))
                if selected:found.add((x,y))
            return found
        a,b=mask(preview),mask(exported)
        if args.exclude_capture_outline:
            # Only a capture-window outline is excluded. The controlled layers
            # are inset; reject media at the boundary and keep coverage strict.
            interior=lambda points:{(x,y) for x,y in points if 0<x<319 and 0<y<179}
            assert b==interior(b),'Cannot exclude an edge containing expected media'
            a=interior(a)
        metric={'timeMs':time_ms,'previewMaskPixels':len(a),'exportMaskPixels':len(b)}
        if time_ms==1800:
            assert not a and not b,metric
        else:
            assert len(a)>100 and len(b)>100,metric
            def dilate(points):return {(x+dx,y+dy) for x,y in points for dx in range(-2,3) for dy in range(-2,3)}
            coverage_a=len(a&dilate(b))/len(a);coverage_b=len(b&dilate(a))/len(b)
            assert min(coverage_a,coverage_b)>.9,(time_ms,coverage_a,coverage_b)
            metric.update(previewWithin2pxOfExport=coverage_a,exportWithin2pxOfPreview=coverage_b)
        parity.append(metric)
        preview.save(root/f'preview_crop_{time_ms}.png');exported.save(root/f'export_frame_{time_ms}.png')
    result['previewExportParity']={'frames':parity,'method':'Known fixture layer color masks after resizing native screen crop to320x180; symmetric2px tolerance for codec/raster edges. Excludes QA debug banner; no claim of bit-identical rendering.'}
result['archivedFilesOnly']=args.offline
result['excludedCaptureBoundaryPxAt320x180']=1 if args.exclude_capture_outline else 0
(root/'signal_validation.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
