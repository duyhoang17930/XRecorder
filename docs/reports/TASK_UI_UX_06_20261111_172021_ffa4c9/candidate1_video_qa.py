from qa06_interactions import *
before=projects()
try:
    with Video('UI06_candidate1_video_selection'):
        q.back();q.click('Edit');q.click('New video project')
        q.click('Edited_ca13829a-b90f-4ac0-96f1-8723256517db.mp4')
        q.click('Photos');q.click('Edited_1794327406739.png')
        q.click('Add clip · 2 clips');time.sleep(1)
        added=projects()-before;assert len(added)==1
        name=added.pop()
        q.click('Rename project');q.click('Clear text');field('UI06_CandidateSelect')
        q.click('Save name');time.sleep(.5)
        q.shot('candidate1_video_two_clips')
        start=read_project(name)
        tool('Edit');panel('Move later');time.sleep(.5)
        q.shot('candidate1_after_move')
        moved=read_project(name);labels=q.labels()
        q.EVENTS.append({'case':'selection-after-reorder','projectFile':name,'before':start,'after':moved,'labels':labels})
        event('candidate1-selection-after-move')
        q.back();q.back()
finally:
    q.restore();q.save_events('candidate1_video_qa')
