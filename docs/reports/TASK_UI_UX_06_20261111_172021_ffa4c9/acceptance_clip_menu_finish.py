from qa06_interactions import *
import pathlib
en=json.loads(pathlib.Path('lib/l10n/app_en.arb').read_text(encoding='utf8'))
name='files/projects/project_1794396351822793.json'
try:
    original=read_project(name);assert len(original['clips'])==2
    with Video('UI06_acceptance_remove_relink'):
        q.click(en['removeClipFromProject']);time.sleep(.4)
        assert len(read_project(name)['clips'])==1
        q.click(en['undoEdit']);time.sleep(.4)
        assert read_project(name)['clips']==original['clips']
        q.click(en['clipOptions']);q.click(en['replaceSource']);q.click(en['cancel'])
        assert read_project(name)['clips']==original['clips']
        q.shot('acceptance_clip_options_history_preserved')
        event('remove-undo-replace-source-cancel-native')
        q.back();q.back();q.click('Settings');q.click('Settings')
finally:q.restore();q.save_events('acceptance_clip_menu_finish')
