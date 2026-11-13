from qa06_interactions import *
try:
    q.back();q.click('Edit');q.click('Edit');before=projects()
    with Video('UI06_final_video_workflow_v2'):
        q.click('New video project')
        q.click('Edited_ca13829a-b90f-4ac0-96f1-8723256517db.mp4')
        q.click('Photos');q.click('Edited_1794327406739.png')
        q.click('Add clip · 2 clips');time.sleep(.8)
        added=projects()-before;assert len(added)==1
        name=added.pop()
        q.click('Rename project');q.click('Clear text');field('UI06_Final_Video_V2');q.click('Save name')
        q.shot('final_v2_video_workspace');event('new-project-with-two-picked-clips')
        play=next(n for n in q.nodes() if n.get('content-desc')=='Play preview')
        p=bounds(play);px=(p[0]+p[2])//2;py=(p[1]+p[3])//2
        q.adb('shell','input','tap',str(px),str(py));time.sleep(1.0)
        q.adb('shell','input','tap',str(px),str(py));time.sleep(.4)
        # First SeekBar is transport; subsequent pair are selected trim handles.
        seek=[n for n in q.nodes() if n.get('class')=='android.widget.SeekBar']
        assert len(seek)>=3
        x1,y1,x2,y2=bounds(seek[0]);y=(y1+y2)//2
        q.adb('shell','input','swipe',str((x1+x2)//2),str(y),'85',str(y),'350')
        time.sleep(.4)
        selected=read_project(name)['clips'][0]
        # Commit an actual trim on the right endpoint, not only a scrub.
        x1,y1,x2,y2=bounds(seek[-1]);y=(y1+y2)//2
        q.adb('shell','input','swipe',str((x1+x2)//2),str(y),str((x1+x2)//2-22),str(y),'400')
        time.sleep(.6)
        trimmed=read_project(name)['clips'][0]
        q.EVENTS.append({'case':'trim-native','before':selected,'after':trimmed})
        assert trimmed['outMs']<selected['outMs'],(selected,trimmed)
        tool('Edit');q.click('Split');time.sleep(.6)
        split=read_project(name);assert len(split['clips'])==3,split
        q.click('Undo edit');time.sleep(.5);assert len(read_project(name)['clips'])==2
        q.click('Redo edit');time.sleep(.5);assert len(read_project(name)['clips'])==3
        tool('Effects');q.shot('final_v2_video_effects')
        q.click('Color filter');q.click('Grayscale');q.click('Apply to project')
        time.sleep(.6)
        assert read_project(name)['effects']['filter']=='grayscale'
        q.rotate(1);q.shot('final_v2_video_landscape');q.rotate(0)
        event('trim-split-effects-history-rotation')
        q.click('Export');time.sleep(2)
        q.shot('final_v2_export_queue_started')
        event('export-started-from-editor')
    with (q.ROOT/'final_v2_video_project.json').open('x',encoding='utf8') as f:
        json.dump({'file':name,'project':read_project(name)},f,indent=2)
finally:q.restore();q.save_events('video_native_final_v2')
