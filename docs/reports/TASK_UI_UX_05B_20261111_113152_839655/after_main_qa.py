import qa05b as q
import json,re,time,subprocess,uuid

def rect(label,header=False):
    for n in sorted(q.nodes(),key=lambda n:n.get('clickable')!='true'):
        if (n.get('content-desc') or n.get('text','')).split('\n')[0]!=label:continue
        b=list(map(int,re.findall(r'\d+',n.get('bounds'))))
        if b[2]>b[0] and b[3]>b[1] and (not header or b[3]<350):return b
    raise AssertionError(label)
def tap(b,delay=.4):
    q.adb('shell','input','tap',str((b[0]+b[2])//2),str((b[1]+b[3])//2));time.sleep(delay)
def event(name):
    q.EVENTS.append({'case':name,'labels':q.labels()});print(name,flush=True)

rec=None;remote=None
try:
    with (q.ROOT/'debug_launch_main.txt').open('xb') as f:f.write(q.adb('shell','am','start','-W','-n','com.xrecorder.xrecorder/.MainActivity'))
    time.sleep(1)
    for _ in range(3):
        if 'Create' in q.labels():break
        q.back()
    remote='/sdcard/ui05b_main_'+uuid.uuid4().hex+'.mp4'
    rec=subprocess.Popen(q.ADB+['shell','screenrecord','--bit-rate','850000','--time-limit','110',remote],creationflags=subprocess.CREATE_NO_WINDOW)
    brands={}
    for tab,title in [('Video','Video Library'),('Photo','Photo Library'),('Edit','Editing Studio'),('Settings','Settings')]:
        q.click(tab);q.click(tab);q.shot('after_header_'+tab.lower()+'_light');brands[tab]={'brand':rect('3HRECORDER',True),'title':rect(title,True)}
    assert len({tuple(v['brand']) for v in brands.values()})==1,brands
    assert len({v['title'][1] for v in brands.values()})==1,brands
    q.EVENTS.append({'case':'headers-aligned','bounds':brands})
    assert sum(t.split('\n')[0]=='Recording settings' for t in q.labels())==1
    q.shot('after_settings_capture_light');q.click('Recording settings');q.shot('after_recording_destination_light')
    assert 'Audio & Video Settings' in q.labels()
    q.back();event('settings-destination-back')
    create=rect('Create')
    for taps in [2,3,5]:
        for _ in range(taps):tap(create,.06)
        labels=q.labels();assert 'Close create menu' in labels,labels
        assert 'Start Recording' not in labels,labels
        q.EVENTS.append({'case':'rapid-create','taps':taps,'createSheetRemained':True,'labels':labels})
        if taps==5:q.shot('after_create_five_taps')
        q.back()
    tap(create);time.sleep(.4);q.click('Screen recording');assert 'Start Recording' in q.labels();q.back()
    event('deliberate-create-handoff-no-recording')
    q.click('Video')
    n=next(n for n in q.nodes() if 'Edited_ca13829a' in (n.get('content-desc') or n.get('text','')))
    b=list(map(int,re.findall(r'\d+',n.get('bounds'))));tap(b)
    preview=rect('Preview')
    tap(preview);time.sleep(3.2);back=rect('Back');assert back[2]-back[0]>=48 and back[3]-back[1]>=48
    q.shot('after_video_player_portrait');q.EVENTS.append({'case':'player-back-target','bounds':back})
    q.adb('shell','input','tap','205','420');time.sleep(.2)
    controls=q.nodes();pause=next((n for n in controls if n.get('content-desc') in ['Play','Pause']),None)
    if pause is not None:
        p=list(map(int,re.findall(r'\d+',pause.get('bounds'))));tap(p,.15);tap(p,.15);q.EVENTS.append({'case':'play-pause','control':dict(pause.attrib)})
    tap(back);assert 'Media details' in q.labels();event('player-visible-back')
    tap(preview);q.rotate(1);time.sleep(.5);q.shot('after_video_player_landscape');q.adb('shell','input','keyevent','4');time.sleep(.6)
    assert 'Media details' in q.labels();q.rotate(0);event('player-landscape-system-back')
    tap(preview);time.sleep(3);tap(back);assert 'Media details' in q.labels();event('player-end-reopen-back')
    q.back();q.click('Settings');q.click('Settings')
    for _ in range(5):
        q.adb('shell','input','swipe','205','740','205','130','120')
        q.adb('shell','input','swipe','205','150','205','750','120')
    q.shot('after_settings_fast_scroll_light');event('settings-stretch-10-flings')
    q.adb('shell','input','keyevent','3');time.sleep(.5);q.adb('shell','am','start','-n','com.xrecorder.xrecorder/.MainActivity');time.sleep(.5)
    assert 'Create' in q.labels();event('background-foreground')
finally:
    q.restore()
    if rec is not None:
        rec.wait(timeout=120)
        with (q.ROOT/'UI05B_main_interactions.mp4').open('xb') as f:f.write(q.adb('exec-out','cat',remote,timeout=60))
    q.save_events('after_main_qa')
