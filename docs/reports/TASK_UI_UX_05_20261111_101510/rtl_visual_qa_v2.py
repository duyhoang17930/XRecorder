import qa05 as q
import json,time,re
from pathlib import Path

ar=json.loads(Path('lib/l10n/app_ar.arb').read_text(encoding='utf8'))
def field(text):
    n=next(n for n in q.nodes() if n.get('class')=='android.widget.EditText')
    b=list(map(int,re.findall(r'\d+',n.get('bounds'))));q.tap((b[0]+b[2])//2,(b[1]+b[3])//2)
    q.adb('shell','input','keyevent','123')
    for _ in range(len(n.get('text',''))+8):q.adb('shell','input','keyevent','67')
    if text:q.adb('shell','input','text',text)
    time.sleep(.5)

try:
    q.adb('shell','am','start','-n','com.xrecorder.xrecorder/.MainActivity');time.sleep(1)
    q.click(ar['settings']);q.click(ar['settings'])
    q.adb('shell','wm','size','320x760');q.adb('shell','settings','put','system','font_scale','2.0');time.sleep(1)
    q.shot('after_arabic_app_320_text200_v2');q.EVENTS.append({'case':'rtl-settings-320-text200','labels':q.labels()})
    q.rotate(1);q.shot('after_arabic_app_320_text200_landscape_v2');q.rotate(0)
    q.adb('shell','wm','size','411x920');q.adb('shell','settings','put','system','font_scale','1.0');time.sleep(1)
    q.click(ar['settings']);q.click(ar['appLanguage'],scrolled=True)
    field('English');q.click('English')
    q.click('Settings');q.click('App language',scrolled=True);q.click('Follow system')
    q.click('Settings');q.shot('after_settings_final_dark');q.EVENTS.append({'case':'preferences-restored','labels':q.labels()})
finally:
    q.adb('shell','wm','size','411x920');q.adb('shell','settings','put','system','font_scale',q.BASE['configuration']['fontScale']);q.restore()
    q.save_events('rtl_visual_qa_v2')
