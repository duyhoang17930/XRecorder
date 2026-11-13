"""Supplement the completed core baseline without overwriting its evidence."""
import qa06 as q
import ast,json,sys,pathlib
phase=sys.argv[1]
if not (q.ROOT/('vm_'+phase+'_connection.json')).exists():
    original=json.loads((q.ROOT/'vm_baseline_connection.json').read_text())
    with (q.ROOT/('vm_'+phase+'_connection.json')).open('x') as f:json.dump(original,f)
if not (q.ROOT/'profile_scenarios.py').exists():
    tree=ast.parse((q.PREVIOUS/'profile_scenarios.py').read_text(encoding='utf8'))
    fn=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='stats')
    with (q.ROOT/'profile_scenarios.py').open('x',encoding='utf8') as f:f.write(ast.unparse(fn)+'\n')
for name in ['profile_editor_only.py','profile_video.py']:
    # The user's UI04 output was renamed after UI05B; use the OTHER retained
    # UI04 QA output for BOTH phases. This choice is recorded, not fabricated.
    source=(q.PREVIOUS/name).read_text(encoding='utf8').replace(
        'Edited_1794327210071.png','Edited_1794327406739.png')
    sys.argv=[name,phase]
    exec(compile(source,str(q.PREVIOUS/name),'exec'),{'__name__':'__main__'})
