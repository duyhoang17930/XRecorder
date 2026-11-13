import qa05 as q
import re,time
try:
    q.click('Video')
    n=next(n for n in q.nodes() if 'Edited_ca13829a' in (n.get('content-desc') or n.get('text','')))
    b=list(map(int,re.findall(r'\d+',n.get('bounds'))));q.tap((b[0]+b[2])//2,(b[1]+b[3])//2)
    for index in range(2):
        q.click('Rename',scrolled=True)
        n=next(n for n in q.nodes() if n.get('class')=='android.widget.EditText')
        b=list(map(int,re.findall(r'\d+',n.get('bounds'))));q.tap((b[0]+b[2])//2,(b[1]+b[3])//2)
        q.adb('shell','input','text','QA05_CANCEL_ONLY');time.sleep(.3)
        if index==0:q.shot('after_rename_keyboard_debug')
        q.click('Cancel');time.sleep(.5)
        q.EVENTS.append({'case':'rename-cancel-keyboard-'+str(index),'labels':q.labels()})
    q.shot('after_rename_cancel_debug');q.back();q.click('Settings')
finally:
    pid=q.adb('shell','pidof','com.xrecorder.xrecorder').decode().strip()
    with (q.ROOT/'debug_rename_runtime_logcat.txt').open('xb') as f:f.write(q.adb('logcat','-d','--pid='+pid,'-v','threadtime'))
    q.save_events('rename_android_qa')
