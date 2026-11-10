import qa04 as q,time,re

def wait(label):
 for _ in range(6):
  labels=q.labels()
  if any(t.split('\n')[0]==label for t in labels):return labels
  time.sleep(.5)
 raise AssertionError(label)

def tool(label):
 q.click('All tools');q.click(label)

try:
 q.click('Transform');q.click('Rotate 90°');q.click('Undo photo edit');q.shot('photo_transform_light_final')
 tool('Pen');q.click('Export quality');q.roundtrip('photo_export_options_final','Export quality',True);q.click('Cancel')
 # Minimum/maximum and rapid drags use the real track rather than the thumb's semantics bounds.
 seek=next(n for n in q.nodes() if n.get('class')=='android.widget.SeekBar')
 b=list(map(int,re.findall(r'\d+',seek.get('bounds'))));y=(b[1]+b[3])//2
 q.adb('shell','input','swipe',str((b[0]+b[2])//2),str(y),'55',str(y),'250')
 q.adb('shell','input','swipe','55',str(y),'355',str(y),'250')
 q.adb('shell','input','swipe','355',str(y),'55',str(y),'200')
 q.EVENTS.append({'screen':'Photo slider endpoints','labels':q.labels()})
 # Create a reversible QA mark and verify Keep editing, then discard only this fixture session.
 q.adb('shell','input','swipe','90','360','220','410','400');time.sleep(.5)
 q.back();wait('Keep editing');q.shot('photo_unsaved_guard_final');q.click('Keep editing')
 q.back();q.click('Discard edits',True)
 q.back();q.click('Settings');q.click('Settings');q.click('Dark',True)
finally:
 q.restore();q.save_events('photo_keyboard_light_complete')
