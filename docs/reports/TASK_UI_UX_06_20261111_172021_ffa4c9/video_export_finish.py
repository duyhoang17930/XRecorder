from qa06_interactions import *
name='files/projects/project_1794397880008428.json'
try:
    with Video('UI06_video_split_effects_export'):
        event('resume-qa-draft-at-valid-one-second-playhead')
        q.click('Split');time.sleep(.5)
        assert len(read_project(name)['clips'])==3
        q.click('Undo edit');time.sleep(.4);assert len(read_project(name)['clips'])==2
        q.click('Redo edit');time.sleep(.4);assert len(read_project(name)['clips'])==3
        tool('Effects');q.shot('final_video_effects_panel');event('effects-before-apply')
        q.click('Color filter');q.click('Grayscale');q.click('Apply to project');time.sleep(.8)
        assert read_project(name)['effects']['filter']=='grayscale'
        q.rotate(1);q.shot('final_video_landscape');q.rotate(0)
        q.shot('final_video_split_applied');event('split-effects-history-rotation')
        q.click('Export');time.sleep(2);q.shot('final_export_queue')
        event('export-started')
    with (q.ROOT/'final_video_project.json').open('x',encoding='utf8') as f:json.dump({'file':name,'project':read_project(name)},f,indent=2)
finally:q.restore();q.save_events('video_export_finish')
