import qa06 as q
import pathlib,runpy,json,sys
parent=pathlib.Path(__file__).parent;destination=parent/'native_final_v2'
assert (destination/'runner_complete.json').exists()
q.ROOT=destination;q._helpers.ROOT=destination
click=q.click
q.click=lambda label,scrolled=False:click(label,scrolled or label.lower().endswith(('.png','.jpg','.jpeg','.mp4')))
for script in ['acceptance_tool_menus.py','acceptance_eraser_roundtrip.py']:
    q.EVENTS=[];q._helpers.EVENTS=q.EVENTS
    sys.argv=[str(parent/script)];runpy.run_path(str(parent/script),run_name='__main__')
# Exact before/after fixture: Light411/font100/default Pen, no edits saved.
q.click('Edit');q.click('Edit photo');q.click('Edited_1794327406739.png')
q.labels();q.shot('acceptance_photo_default_light');q.back();q.click('Settings');q.click('Settings')
with (destination/'runner_extra_complete.json').open('x') as f:json.dump({'result':'PASS','scripts':2,'sameFixtureBeforeAfterScreenshot':True},f)
