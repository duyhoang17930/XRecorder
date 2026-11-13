import qa05b as q
import re,json,time

def choose_language(query,label):
    n=next(n for n in q.nodes() if n.get('class')=='android.widget.EditText')
    b=list(map(int,re.findall(r'\d+',n.get('bounds'))));q.tap((b[0]+b[2])//2,(b[1]+b[3])//2)
    q.adb('shell','input','text',query)
    n=next(n for n in q.nodes() if n.get('class')!='android.widget.EditText' and (n.get('content-desc') or n.get('text',''))==label)
    b=list(map(int,re.findall(r'\d+',n.get('bounds'))));q.tap((b[0]+b[2])//2,(b[1]+b[3])//2)

try:
    q.click('Settings');q.click('Settings');q.shot('before_settings_capture')
    q.click('Video quality');q.shot('before_recording_destination');q.back()
    for tab in ['Video','Photo','Edit','Settings']:
        q.click(tab);q.click(tab);q.shot('before_header_'+tab.lower())
    q.click('App language',scrolled=True);choose_language('vi','Tiếng Việt')
    q.click('Video');q.click('mới nhất',scrolled=True);q.shot('before_sort_vietnamese');q.back()
    ar=json.loads(open('lib/l10n/app_vi.arb',encoding='utf8').read())
    q.click(ar['settings']);q.click(ar['settings']);q.click(ar['appLanguage'],scrolled=True);q.click(ar['followSystem'])
    q.click('Video')
    n=next(n for n in q.nodes() if 'Edited_ca13829a' in (n.get('content-desc') or n.get('text','')))
    b=list(map(int,re.findall(r'\d+',n.get('bounds'))));q.tap((b[0]+b[2])//2,(b[1]+b[3])//2)
    q.click('Preview');time.sleep(.8);q.shot('before_video_player');q.back();q.back();q.click('Settings')
finally:q.save_events('before_visual')
