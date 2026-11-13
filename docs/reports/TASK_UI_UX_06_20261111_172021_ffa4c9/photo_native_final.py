from qa06_interactions import *
try:
    for _ in range(5):
        if 'Create' in q.labels():break
        q.back()
    q.click('Edit');q.click('Edit')
    with Video('UI06_final_photo_workflow_v2'):
        q.click('Edit photo');q.click('Edited_1794327406739.png')
        q.shot('final_v2_photo_workspace')
        tool('Crop');q.shot('final_v2_photo_crop')
        seek=[n for n in q.nodes() if n.get('class')=='android.widget.SeekBar']
        assert len(seek)==4
        b=bounds(seek[1]);y=(b[1]+b[3])//2
        q.adb('shell','input','swipe',str((b[0]+b[2])//2),str(y),str((b[0]+b[2])//2-35),str(y),'350')
        event('photo-crop-range')
        tool('Text');field('UI06');q.back();panel('Apply')
        q.shot('final_v2_photo_text_applied')
        tool('Drawing');q.click('Color');q.shot('final_v2_photo_color_picker')
        q.click('Cyan ink')
        seek=[n for n in q.nodes() if n.get('class')=='android.widget.SeekBar'];assert len(seek)==1
        b=bounds(seek[0]);y=(b[1]+b[3])//2
        # Both endpoints and repeated dragging preserve the .002..02 invariant.
        for start,end in [((b[0]+b[2])//2,371),(371,40),(40,205)]:
            q.adb('shell','input','swipe',str(start),str(y),str(end),str(y),'180')
        q.adb('shell','input','swipe','95','280','290','330','700')
        q.click('Undo photo edit');q.click('Redo photo edit')
        q.shot('final_v2_photo_drawing')
        event('photo-color-width-draw-history')
        tool('Transform');panel('Rotate 90°')
        q.rotate(1);q.shot('final_v2_photo_landscape');q.rotate(0)
        q.adb('shell','input','keyevent','3');time.sleep(.5)
        q.adb('shell','am','start','-n','com.xrecorder.xrecorder/.MainActivity')
        q.shot('final_v2_photo_after_resume')
        q.click('Save copy');time.sleep(2)
        q.shot('final_v2_photo_saved')
        event('photo-save-copy')
finally:q.restore();q.save_events('photo_native_final_v2')
