import qa04 as q,re,time
try:
 q.click('Photo');q.click('slider_fixture.png',True);q.click('Crop & annotate a copy',True)
 time.sleep(2);q.shot('photo_dark_latest_apk')
 def seek_to(x):
  node=next(n for n in q.nodes() if n.get('class')=='android.widget.SeekBar')
  a,b,c,d=map(int,re.findall(r'\d+',node.get('bounds')));y=(b+d)//2
  q.adb('shell','input','swipe',str((a+c)//2),str(y),str(x),str(y),'250');time.sleep(.3)
 seek_to(409);labels=q.labels();assert '5 pixels' in labels,labels
 q.EVENTS.append({'endpoint':'maximum','labels':labels})
 seek_to(1);labels=q.labels();assert '2 pixels' in labels,labels
 q.EVENTS.append({'endpoint':'minimum','labels':labels})
 q.click('Color');q.shot('color_dark_latest_apk');q.back()
 q.back();q.back();q.click('Edit');q.click('UI04_Editor_QA',True);time.sleep(2)
 q.shot('video_preview_latest_apk')
finally:
 q.restore();q.save_events('final_photo_boundaries')
