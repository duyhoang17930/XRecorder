import qa03 as q,time,json,subprocess,uuid
def checkpoint(name,marker,save=False):
 result=q.roundtrip(name,marker,save);print(name,[(r['rotation'],r['size'],r['markerFound']) for r in result],flush=True)
try:
 remote='/sdcard/ui03_cold_'+uuid.uuid4().hex+'.mp4'
 rec=subprocess.Popen(q.ADB+['shell','screenrecord','--bit-rate','700000','--time-limit','30',remote],creationflags=subprocess.CREATE_NO_WINDOW)
 time.sleep(.5);start=time.monotonic()
 timing=q.adb('shell','am','start','-W','-n','com.xrecorder.xrecorder/.MainActivity')
 (q.ROOT/'cold_start.txt').open('xb').write(timing)
 print(timing.decode(),flush=True)
 rec.wait();q.adb('pull',remote,str(q.ROOT/'cold_start_no_custom_splash.mp4'))
 q.shot('home_after_no_splash')
 # Rotation recording only covers UI; app recording/capture is never invoked.
 remote='/sdcard/ui03_rotation_'+uuid.uuid4().hex+'.mp4'
 rec=subprocess.Popen(q.ADB+['shell','screenrecord','--bit-rate','700000','--time-limit','25',remote],creationflags=subprocess.CREATE_NO_WINDOW)
 q.click('Video')
 checkpoint('Videos','Video Library',True)
 q.click('Photo');checkpoint('Photos','Photo Library')
 q.click('Edit');checkpoint('Edit','Editing Studio')
 q.click('Settings');checkpoint('Settings','Settings',True)
 rec.wait();q.adb('pull',remote,str(q.ROOT/'rotation_main_tabs.mp4'))
 q.click('View introduction',True)
 for page in range(3):
  time.sleep(1);q.shot('onboarding_final_'+str(page+1))
  if page==0:checkpoint('Onboarding','Record Anything',True)
  q.click('Get Started' if page==2 else 'Next')
 print('onboarding controls complete',flush=True)
 q.click('Help & guides',True)
 checkpoint('Help','Help & guides',True)
 q.back();q.click('About & licenses',True)
 checkpoint('About_dialog','MxT APP',True);q.back()
finally:
 q.restore();q.save_events('orientation_main_run1')

