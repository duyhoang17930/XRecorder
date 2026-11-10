import qa03 as q,time
try:
 q.click('Preview',True)
 q.roundtrip('Photo_Preview_v3','Photo preview',True)
 q.back();q.click('Crop & annotate a copy',True)
 q.roundtrip('Photo_Editor_v3','Photo Editor',True)
 print(q.labels(),flush=True)
finally:
 q.restore();q.save_events('orientation_media_run3')
