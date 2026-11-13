from qa06_interactions import *
try:
    q.click('Edit');q.click('Edit');before=projects()
    with Video('UI06_acceptance_video_interactions'):
        q.click('New video project')
        q.click('Edited_ca13829a-b90f-4ac0-96f1-8723256517db.mp4')
        q.click('Photos');q.click('Edited_1794327406739.png');q.click('Add clip · 2 clips')
        created=projects()-before;assert len(created)==1;name=created.pop()
        q.click('Rename project');q.click('Clear text');field('UI06_Acceptance');q.click('Save name')
        time.sleep(1);q.shot('acceptance_video_workspace')
        play=next(n for n in q.nodes() if n.get('content-desc')=='Play preview');b=bounds(play)
        x=(b[0]+b[2])//2;y=(b[1]+b[3])//2
        q.adb('shell','input','tap',str(x),str(y));time.sleep(1)
        q.adb('shell','input','tap',str(x),str(y));time.sleep(.3)
        slider=[n for n in q.nodes() if n.get('class')=='android.widget.SeekBar'][-1]
        b=bounds(slider);x=(b[0]+b[2])//2;y=(b[1]+b[3])//2
        original=read_project(name)
        q.adb('shell','input','swipe',str(x),str(y),str(x-22),str(y),'350');time.sleep(.4)
        trimmed=read_project(name);assert trimmed['clips'][0]['outMs']<original['clips'][0]['outMs']
        tool('Edit')
        transport=next(n for n in q.nodes() if n.get('class')=='android.widget.SeekBar');b=bounds(transport)
        q.adb('shell','input','tap','85',str((b[1]+b[3])//2))
        labels=q.labels();q.EVENTS.append({'case':'split-playhead','labels':labels})
        q.click('Split');time.sleep(.4);assert len(read_project(name)['clips'])==3
        q.click('Undo edit');time.sleep(.3);assert len(read_project(name)['clips'])==2
        q.click('Redo edit');time.sleep(.3);assert len(read_project(name)['clips'])==3
        tool('Effects');q.shot('acceptance_video_effects')
        q.click('Color filter');q.click('Grayscale');q.click('Apply to project')
        time.sleep(.5);assert read_project(name)['effects']['filter']=='grayscale'
        q.click('Undo edit');time.sleep(.3);assert read_project(name)['effects'].get('filter')!='grayscale'
        q.click('Redo edit');time.sleep(.3);assert read_project(name)['effects']['filter']=='grayscale'
        q.rotate(1);q.labels();q.shot('acceptance_video_landscape');q.rotate(0)
        q.shot('acceptance_video_split_effects_applied');event('video-final-apk-history-effects-rotation')
        q.click('Export');time.sleep(1.2);q.shot('acceptance_export_queue');event('video-final-apk-export')
    with (q.ROOT/'acceptance_video_project.json').open('x',encoding='utf8') as f:json.dump({'file':name,'project':read_project(name)},f,indent=2)
finally:q.restore();q.save_events('acceptance_video_qa')
