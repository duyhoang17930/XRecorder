import qa05b as q
import re,json,time
vi=json.loads(open("lib/l10n/app_vi.arb",encoding="utf8").read())
try:
    q.click('Video');q.click('mới nhất',scrolled=True);q.shot('before_sort_vietnamese');q.back()
    ar=json.loads(open('lib/l10n/app_vi.arb',encoding='utf8').read())
    q.click(ar['settings']);q.click(ar['settings']);q.click(ar['appLanguage'],scrolled=True);q.click(ar['followSystem'])
    q.click('Video')
    n=next(n for n in q.nodes() if 'Edited_ca13829a' in (n.get('content-desc') or n.get('text','')))
    b=list(map(int,re.findall(r'\d+',n.get('bounds'))));q.tap((b[0]+b[2])//2,(b[1]+b[3])//2)
    q.click('Preview');time.sleep(.8);q.shot('before_video_player');q.back();q.back();q.click('Settings')
finally:q.save_events('before_visual_v3')
