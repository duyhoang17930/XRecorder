from qa06_interactions import *
try:
    q.adb('shell','am','start','-W','-n','com.xrecorder.xrecorder/.MainActivity')
    q.adb('shell','wm','size','360x800');q.adb('shell','settings','put','system','font_scale','1.5');time.sleep(1.5)
    q.click('Edit');q.click('Edit');before=projects()
    with Video('UI06_acceptance_photo_interactions'):
        q.click('Edit photo');q.click('Edited_1794327406739.png');time.sleep(.5)
        tool('Text');field('UI06_final');q.shot('acceptance_photo_keyboard_360_text150')
        q.back();panel('Apply');event('text150-toolbar-selection-and-apply')
        tool('Drawing');q.click('Color');q.shot('acceptance_photo_color_picker')
        q.click('Cyan ink')
        slider=next(n for n in q.nodes() if n.get('class')=='android.widget.SeekBar')
        b=bounds(slider);y=(b[1]+b[3])//2
        for start,end in [((b[0]+b[2])//2,320),(320,40),(40,170)]:
            q.adb('shell','input','swipe',str(start),str(y),str(end),str(y),'180')
        q.adb('shell','input','swipe','85','250','265','290','550')
        q.click('Undo photo edit');q.click('Redo photo edit')
        q.shot('acceptance_photo_marks_360_text150')
        q.rotate(1);q.shot('acceptance_photo_landscape_360_text150');q.rotate(0)
        q.adb('shell','input','keyevent','3');time.sleep(.5)
        q.adb('shell','am','start','-n','com.xrecorder.xrecorder/.MainActivity')
        assert 'Save copy' in q.labels();q.shot('acceptance_photo_resumed')
        q.click('Save copy');assert 'Media details' in q.labels()
        q.shot('acceptance_photo_saved_details');event('save-copy-from-final-apk')
        q.back();assert not any('Opening your project' in t for t in q.labels())
        q.click('New video project');q.click('Cancel');assert projects()==before
        event('final-studio-unlocked-and-cancel-has-no-new-draft')
finally:
    q.adb('shell','wm','size','411x920');q.adb('shell','settings','put','system','font_scale','1.0');q.restore()
    q.save_events('acceptance_photo_qa')
