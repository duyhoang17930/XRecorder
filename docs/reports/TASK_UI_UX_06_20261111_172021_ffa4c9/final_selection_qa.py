from qa06_interactions import *
try:
    launch=q.adb('shell','am','start','-W','-n','com.xrecorder.xrecorder/.MainActivity')
    with (q.ROOT/'final_debug_launch.txt').open('xb') as f:f.write(launch)
    q.click('Edit');q.click('UI06_CandidateSelect',True)
    name='files/projects/project_1794396351822793.json'
    original=read_project(name);assert original['clips'][0]['mediaId'].endswith('/1451'),original
    tool('Edit');q.click('Clip options');q.click('Move later');time.sleep(.8)
    moved=read_project(name);assert moved['clips'][1]['mediaId']==original['clips'][0]['mediaId']
    labels=q.labels();assert any('2.0' in s and 'Edited_1794327406739.png' in s for s in labels),labels
    q.shot('final_video_selected_photo_after_reorder');event('selection-retained-after-move')
    q.click('Undo');time.sleep(.6)
    assert read_project(name)['clips']==original['clips']
    q.click('Redo');time.sleep(.6)
    assert read_project(name)['clips']==moved['clips']
    event('selection-undo-redo')
    q.back();q.back()
finally:
    q.restore();q.save_events('final_selection_qa')
