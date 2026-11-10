import qa03 as q,time
try:
 q.click('Settings');q.click('Light',True);q.click('View introduction',True)
 q.rotate(1);time.sleep(3);q.shot('light_onboarding_landscape_settled')
 q.EVENTS.append({'screen':'Light onboarding final','labels':q.labels(),'size':q.pixels()[1]})
 q.rotate(0);q.click('Skip');q.click('Settings');q.click('Dark',True)
 q.click('Video');q.click('Choose folder')
 q.click('sdk_gphone64_x86_64');q.click('Download');q.click('UI02C_1794308051935')
 q.click('USE THIS FOLDER');q.click('ALLOW');time.sleep(2)
 q.click('Edit');q.click('Video project')
 texts=q.labels();assert any('3H_2e625c63' in t for t in texts)
 q.EVENTS.append({'screen':'Retained QA draft after install-replace','labels':texts})
 q.shot('retained_qa_draft_after_replace')
 q.back();q.click('Video')
finally:
 q.restore();q.save_events('final_restore_run13')
