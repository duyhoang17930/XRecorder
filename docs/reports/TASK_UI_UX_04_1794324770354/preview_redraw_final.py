import qa04 as q,time,re,json
def wait(label):
 for _ in range(6):
  if label in q.labels():return
  time.sleep(.5)
 raise AssertionError(label)
try:
 q.click('Edit');q.click('UI04_Editor_QA',True);wait('Rename project');time.sleep(2)
 seek=next(n for n in q.nodes() if n.get('class')=='android.widget.SeekBar')
 b=list(map(int,re.findall(r'\d+',seek.get('bounds'))));y=(b[1]+b[3])//2
 q.adb('shell','input','swipe',str((b[0]+b[2])//2),str(y),'205',str(y),'500');time.sleep(2)
 q.EVENTS.append({'seekBeforeRotation':q.labels()})
 q.shot('preview_paused_portrait_final')
 q.rotate(1);time.sleep(3);q.shot('preview_paused_landscape_refreshed')
 q.EVENTS.append({'landscapeLabels':q.labels()})
 q.rotate(0);time.sleep(2);q.EVENTS.append({'seekAfterRotation':q.labels()})
 q.click('Effects');wait('Video & audio effects');q.rotate(1);time.sleep(1)
 q.click('Cancel');time.sleep(3);q.shot('preview_paused_after_rotated_effects')
 q.rotate(0);time.sleep(2);q.shot('preview_paused_return_final')
 q.EVENTS.append({'afterEffectsCancel':q.labels()})
finally:
 q.restore();q.save_events('preview_redraw_final')
