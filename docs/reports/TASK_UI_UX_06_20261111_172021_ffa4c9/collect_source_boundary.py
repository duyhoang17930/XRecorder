"""Compare current source bytes with the dirty UI06 preflight, never Git HEAD."""
import pathlib,json,hashlib,subprocess,sys
root=pathlib.Path.cwd();out=pathlib.Path(__file__).parent
baseline=json.loads((out/'baseline.json').read_text(encoding='utf8'))
changed=[];missing=[]
for name,old in baseline['hashes'].items():
    path=root/name
    if not path.is_file():missing.append(name);continue
    now=hashlib.sha256(path.read_bytes()).hexdigest()
    if now!=old:changed.append({'path':name,'before':old,'after':now})
protected=lambda p:p.startswith(('android/','lib/features/recording/')) or p in {
    'lib/features/settings/settings_controller.dart',
    'lib/features/settings/recording_settings_form.dart',
    'lib/features/settings/audio_video_settings_screen.dart',
    'lib/core/widgets/studio_create_sheet.dart',
    'lib/core/domain/models.dart',
    'lib/features/editor/project_controller.dart',
    'lib/features/editor/project_repository.dart',
}
violations=[row for row in changed if protected(row['path'])]
assert not missing and not violations,(missing,violations)
untracked=subprocess.check_output(['git','ls-files','--others','--exclude-standard','lib','android','test','tool'],text=True).splitlines()
oldUntracked=[line[3:].strip('"') for line in baseline['status'].splitlines() if line.startswith('?? ')]
added=[p for p in untracked if not any(p==old or p.startswith(old.rstrip('/')+'/') for old in oldUntracked)]
record={'baselineHead':baseline['head'],'currentHead':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'baselineTrackedFileCount':len(baseline['hashes']),'changedSinceDirtyBaseline':changed,'missingBaselineFiles':missing,'protectedViolations':violations,'newSourceOrTests':added,'baselineUntrackedPresence':{p:(root/p).exists() for p in oldUntracked},'scope':'Protected Android/P1, models/controller/repository and EditorPreview.kt byte-identical to UI06 preflight; existing UI05/05B differences against HEAD are preserved.'}
photoPath='lib/features/media/photo_tools_screen.dart'
oldPhoto=subprocess.check_output(['git','show','HEAD:'+photoPath]).decode('utf8')
newPhoto=(root/photoPath).read_text(encoding='utf8')
def renderFunction(text):return text.split('Future<ui.Image> renderPhotoCopy(',1)[1].split('/// Edits a copy',1)[0]
record['photoRenderAlgorithmTextUnchanged']=renderFunction(oldPhoto)==renderFunction(newPhoto)
assert record['photoRenderAlgorithmTextUnchanged']
with (out/(sys.argv[1] if len(sys.argv)>1 else 'source_boundary_final.json')).open('x',encoding='utf8') as f:json.dump(record,f,indent=2)
print('Tracked source baseline',len(baseline['hashes']),'changed',len(changed),'new source/test',len(added),'protected violations',len(violations))
