from qa06_interactions import *
import pathlib,ast
source=(q.PREVIOUS/'localized_visual_qa.py').read_text(encoding='utf8')
fn=next(n for n in ast.parse(source).body if isinstance(n,ast.FunctionDef) and n.name=='language')
exec(compile(ast.Module(body=[fn],type_ignores=[]),'<language-picker-helper>','exec'))
ar=json.loads(pathlib.Path('lib/l10n/app_ar.arb').read_text(encoding='utf8'))
try:
    # Continue the already-open Arabic picker after its failed offscreen-file
    # locator; its original display was restored. No new picker/draft needed.
    q.click('Edited_1794327406739.png')
    q.adb('shell','wm','size','320x760');q.adb('shell','settings','put','system','font_scale','2.0');time.sleep(1.2)
    q.shot('acceptance_photo_320_arabic_text200')
    q.click(ar['editorAllTools']);q.shot('acceptance_photo_rtl_tool_sheet');q.back()
    q.rotate(1);q.labels();q.shot('acceptance_photo_rtl_landscape');q.rotate(0);q.back()
    q.click(ar['settings']);q.click(ar['settings']);q.click(ar['appLanguage'],True);language('English')
    event('rtl-photo-tool-sheet-rotation-text200')
finally:
    q.adb('shell','wm','size','411x920');q.adb('shell','settings','put','system','font_scale','1.0');q.restore()
    q.save_events('acceptance_photo_rtl_finish')
