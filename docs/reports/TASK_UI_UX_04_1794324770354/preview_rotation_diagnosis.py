import qa04 as q,time,re,json
try:
 q.click('Back');q.rotate(1);time.sleep(3);q.shot('video_landscape_paused_settled')
 q.click('Play preview');time.sleep(.4);q.shot('video_landscape_playing')
 time.sleep(2);q.shot('video_landscape_after_play')
 q.rotate(0);time.sleep(1)
 ns=q.nodes();seek=next(n for n in ns if n.get('class')=='android.widget.SeekBar')
 b=list(map(int,re.findall(r'\d+',seek.get('bounds'))));q.tap(205,(b[1]+b[3])//2);time.sleep(1)
 before=q.labels();q.roundtrip('Video_editor_seek','UI04_Editor_QA',False)
 after=q.labels();q.EVENTS.append({'seekBefore':before,'seekAfter':after})
 q.shot('video_editor_seek_after_rotation')
finally:
 q.restore();q.save_events('preview_rotation_diagnosis')
