"""Compact actual-main-app interaction evidence; only QA fixture edits, no save."""
import qa05 as q,re,time,subprocess,uuid,json
def rect(label):
 for n in sorted(q.nodes(),key=lambda n:n.get('clickable')!='true'):
  if (n.get('content-desc') or n.get('text','')).split('\n')[0]==label:
   b=list(map(int,re.findall(r'\d+',n.get('bounds'))))
   if b[2]>b[0] and b[3]>b[1]:return b
 raise AssertionError(label)
def tap(b,delay=.35):q.adb('shell','input','tap',str((b[0]+b[2])//2),str((b[1]+b[3])//2));time.sleep(delay)
def wait(label):
 for _ in range(5):
  labels=q.labels()
  if any(v.split('\n')[0]==label for v in labels):return labels
  time.sleep(.5)
 raise AssertionError(label)
old_shot=q.shot
q.shot=lambda name:old_shot(name+'_v2')
q.back()
rec=None
try:
 q.click('Settings');nav={name:rect(name) for name in ['Video','Photo','Edit','Settings','Create']}
 assert all(b[2]-b[0]>=48 and b[3]-b[1]>=48 for b in nav.values())
 q.click('Photo');fixture=rect('slider_fixture.png');tap(fixture);edit=rect('Crop & annotate a copy');q.back();q.click('Video')
 remote='/sdcard/ui05_motion_'+uuid.uuid4().hex+'.mp4'
 rec=subprocess.Popen(q.ADB+['shell','screenrecord','--bit-rate','800000','--time-limit','75',remote],creationflags=subprocess.CREATE_NO_WINDOW)
 time.sleep(.4)
 for tab in ['Photo','Edit','Settings','Video','Settings']:tap(nav[tab])
 for _ in range(3):q.adb('shell','input','swipe','205','690','205','180','200')
 bottom=q.labels();tap(nav['Video']);tap(nav['Settings']);returned=q.labels()
 assert bottom==returned,(bottom,returned)
 tap(nav['Settings'],.6);top=q.labels();assert any(t.startswith('Video quality') for t in top),top
 q.shot('after_settings_reselected_top');q.EVENTS.append({'branchScrollRetained':True,'reselectTop':True,'navTargets':nav})
 tap(nav['Create'],.6)
 wait('Screen recording');q.shot('after_create_modal')
 buttons=[n for n in q.nodes() if n.get('clickable')=='true' and (n.get('content-desc') or n.get('text','')).split('\n')[0]=='Screen recording']
 assert len(buttons)==1,len(buttons)
 q.back();tap(nav['Photo']);tap(fixture);tap(edit);wait('Stroke width')
 ink=rect('Color');undo=rect('Undo photo edit');redo=rect('Redo photo edit')
 tap(ink);wait('Cyan ink');q.shot('after_color_picker_visual');q.click('Cyan ink')
 q.adb('shell','input','swipe','70','350','300','390','500');time.sleep(.3)
 tap(undo);tap(redo);q.click('All tools');q.click('Rectangle');q.shot('after_selected_rectangle')
 q.rotate(1);time.sleep(.6);q.shot('after_photo_landscape_visual');q.rotate(0);time.sleep(.6)
 q.back();wait('Keep editing');q.click('Keep editing');tap(undo);q.back();q.back()
 q.adb('shell','settings','put','global','animator_duration_scale','0');time.sleep(.7)
 for tab in ['Edit','Video','Settings','Photo']:tap(nav[tab],.14)
 q.shot('after_reduced_motion_navigation');q.EVENTS.append({'reducedMotionSetting':'0','labels':q.labels()})
 q.adb('shell','input','keyevent','3');time.sleep(.4)
 q.adb('shell','am','start','-n','com.xrecorder.xrecorder/.MainActivity');time.sleep(.8)
 assert 'Create' in q.labels()
 q.EVENTS.append({'backgroundForeground':True})
 rec.wait(timeout=90)
 blob=q.adb('exec-out','cat',remote,timeout=60)
 with (q.ROOT/'UI05_motion_interactions_v2.mp4').open('xb') as f:f.write(blob)
 print('Native sequence completed; video bytes='+str(len(blob)),flush=True)
finally:
 if rec is not None and rec.poll() is None:rec.wait(timeout=90)
 if q.BASE['configuration']['animator']=='null':q.adb('shell','settings','delete','global','animator_duration_scale')
 else:q.adb('shell','settings','put','global','animator_duration_scale',q.BASE['configuration']['animator'])
 q.restore();q.save_events('main_visual_qa_v2')
