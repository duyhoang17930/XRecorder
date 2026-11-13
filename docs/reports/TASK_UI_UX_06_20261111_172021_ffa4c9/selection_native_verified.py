from qa06_interactions import *
try:
    name='files/projects/project_1794396351822793.json'
    original=read_project(name)
    assert original['clips'][1]['mediaId'].endswith('/1451')
    q.click('Clip options');q.click('Move earlier');time.sleep(.6)
    moved=read_project(name)
    assert moved['clips'][0]['mediaId']==original['clips'][1]['mediaId']
    assert 'Selected clip: Edited_1794327406739.png' in q.labels()
    q.shot('final_video_reordered_selected');event('selected-photo-retained-after-move-earlier')
    q.click('Undo edit');time.sleep(.6)
    assert read_project(name)['clips']==original['clips']
    assert 'Selected clip: Edited_1794327406739.png' in q.labels()
    q.click('Redo edit');time.sleep(.6)
    assert read_project(name)['clips']==moved['clips']
    assert 'Selected clip: Edited_1794327406739.png' in q.labels()
    event('native-reorder-undo-redo-preserves-selection')
    q.back();q.back()
finally:q.restore();q.save_events('selection_native_verified')
