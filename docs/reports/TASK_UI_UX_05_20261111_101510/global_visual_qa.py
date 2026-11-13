"""Additional actual-main UI acceptance. Never save media or start capture."""
import qa05 as q
import re,time,json

def field(text):
    candidates=[n for n in q.nodes() if n.get('class')=='android.widget.EditText']
    assert len(candidates)==1
    n=candidates[0];b=list(map(int,re.findall(r'\d+',n.get('bounds'))))
    q.tap((b[0]+b[2])//2,(b[1]+b[3])//2)
    q.adb('shell','input','keyevent','123')
    for _ in range(len(n.get('text',''))+8):q.adb('shell','input','keyevent','67')
    if text:q.adb('shell','input','text',text)
    time.sleep(.5)

def event(name,**extra):
    q.EVENTS.append({'case':name,'labels':q.labels(),**extra})
    print(name,flush=True)

try:
    q.click('Settings');q.click('Settings')
    q.click('Light',scrolled=True);q.click('Video');q.shot('after_navigation_light')
    q.click('Newest');event('sort-root-modal');q.shot('after_sort_modal_light');q.back()
    field('UI04');q.shot('after_search_keyboard_light');event('search-keyboard')
    q.back();field('');q.back()
    for tab,marker in [('Video','Video Library'),('Photo','Photo Library'),('Edit','Edit'),('Settings','Settings')]:
        q.click(tab);q.roundtrip('global_'+tab,marker)
    q.click('Settings')
    for _ in range(5):
        q.adb('shell','input','swipe','205','750','205','130','140')
        q.adb('shell','input','swipe','205','160','205','750','140')
    q.shot('after_settings_repeated_scroll_light');event('settings-stretch-attempt-10-fast-flings')
    q.click('Settings');q.click('View introduction',scrolled=True)
    for page in range(3):
        q.shot('after_onboarding_light_'+str(page+1));event('onboarding-light-'+str(page+1))
        if page<2:q.click('Next')
    q.rotate(1);q.shot('after_onboarding_landscape_light');q.rotate(0);q.click('Get Started')
    q.click('Settings');q.click('Dark',scrolled=True);q.click('Settings')
    q.click('View introduction',scrolled=True)
    for page in range(3):
        q.shot('after_onboarding_dark_'+str(page+1))
        if page<2:q.click('Next')
    q.click('Get Started');q.click('Settings');q.click('App language',scrolled=True)
    field('ar');q.click('العربية');q.back()
    q.adb('shell','wm','size','320x760');q.adb('shell','settings','put','system','font_scale','2.0');time.sleep(1)
    q.shot('after_arabic_320_text200');event('arabic-320-text200')
    q.rotate(1);q.shot('after_arabic_320_text200_landscape');q.rotate(0)
    q.adb('shell','wm','size','411x920');q.adb('shell','settings','put','system','font_scale','1.0');time.sleep(1)
    q.click('الإعدادات');q.click('لغة التطبيق',scrolled=True)
    field('English');q.click('English');q.back()
    q.click('App language',scrolled=True);q.click('Follow system');q.back()
    q.click('Settings');q.shot('after_settings_final_dark');event('restored-system-language-dark')
finally:
    q.adb('shell','wm','size','411x920');q.adb('shell','settings','put','system','font_scale',q.BASE['configuration']['fontScale']);q.restore()
    q.save_events('global_visual_qa')
