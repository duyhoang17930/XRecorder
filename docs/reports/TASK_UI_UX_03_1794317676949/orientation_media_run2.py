import qa03 as q,time,re
try:
 q.click('slider_fixture.png')
 q.roundtrip('Media_Details','slider_fixture.png',True)
 q.click('Preview',True)
 q.roundtrip('Photo_Preview','Photo preview',True)
 q.back();q.click('Crop & annotate a copy',True)
 q.roundtrip('Photo_Editor','Photo Editor',True)
 print(q.labels(),flush=True)
finally:
 q.restore();q.save_events('orientation_media_run2')
