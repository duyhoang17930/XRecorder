import qa05 as q
import re,time,uuid,subprocess,json

def center(label):
    for n in sorted(q.nodes(),key=lambda n:n.get('clickable')!='true'):
        if (n.get('content-desc') or n.get('text','')).split('\n')[0]==label:
            b=list(map(int,re.findall(r'\d+',n.get('bounds'))));return ((b[0]+b[2])//2,(b[1]+b[3])//2)
    raise AssertionError(label)

original={k:q.adb('shell','settings','get','global',k).decode().strip() for k in ['transition_animation_scale','animator_duration_scale']}
try:
    launch=q.adb('shell','am','start','-W','-n','com.xrecorder.xrecorder/.MainActivity')
    with (q.ROOT/'debug_launch.txt').open('xb') as f:f.write(launch)
    time.sleep(2);q.click('Settings');q.click('Settings')
    nav={n:center(n) for n in ['Video','Photo','Edit','Settings','Create']}
    for key in original:q.adb('shell','settings','put','global',key,'0')
    time.sleep(1)
    remote='/sdcard/ui05_reduce_motion_'+uuid.uuid4().hex+'.mp4'
    rec=subprocess.Popen(q.ADB+['shell','screenrecord','--bit-rate','700000','--time-limit','16',remote],creationflags=subprocess.CREATE_NO_WINDOW)
    time.sleep(.5)
    for tab in ['Video','Photo','Edit','Settings','Photo','Video','Settings']:
        x,y=nav[tab];q.adb('shell','input','tap',str(x),str(y));time.sleep(.25)
    x,y=nav['Create'];q.adb('shell','input','tap',str(x),str(y));time.sleep(.5);q.back()
    q.click('Media storage',scrolled=True);q.shot('debug_reduced_motion_dialog');q.click('Close')
    rec.wait(timeout=25)
    with (q.ROOT/'UI05_reduced_motion_debug.mp4').open('xb') as f:f.write(q.adb('exec-out','cat',remote))
    q.EVENTS.append({'case':'debug-reduced-motion','settingsApplied':{k:'0' for k in original},'labels':q.labels()})
    pid=q.adb('shell','pidof','com.xrecorder.xrecorder').decode().strip()
    with (q.ROOT/'debug_runtime_logcat.txt').open('xb') as f:f.write(q.adb('logcat','-d','--pid='+pid,'-v','threadtime'))
finally:
    for key,value in original.items():
        q.adb('shell','settings','delete','global',key) if value=='null' else q.adb('shell','settings','put','global',key,value)
    q.restore();q.EVENTS.append({'restoredGlobals':original});q.save_events('debug_reduced_motion_qa')
