import qa03 as q,time,json,re,pathlib
ar=json.loads(pathlib.Path('lib/l10n/app_ar.arb').read_text(encoding='utf8'))
rtl=False
def input_field(text):
 n=next(n for n in q.nodes() if n.get('class')=='android.widget.EditText')
 x1,y1,x2,y2=map(int,re.findall(r'\d+',n.get('bounds')))
 q.tap((x1+x2)//2,(y1+y2)//2)
 q.adb('shell','input','text',text);time.sleep(.8)
try:
 q.click('App language',True)
 input_field('ar')
 q.click('العربية');rtl=True
 q.click(ar['viewIntroduction'],True)
 q.adb('shell','wm','size','320x920')
 q.adb('shell','settings','put','system','font_scale','2.0')
 q.adb('shell','settings','put','global','animator_duration_scale','0')
 time.sleep(1)
 for page in range(3):
  if page==0:q.shot('onboarding_ar_320_text200_reduce_motion')
  texts=q.labels();q.EVENTS.append({'screen':'onboarding RTL','page':page,'size':q.pixels()[1],'labels':texts,'fontScale':'2.0','animatorScale':'0'})
  assert ar['onboardingGetStarted' if page==2 else 'onboardingNext'] in texts
  q.click(ar['onboardingGetStarted' if page==2 else 'onboardingNext'])
 q.click(ar['appLanguage'],True);q.click(ar['followSystem']);rtl=False
 for width,scale in [(320,'2.0'),(360,'1.5'),(393,'1.0'),(411,'1.0')]:
  q.adb('shell','wm','size',str(width)+'x920')
  q.adb('shell','settings','put','system','font_scale',scale);time.sleep(.7)
  q.click('Settings')
  ns=q.nodes();targets=[]
  for n in ns:
   if n.get('clickable')=='true' and (n.get('content-desc') or n.get('text')) in ['Video','Photo','Edit','Settings','Create']:
    bounds=list(map(int,re.findall(r'\d+',n.get('bounds'))));targets.append({'label':n.get('content-desc') or n.get('text'),'bounds':bounds})
    assert bounds[2]-bounds[0]>=48 and bounds[3]-bounds[1]>=48
  assert len(targets)==5
  q.EVENTS.append({'screen':'Settings navigation','width':width,'scale':scale,'targets':targets,'labels':q.labels()})
  if width==320:q.shot('settings_320_text200_dark')
 q.click('View introduction',True);q.shot('onboarding_dark_final')
 q.rotate(1);time.sleep(1);q.shot('onboarding_dark_landscape_final');q.rotate(0)
 q.click('Skip')
 q.click('About & licenses',True);q.back()
 q.shot('settings_help_about_clean')
finally:
 q.adb('shell','wm','size',q.BASE['configuration']['size'].split('Override size: ')[-1])
 q.adb('shell','settings','put','system','font_scale',q.BASE['configuration']['fontScale'])
 if q.BASE['configuration']['animator']=='null':q.adb('shell','settings','delete','global','animator_duration_scale')
 else:q.adb('shell','settings','put','global','animator_duration_scale',q.BASE['configuration']['animator'])
 q.restore();q.save_events('responsive_run11')
 if rtl:print('Locale needs UI restore from Arabic to Follow system',flush=True)
