from qa06_interactions import *
try:
    assert 'Media details' in q.labels()
    before=projects()
    with Video('UI06_guard_return_verified'):
        q.back();labels=q.labels()
        assert not any('Opening your project' in t for t in labels),labels
        q.shot('guard_final_studio_unlocked')
        q.click('New video project');assert 'Choose media' in q.labels()
        q.click('Cancel');assert projects()==before
        event('save-copy-return-studio-unlocked-picker-cancel-no-draft')
finally:q.restore();q.save_events('guard_native_return')
