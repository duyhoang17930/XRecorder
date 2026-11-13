from qa06_interactions import *
import ast,pathlib
source=(q.PREVIOUS/'localized_visual_qa.py').read_text(encoding='utf8')
fn=next(n for n in ast.parse(source).body if isinstance(n,ast.FunctionDef) and n.name=='language')
exec(compile(ast.Module(body=[fn],type_ignores=[]),'<language-selection-helper>','exec'))
ar=json.loads(pathlib.Path('lib/l10n/app_ar.arb').read_text(encoding='utf8'))
original={k:q.adb('shell','settings','get','global',k).decode().strip() for k in ['transition_animation_scale','animator_duration_scale']}
try:
    q.adb('shell','wm','size','320x760');q.adb('shell','settings','put','system','font_scale','2.0')
    q.click(ar['edit']);q.click(ar['edit']);q.click('UI06_Final_Video_V2',True);time.sleep(2)
    q.shot('guard_final_video_arabic_320_settled');tool(ar['effects'])
    q.shot('guard_final_effects_arabic_320_text200');q.rotate(1);time.sleep(.5)
    q.shot('guard_final_effects_arabic_landscape_text200');q.rotate(0)
    event('arabic-video-effects-320-text200-rotation')
    q.back();q.back();q.click(ar['settings']);q.click(ar['settings']);q.click(ar['appLanguage'],True);language('English')
    q.adb('shell','wm','size','360x800');q.adb('shell','settings','put','system','font_scale','1.5');time.sleep(.5)
    q.click('Edit');q.click('Edit');q.click('Edit photo');q.click('Edited_1794327406739.png')
    tool('Text');field('UI06_IME');q.shot('guard_final_photo_keyboard_360_text150');q.back()
    q.rotate(1);q.shot('guard_final_photo_360_landscape_text150');q.rotate(0);q.back()
    q.adb('shell','wm','size','393x850');q.adb('shell','settings','put','system','font_scale','1.0')
    q.click('Video');q.click('Video');q.shot('guard_final_library_393_dark')
    q.click('Settings');q.click('Settings');q.click('Light',True)
    q.adb('shell','wm','size','411x920')
    for k in original:q.adb('shell','settings','put','global',k,'0')
    q.click('Edit');q.click('Edit');q.click('UI06_Final_Video_V2',True);tool('Edit')
    for _ in range(4):
        q.adb('shell','input','swipe','205','700','205','460','120')
        q.adb('shell','input','swipe','205','460','205','700','120')
    q.shot('guard_final_video_flings_reduced_motion');event('context-eight-flings-reduced-motion')
    q.back();q.back();q.click('Settings');q.click('Settings');event('restored-light-english')
finally:
    for k,v in original.items():
        q.adb('shell','settings','delete','global',k) if v=='null' else q.adb('shell','settings','put','global',k,v)
    q.adb('shell','wm','size','411x920');q.adb('shell','settings','put','system','font_scale','1.0');q.restore()
    q.save_events('responsive_native_finish')
