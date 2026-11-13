from qa06_interactions import *
import pathlib,ast
source=(q.PREVIOUS/'localized_visual_qa.py').read_text(encoding='utf8')
fn=next(n for n in ast.parse(source).body if isinstance(n,ast.FunctionDef) and n.name=='language')
exec(compile(ast.Module(body=[fn],type_ignores=[]),'<language-picker-helper>','exec'))
ar=json.loads(pathlib.Path('lib/l10n/app_ar.arb').read_text(encoding='utf8'))
try:
    q.click('Settings');q.click('Settings');q.click('App language',True);language('العربية')
    q.adb('shell','wm','size','320x760');q.adb('shell','settings','put','system','font_scale','2.0');time.sleep(1.2)
    q.click(ar['edit']);q.click(ar['edit']);q.click(ar['editPhoto']);q.click('Edited_1794327406739.png')
    q.shot('acceptance_photo_320_arabic_text200')
    q.click(ar['editorAllTools']);q.shot('acceptance_photo_rtl_tool_sheet');q.back()
    q.rotate(1);q.labels();q.shot('acceptance_photo_rtl_landscape')
    # The short landscape must retain a real drawing surface, not just controls.
    surfaces=[bounds(n) for n in q.nodes() if n.get('class')=='android.view.View' and n.get('scrollable')=='true']
    b=max((b for b in surfaces if b[1]>70 and b[3]<300),key=lambda b:(b[2]-b[0])*(b[3]-b[1]))
    q.adb('shell','input','swipe',str(round(b[0]+(b[2]-b[0])*.25)),str(round(b[1]+(b[3]-b[1])*.4)),str(round(b[0]+(b[2]-b[0])*.6)),str(round(b[1]+(b[3]-b[1])*.5)),'450')
    q.rotate(0);q.shot('acceptance_photo_rtl_marks_retained')
    q.click(ar['undoPhotoEdit']);q.back()
    q.click(ar['settings']);q.click(ar['settings']);q.click(ar['appLanguage'],True);language('English')
    event('rtl-photo-tools-and-rotation-text200')
finally:
    q.adb('shell','wm','size','411x920');q.adb('shell','settings','put','system','font_scale','1.0');q.restore()
    q.save_events('acceptance_photo_rtl')
