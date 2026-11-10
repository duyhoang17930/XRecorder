import qa03 as q,time
try:
 q.roundtrip('Video_Editor','Video project',True)
 assert any('3H_2e625c63' in t for t in q.labels())
 q.click('Play preview');time.sleep(.5)
 q.shot('video_native_preview_playing')
 q.EVENTS.append({'afterPlay':q.labels()})
 q.back();q.click('Settings');q.click('App language',True)
 q.roundtrip('Language_dialog','App language',True)
 print(q.labels(),flush=True)
finally:
 q.restore();q.save_events('orientation_video_run5')
