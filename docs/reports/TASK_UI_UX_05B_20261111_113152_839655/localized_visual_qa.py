import qa05b as q
import json,time,re
from pathlib import Path

def language(label):
    # Select from the actual list; avoid changing keyboard/stylus preferences.
    for _ in range(7):
        ns=q.nodes()
        for n in ns:
            if n.get('class')=='android.widget.Button' and (n.get('content-desc') or n.get('text',''))==label:
                b=list(map(int,re.findall(r'\d+',n.get('bounds'))));q.tap((b[0]+b[2])//2,(b[1]+b[3])//2);return
        n=next(n for n in ns if n.get('scrollable')=='true')
        b=list(map(int,re.findall(r'\d+',n.get('bounds'))));x=(b[0]+b[2])//2
        q.adb('shell','input','swipe',str(x),str(b[3]-20),str(x),str(b[1]+20),'300');time.sleep(.4)
    raise AssertionError(label)
def event(name):
    q.EVENTS.append({'case':name,'labels':q.labels()});print(name,flush=True)

original={key:q.adb('shell','settings','get','global',key).decode().strip() for key in ['transition_animation_scale','animator_duration_scale']}
try:
    q.click('Settings');q.click('Settings');q.click('App language',scrolled=True);language('Tiếng Việt')
    vi=json.loads(Path('lib/l10n/app_vi.arb').read_text(encoding='utf8'))
    q.shot('after_settings_vietnamese');q.click(vi['video']);q.click(vi['newest'],scrolled=True)
    q.shot('after_sort_vietnamese');event('vietnamese-sort');q.back()
    q.click(vi['settings']);q.click(vi['settings']);q.click(vi['appLanguage'],scrolled=True);language('العربية')
    ar=json.loads(Path('lib/l10n/app_ar.arb').read_text(encoding='utf8'))
    q.adb('shell','wm','size','320x760');q.adb('shell','settings','put','system','font_scale','2.0');time.sleep(1)
    q.click(ar['settings']);q.click(ar['settings']);q.shot('after_settings_arabic_320_text200')
    for _ in range(3):
        q.adb('shell','input','swipe','160','600','160','180','130')
        q.adb('shell','input','swipe','160','200','160','600','130')
    q.rotate(1);q.shot('after_settings_arabic_320_text200_landscape');q.rotate(0);event('rtl-settings-small-large-text-scroll-rotation')
    q.click(ar['video']);q.click(ar['newest'],scrolled=True);q.shot('after_sort_arabic_320_text200');q.back()
    q.adb('shell','wm','size','360x800');q.adb('shell','settings','put','system','font_scale','1.5');time.sleep(.6)
    q.click(ar['settings']);q.click(ar['settings']);q.click(ar['appLanguage'],scrolled=True);language('English')
    q.click('Settings');q.shot('after_settings_360_text150');q.rotate(1);q.rotate(0)
    q.adb('shell','wm','size','393x850');q.adb('shell','settings','put','system','font_scale','1.0');time.sleep(.6)
    q.click('Settings');q.click('Dark',scrolled=True);q.click('Video');q.shot('after_navigation_dark_393')
    q.adb('shell','wm','size','411x920');time.sleep(.6)
    q.click('Settings');q.click('Settings');q.click('Light',scrolled=True)
    for tab,marker in [('Video','Video Library'),('Photo','Photo Library'),('Edit','Editing Studio'),('Settings','Settings')]:
        q.click(tab);q.roundtrip('ui05b_'+tab,marker)
    for key in original:q.adb('shell','settings','put','global',key,'0')
    q.click('Settings');q.click('Create');q.shot('after_create_reduced_motion');q.back();event('reduced-motion-create')
    q.click('Settings');q.click('App language',scrolled=True)
    ns=q.nodes();field=next(n for n in ns if n.get('class')=='android.widget.EditText');b=list(map(int,re.findall(r'\d+',field.get('bounds'))))
    q.tap((b[0]+b[2])//2,(b[1]+b[3])//2);q.adb('shell','input','text','English');time.sleep(.5)
    q.shot('after_language_keyboard');q.back();q.back()
    q.click('Settings');q.click('Settings');q.shot('after_settings_final_light_english');event('restored-light-english')
finally:
    for key,value in original.items():
        q.adb('shell','settings','delete','global',key) if value=='null' else q.adb('shell','settings','put','global',key,value)
    q.adb('shell','wm','size','411x920');q.adb('shell','settings','put','system','font_scale','1.0');q.restore()
    q.save_events('localized_visual_qa')
