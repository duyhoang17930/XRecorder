import qa05b as q
import json,re,time,subprocess,uuid
from pathlib import Path

def language(label):
    for _ in range(7):
        ns=q.nodes()
        for n in ns:
            if n.get('class')=='android.widget.Button' and (n.get('content-desc') or n.get('text',''))==label:
                b=list(map(int,re.findall(r'\d+',n.get('bounds'))));q.tap((b[0]+b[2])//2,(b[1]+b[3])//2);return
        n=next(n for n in ns if n.get('scrollable')=='true')
        b=list(map(int,re.findall(r'\d+',n.get('bounds'))));x=(b[0]+b[2])//2
        q.adb('shell','input','swipe',str(x),str(b[3]-20),str(x),str(b[1]+20),'300')
    raise AssertionError(label)

vi=json.loads(Path('lib/l10n/app_vi.arb').read_text(encoding='utf8'))
q.click('Settings');q.click('Settings')
remote='/sdcard/ui05b_localized_'+uuid.uuid4().hex+'.mp4'
rec=subprocess.Popen(q.ADB+['shell','screenrecord','--bit-rate','650000','--time-limit','75',remote],creationflags=subprocess.CREATE_NO_WINDOW)
try:
    q.click('App language',scrolled=True);language('Ti\u1ebfng Vi\u1ec7t')
    q.click(vi['video']);q.click(vi['video']);q.click(vi['newest'],scrolled=True)
    time.sleep(1);q.back()
    q.click(vi['settings']);q.click(vi['settings']);q.click(vi['appLanguage'],scrolled=True);language('English')
    q.click('Video');q.click('Video')
    time.sleep(.5);q.click('Settings');q.click('Settings')
    q.EVENTS.append({'case':'localized-sort-video-and-restore','labels':q.labels()})
finally:
    rec.wait(timeout=85)
    with (q.ROOT/'UI05B_localized_sort_final.mp4').open('xb') as f:f.write(q.adb('exec-out','cat',remote,timeout=60))
    q.save_events('localized_video')
