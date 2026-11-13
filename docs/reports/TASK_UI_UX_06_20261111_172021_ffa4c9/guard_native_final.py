from qa06_interactions import *
try:
    q.adb('shell','am','start','-W','-n','com.xrecorder.xrecorder/.MainActivity')
    q.click('Edit');before=projects()
    with Video('UI06_guard_save_copy_return'):
        q.click('Edit photo');q.click('Edited_1794327406739.png')
        tool('Text');field('UI06_guard');q.back();panel('Apply')
        q.shot('guard_final_photo_text')
        q.adb('shell','input','keyevent','3');time.sleep(.4)
        q.adb('shell','am','start','-n','com.xrecorder.xrecorder/.MainActivity')
        assert 'Save copy' in q.labels()
        q.shot('guard_final_photo_resumed')
        q.click('Save copy');time.sleep(.8)
        assert 'Media details' in q.labels()
        q.back()
        labels=q.labels()
        assert not any('Opening your project' in t for t in labels),labels
        q.shot('guard_final_studio_unlocked')
        q.click('New video project');assert 'Choose media' in q.labels()
        q.click('Cancel');assert projects()==before
        event('real-save-copy-return-picker-unlocked-no-empty-draft')
finally:q.restore();q.save_events('guard_native_final')
