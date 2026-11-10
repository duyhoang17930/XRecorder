import qa03 as q,time
try:
 q.click('3H_ea491dd5_Edited_a89b00bf-db24-4779-8be8-74cb5d385f87.mp4',True)
 q.click('Preview',True)
 for r in [0,1,0]:
  size=q.rotate(r);time.sleep(.8)
  activity=q.adb('shell','dumpsys','activity','activities').decode()
  resumed=[s for s in activity.splitlines() if 'topResumedActivity=' in s]
  assert any('VideoPreviewActivity' in s for s in resumed)
  q.shot('Native_video_preview_'+str(r)+'_'+str(len(q.EVENTS)))
  q.EVENTS.append({'screen':'Native Video Preview','rotation':r,'size':size,'resumedActivity':resumed})
 q.back();q.back();q.click('Settings');q.click('Settings')
 q.click('Dark',True);q.click('Settings');q.shot('final_nav_dark')
 q.click('App language',True)
 print(q.labels(),flush=True)
finally:
 q.restore();q.save_events('orientation_preview_run8')
