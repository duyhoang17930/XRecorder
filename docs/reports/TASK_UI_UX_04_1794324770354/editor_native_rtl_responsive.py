import qa04 as q,time,re,json,pathlib
ar=json.loads(pathlib.Path('lib/l10n/app_ar.arb').read_text(encoding='utf8'))
rtl=False

def shell():
 for _ in range(6):
  text=q.labels()
  if 'Create' in text or ar['create'] in text:return
  q.back()
 raise AssertionError('Shell not reached')

def record(name):
 time.sleep(2);q.shot(name)
 q.EVENTS.append({'screen':name,'labels':q.labels(),'size':q.pixels()[1]})

try:
 shell();q.click('Settings');q.click('Settings');q.click('Light',True)
 q.click('Edit');q.click('UI04_Editor_QA',True);q.click('Effects');record('effects_video_light_final')
 q.rotate(1);record('effects_video_light_landscape_final');q.click('Cancel');q.rotate(0)
 shell();q.click('Settings');q.click('Settings');q.click('Dark',True)
 q.click('App language',True)
 n=next(n for n in q.nodes() if n.get('class')=='android.widget.EditText')
 x1,y1,x2,y2=map(int,re.findall(r'\d+',n.get('bounds')))
 q.tap((x1+x2)//2,(y1+y2)//2);q.adb('shell','input','text','ar');q.click('العربية');rtl=True
 q.click(ar['photo']);q.click(ar['chooseFolder']);q.click('USE THIS FOLDER');q.click('ALLOW')
 q.click('slider_fixture.png',True);q.click(ar['cropAnnotateACopy'],True)
 q.click(ar['editorAllTools']);q.click(ar['editorCrop'])
 q.rotate(1);record('photo_crop_selected_latest_landscape');q.rotate(0)
 q.click(ar['editorAllTools']);q.click(ar['pen'])
 q.adb('shell','wm','size','320x920');q.adb('shell','settings','put','system','font_scale','2.0')
 q.adb('shell','settings','put','global','animator_duration_scale','0');record('photo_ar_320_text200_reduce')
 q.click(ar['editorColor']);record('color_ar_320_text200_reduce')
 q.rotate(1);record('color_ar_landscape_text200_reduce');q.back();q.rotate(0)
 for width,scale in [(360,'1.5'),(393,'1.0'),(411,'1.0')]:
  q.adb('shell','wm','size',str(width)+'x920');q.adb('shell','settings','put','system','font_scale',scale);time.sleep(1)
  labels=q.labels();assert ar['saveCopy'] in labels,labels
  q.EVENTS.append({'screen':'Photo responsive RTL','width':width,'scale':scale,'labels':labels,'size':q.pixels()[1]})
 q.adb('shell','wm','size','320x920');q.adb('shell','settings','put','system','font_scale','2.0')
 shell();q.click(ar['edit']);q.click('UI04_Editor_QA',True);q.click(ar['effects']);record('effects_ar_320_text200_reduce')
 q.rotate(1);record('effects_ar_landscape_text200_reduce');q.click(ar['cancel']);q.rotate(0)
 shell();q.click(ar['settings']);q.click(ar['settings']);q.click(ar['appLanguage'],True);q.click(ar['followSystem']);rtl=False
finally:
 q.adb('shell','wm','size',q.BASE['configuration']['size'].split('Override size: ')[-1])
 q.adb('shell','settings','put','system','font_scale',q.BASE['configuration']['fontScale'])
 if q.BASE['configuration']['animator']=='null':q.adb('shell','settings','delete','global','animator_duration_scale')
 else:q.adb('shell','settings','put','global','animator_duration_scale',q.BASE['configuration']['animator'])
 q.restore();q.save_events('editor_native_rtl_responsive')
 if rtl:print('RESTORE APP LOCALE THROUGH UI REQUIRED',flush=True)
