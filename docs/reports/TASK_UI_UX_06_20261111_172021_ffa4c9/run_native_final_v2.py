"""New evidence namespace for the last low-height layout fix; old files stay."""
import qa06 as q
import pathlib,json,hashlib,runpy,sys
parent=pathlib.Path(__file__).parent
destination=parent/'native_final_v2';destination.mkdir(exist_ok=False)
q.ROOT=destination;q._helpers.ROOT=destination
click=q.click
def fixture_click(label,scrolled=False):
    return click(label,scrolled or label.lower().endswith(('.png','.jpg','.jpeg','.mp4')))
q.click=fixture_click
identity={kind:{'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size} for kind in ['debug','profile'] for path in [pathlib.Path('build/app/outputs/flutter-apk/app-'+kind+'.apk')]}
with (destination/'acceptance_apk_identity.json').open('x') as f:json.dump(identity,f,indent=2)
for script in ['acceptance_photo_qa.py','acceptance_video_qa.py','acceptance_screens_qa.py','acceptance_crop_transform.py','acceptance_dark_photo_saf.py','acceptance_photo_rtl.py','validate_acceptance_outputs.py']:
    q.EVENTS=[];q._helpers.EVENTS=q.EVENTS
    print('START '+script,flush=True)
    sys.argv=[str(parent/script)]
    runpy.run_path(str(parent/script),run_name='__main__')
    print('PASS '+script,flush=True)
with (destination/'runner_complete.json').open('x') as f:json.dump({'result':'PASS','sourcePatch':'Short landscape canvas/tools remain available; IME unchanged.','scripts':7},f)
