from qa06_interactions import *
try:
    q.click('Settings');q.click('Settings');q.click('Dark',True)
    q.click('Edit');q.click('Edit');q.click('Edit photo');q.click('Edited_1794327406739.png')
    q.shot('acceptance_photo_dark');q.rotate(1);q.labels();q.shot('acceptance_photo_dark_landscape')
    q.click('Color');q.shot('acceptance_photo_dark_color');q.back();q.rotate(0);q.back()
    q.click('Settings');q.click('Settings');q.click('Light',True)
    q.click('Edit');q.click('Edit');q.click('UI04_Editor_QA',True);time.sleep(2)
    q.shot('acceptance_existing_saf_project');q.rotate(1);q.labels();q.shot('acceptance_existing_saf_landscape');q.rotate(0)
    event('existing-saf-draft-preview-rotation-read-only')
    q.back();q.click('Settings');q.click('Settings')
finally:q.restore();q.save_events('acceptance_dark_photo_saf')
