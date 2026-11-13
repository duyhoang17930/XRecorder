from qa06_interactions import *
try:
    q.click('Edit');q.click('Edit');q.click('Edit photo');q.click('Edited_1794327406739.png')
    with Video('UI06_acceptance_shapes_eraser_guards'):
        for shape,start,end in [('Rectangle',(90,300),(275,350)),('Circle',(120,315),(260,365)),('Arrow',(100,365),(270,300))]:
            tool('Shapes');q.click(shape)
            q.adb('shell','input','swipe',str(start[0]),str(start[1]),str(end[0]),str(end[1]),'450')
        q.shot('acceptance_photo_three_shapes')
        q.click('Undo photo edit');q.click('Redo photo edit')
        tool('Drawing');q.click('Eraser')
        q.adb('shell','input','swipe','90','300','105','303','400')
        q.shot('acceptance_photo_eraser')
        q.back();assert 'Discard photo edits?' in q.labels()
        q.click('Keep editing');assert 'Photo editor' in q.labels()
        q.back();q.click('Discard edits');assert 'Create' in q.labels()
        event('photo-shapes-eraser-history-keep-discard')
    q.click('Edit');q.click('UI06_CandidateSelect',True);name='files/projects/project_1794396351822793.json'
    original=read_project(name);assert len(original['clips'])==2
    with Video('UI06_acceptance_clip_options'):
        tool('Edit');q.click('Clip options');q.click('Duplicate clip');time.sleep(.4)
        assert len(read_project(name)['clips'])==3
        q.click('Undo edit');time.sleep(.4);assert len(read_project(name)['clips'])==2
        q.click('Clip options');q.click('Move later');time.sleep(.4)
        assert read_project(name)['clips'][1]['mediaId']==original['clips'][0]['mediaId']
        assert 'Selected clip: Edited_1794327406739.png' in q.labels()
        q.click('Undo edit');time.sleep(.4)
        q.click('Clip options');q.click('Remove clip from project');time.sleep(.4)
        assert len(read_project(name)['clips'])==1
        q.click('Undo edit');time.sleep(.4);assert len(read_project(name)['clips'])==2
        q.click('Clip options');q.click('Replace source');q.click('Cancel')
        assert read_project(name)['clips']==original['clips']
        q.shot('acceptance_clip_options_history_preserved');event('clip-duplicate-move-remove-relink-cancel-history')
        q.back();q.back()
    q.click('Settings');q.click('Settings')
finally:q.restore();q.save_events('acceptance_tool_menus')
