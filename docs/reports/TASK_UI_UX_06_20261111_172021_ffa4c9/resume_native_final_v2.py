from qa06_interactions import *
import pathlib,ast,runpy,sys
parent=pathlib.Path(__file__).parent;destination=parent/'native_final_v2'
q.ROOT=destination;q._helpers.ROOT=destination
click=q.click;q.click=lambda label,scrolled=False:click(label,scrolled or label.lower().endswith(('.png','.jpg','.jpeg','.mp4')))
source=(q.PREVIOUS/'localized_visual_qa.py').read_text(encoding='utf8')
fn=next(n for n in ast.parse(source).body if isinstance(n,ast.FunctionDef) and n.name=='language')
exec(compile(ast.Module(body=[fn],type_ignores=[]),'<language-picker-helper>','exec'))
ar=json.loads(pathlib.Path('lib/l10n/app_ar.arb').read_text(encoding='utf8'))
q.click(ar['settings']);q.click(ar['appLanguage']);language('English')
q.click('Settings');q.click('Settings');q.click('Light',True)
original={k:q.adb('shell','settings','get','global',k).decode().strip() for k in ['transition_animation_scale','animator_duration_scale']}
try:
    for k in original:q.adb('shell','settings','put','global',k,'0')
    q.click('Create');q.shot('acceptance_create_reduced_motion');q.back()
finally:
    for k,v in original.items():q.adb('shell','settings','delete','global',k) if v=='null' else q.adb('shell','settings','put','global',k,v)
q.shot('acceptance_settings_restored');event('screens-resume-english-light-reduced-motion')
q.save_events('acceptance_screens_resume')
for script in ['acceptance_crop_transform.py','acceptance_dark_photo_saf.py','acceptance_photo_rtl.py','validate_acceptance_outputs.py']:
    q.EVENTS=[];q._helpers.EVENTS=q.EVENTS
    print('START '+script,flush=True);sys.argv=[str(parent/script)]
    runpy.run_path(str(parent/script),run_name='__main__');print('PASS '+script,flush=True)
with (destination/'runner_complete.json').open('x') as f:json.dump({'result':'PASS_WITH_DOCUMENTED_LOCATOR_RESUME','originalCoreScriptsPassed':['photo','video'],'resumedScripts':4,'screensContinuation':'acceptance_screens_resume.json'},f,indent=2)
