import qa03 as q,time,json,pathlib,re
ar=json.loads(pathlib.Path('lib/l10n/app_ar.arb').read_text(encoding='utf8'))
rtl=False
try:
 q.click('Settings');q.click('App language',True)
 n=next(n for n in q.nodes() if n.get('class')=='android.widget.EditText')
 x1,y1,x2,y2=map(int,re.findall(r'\d+',n.get('bounds')))
 q.tap((x1+x2)//2,(y1+y2)//2);q.adb('shell','input','text','ar')
 q.click('\u0627\u0644\u0639\u0631\u0628\u064a\u0629')
 rtl=True;q.click(ar['viewIntroduction'],True)
 q.adb('shell','wm','size','320x920')
 q.adb('shell','settings','put','system','font_scale','2.0')
 q.adb('shell','settings','put','global','animator_duration_scale','0')
 time.sleep(4)
 for page in range(3):
  texts=q.labels();q.EVENTS.append({'page':page,'labels':texts,'size':q.pixels()[1],'fontScale':2,'animatorScale':0})
  assert ar['onboardingGetStarted' if page==2 else 'onboardingNext'] in texts
  if page==0:q.shot('onboarding_rtl_320_200_settled')
  q.click(ar['onboardingGetStarted' if page==2 else 'onboardingNext'])
 q.click(ar['settings']);q.click(ar['appLanguage'],True);q.click(ar['followSystem']);rtl=False
 q.click('Video')
finally:
 q.adb('shell','wm','size',q.BASE['configuration']['size'].split('Override size: ')[-1])
 q.adb('shell','settings','put','system','font_scale',q.BASE['configuration']['fontScale'])
 if q.BASE['configuration']['animator']=='null':q.adb('shell','settings','delete','global','animator_duration_scale')
 else:q.adb('shell','settings','put','global','animator_duration_scale',q.BASE['configuration']['animator'])
 q.restore();q.save_events('rtl_settled_run14')
 if rtl:print('Locale still needs restoration',flush=True)
