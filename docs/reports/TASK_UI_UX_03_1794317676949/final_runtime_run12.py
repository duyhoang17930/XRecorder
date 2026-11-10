import qa03 as q,time,re,json
try:
 q.click('Settings');q.click('App language',True)
 n=next(n for n in q.nodes() if n.get('class')=='android.widget.EditText')
 x1,y1,x2,y2=map(int,re.findall(r'\d+',n.get('bounds')))
 q.tap((x1+x2)//2,(y1+y2)//2);q.adb('shell','input','text','ar')
 for r in [1,0]:
  size=q.rotate(r);time.sleep(2)
  texts=q.labels();assert 'ar' in texts
  ime=q.adb('shell','dumpsys','input_method').decode()
  q.EVENTS.append({'screen':'Language search IME final','size':size,'rotation':r,'labels':texts,'imeState':[s.strip() for s in ime.splitlines() if 'mInputShown=' in s or 'mShowRequested=' in s]})
  if r:q.shot('language_keyboard_landscape_final')
 q.click('Close')
 for width,scale in [(320,'2.0'),(360,'1.5'),(393,'1.0'),(411,'1.0')]:
  q.adb('shell','wm','size',str(width)+'x920')
  q.adb('shell','settings','put','system','font_scale',scale);time.sleep(3)
  q.click('Settings')
  ns=q.nodes();targets=[]
  for n in ns:
   if n.get('clickable')=='true' and (n.get('content-desc') or n.get('text')) in ['Video','Photo','Edit','Settings','Create']:
    bounds=list(map(int,re.findall(r'\d+',n.get('bounds'))));targets.append({'label':n.get('content-desc') or n.get('text'),'bounds':bounds})
    assert bounds[2]-bounds[0]>=48 and bounds[3]-bounds[1]>=48
  assert len(targets)==5
  q.EVENTS.append({'screen':'Settings navigation final','width':width,'scale':scale,'size':q.pixels()[1],'targets':targets,'labels':q.labels()})
  if width==320:q.shot('settings_320_text200_dark_settled')
 q.click('View introduction',True);time.sleep(2);q.shot('onboarding_dark_final')
 q.rotate(1);time.sleep(2);q.shot('onboarding_dark_landscape_final');q.rotate(0)
 q.click('Skip');q.click('Settings');q.click('About & licenses',True);q.back()
 q.shot('settings_help_about_clean')
finally:
 q.adb('shell','wm','size',q.BASE['configuration']['size'].split('Override size: ')[-1])
 q.adb('shell','settings','put','system','font_scale',q.BASE['configuration']['fontScale'])
 q.restore();q.save_events('final_runtime_run12')
