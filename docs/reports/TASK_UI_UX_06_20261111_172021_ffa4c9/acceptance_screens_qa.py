from qa06_interactions import *
import ast,pathlib
source=(q.PREVIOUS/'localized_visual_qa.py').read_text(encoding='utf8')
fn=next(n for n in ast.parse(source).body if isinstance(n,ast.FunctionDef) and n.name=='language')
exec(compile(ast.Module(body=[fn],type_ignores=[]),'<language-picker-helper>','exec'))
animation={k:q.adb('shell','settings','get','global',k).decode().strip() for k in ['transition_animation_scale','animator_duration_scale']}
try:
    for _ in range(5):
        labels=q.labels()
        if all(t in labels for t in ['Video','Photo','Settings']):break
        q.back()
    with Video('UI06_acceptance_general_interactions'):
        for tab in ['Video','Photo','Edit','Settings']:
            q.click(tab);q.click(tab);q.shot('acceptance_root_'+tab.lower())
        node=next(n for n in q.nodes() if n.get('content-desc')=='Create' and n.get('clickable')=='true')
        b=bounds(node);x=(b[0]+b[2])//2;y=(b[1]+b[3])//2
        for count in [2,3,5]:
            for _ in range(count):q.adb('shell','input','tap',str(x),str(y));time.sleep(.04)
            labels=q.labels();titles=[s.splitlines()[0] for s in labels]
            assert 'Record screen' in titles and 'Screenshot' in titles and 'Editing Studio' in titles
            assert 'Start Recording' not in labels
            q.EVENTS.append({'case':'final-rapid-create','taps':count,'modalRemained':True})
            if count==5:q.shot('acceptance_create')
            q.back()
        q.click('Video');q.click('Video');q.click('Edited_ca13829a-b90f-4ac0-96f1-8723256517db.mp4',True)
        q.shot('acceptance_media_details')
        q.click('Rename',True);q.click('Clear text');q.shot('acceptance_clear_rename');q.click('Cancel')
        q.back();q.click('Settings');q.click('Settings');q.click('Dark',True)
        q.adb('shell','wm','size','393x850');time.sleep(1.2)
        q.click('Edit');q.click('Edit');q.shot('acceptance_studio_393_dark')
        q.click('UI06_Acceptance',True);time.sleep(2);q.shot('acceptance_video_dark')
        q.rotate(1);q.labels();q.shot('acceptance_video_dark_landscape');q.rotate(0)
        tool('Audio');q.shot('acceptance_audio_dark');q.back();q.back()
    q.adb('shell','wm','size','411x920');time.sleep(1)
    q.click('Settings');q.click('Settings');q.click('App language',True);language('العربية')
    ar=json.loads(pathlib.Path('lib/l10n/app_ar.arb').read_text(encoding='utf8'))
    q.adb('shell','wm','size','320x760');q.adb('shell','settings','put','system','font_scale','2.0');time.sleep(1.2)
    q.click(ar['edit']);q.click(ar['edit']);q.click('UI06_Acceptance',True);time.sleep(2)
    q.shot('acceptance_video_320_arabic_text200');tool(ar['effects'])
    q.shot('acceptance_effects_320_arabic_text200');q.rotate(1);q.labels();q.shot('acceptance_effects_arabic_landscape');q.rotate(0)
    q.back();q.back();q.click(ar['settings']);q.click(ar['settings']);q.click(ar['appLanguage'],True);language('English')
    q.adb('shell','wm','size','411x920');q.adb('shell','settings','put','system','font_scale','1.0');time.sleep(1.2)
    q.click('Settings');q.click('Settings');q.click('Light',True)
    for k in animation:q.adb('shell','settings','put','global',k,'0')
    q.click('Create');q.shot('acceptance_create_reduced_motion');q.back()
    q.shot('acceptance_settings_restored');event('final-layout-theme-locale-qa-completed')
finally:
    for k,v in animation.items():
        q.adb('shell','settings','delete','global',k) if v=='null' else q.adb('shell','settings','put','global',k,v)
    q.adb('shell','wm','size','411x920');q.adb('shell','settings','put','system','font_scale','1.0');q.restore()
    q.save_events('acceptance_screens_qa')
