"""Before/after use the identical UI05B scripts and the same retained QA media."""
import qa06 as q
import ast,pathlib,runpy,sys
phase=sys.argv[1]
# The supplemental video script reads this function without executing a workload.
tree=ast.parse((q.PREVIOUS/'profile_scenarios.py').read_text(encoding='utf8'))
fn=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='stats')
path=q.ROOT/'profile_scenarios.py'
if not path.exists():
    with path.open('x',encoding='utf8') as f:f.write(ast.unparse(fn)+'\n')
for script in ['connect_profile.py','profile_core.py']:
    sys.argv=[str(q.PREVIOUS/script),phase]
    runpy.run_path(str(q.PREVIOUS/script),run_name='__main__')
