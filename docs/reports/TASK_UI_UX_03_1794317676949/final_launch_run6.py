import qa03 as q,subprocess,time,uuid,json
remote='/sdcard/ui03_final_launch_'+uuid.uuid4().hex+'.mp4'
rec=subprocess.Popen(q.ADB+['shell','screenrecord','--bit-rate','700000','--time-limit','25',remote],creationflags=subprocess.CREATE_NO_WINDOW)
time.sleep(.5)
start=time.monotonic()
timing=q.adb('shell','am','start','-W','-n','com.xrecorder.xrecorder/.MainActivity')
with (q.ROOT/'final_cold_start.txt').open('xb') as f:f.write(timing)
print(timing.decode(),flush=True)
rec.wait();q.adb('pull',remote,str(q.ROOT/'final_cold_start.mp4'))
print(q.labels(),flush=True)
q.shot('final_build_home_light')
q.click('Settings');q.click('View introduction',True)
for i in range(3):
 time.sleep(1.2);q.shot('final_build_onboarding_'+str(i+1))
 if i==2:
  try:
   q.roundtrip('Final_onboarding_landscape','Smart Subtitles',True)
  finally:q.restore()
 q.click('Get Started' if i==2 else 'Next')
q.save_events('final_launch_run6')
