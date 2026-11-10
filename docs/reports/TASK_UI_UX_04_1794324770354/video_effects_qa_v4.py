import qa04 as q,time,json,re,tarfile

def wait(label):
 for _ in range(8):
  texts=q.labels()
  if label in texts or any(t.split('\n')[0]==label for t in texts):return texts
  time.sleep(.5)
 raise AssertionError('Expected '+label)
def bounds(n):return list(map(int,re.findall(r'\d+',n.get('bounds'))))
def section(label):
 try:q.click(label)
 except RuntimeError:
  ns=q.nodes();n=next(n for n in ns if n.get('clickable')=='true' and (n.get('content-desc') or n.get('text','')) in ['Video','Audio','Subtitles','Overlays','Export quality'])
  b=bounds(n);y=(b[1]+b[3])//2
  q.adb('shell','input','swipe','360',str(y),'60',str(y),'400');q.click(label)
def field(text):
 n=next(n for n in q.nodes() if n.get('class')=='android.widget.EditText')
 b=bounds(n);q.tap((b[0]+b[2])//2,(b[1]+b[3])//2)
 q.adb('shell','input','keyevent','123',*(['67']*(len(n.get('text',''))+8)));q.adb('shell','input','text',text)
def hide_keyboard():
 if 'mInputShown=true' in q.adb('shell','dumpsys','input_method').decode():q.back()
def document(path):return q.adb('exec-out','run-as','com.xrecorder.xrecorder','cat',path)
try:
 q.click('Edit');q.click('Video project UI04_Editor_QAcopy',True);wait('Rename project');time.sleep(2)
 beforePaths={m.name for m in tarfile.open(q.ROOT/'private_preferences_projects_before.tar').getmembers() if m.isfile() and m.name.startswith('files/projects/')}
 paths=q.adb('shell','run-as','com.xrecorder.xrecorder','find','files/projects','-type','f').decode().splitlines()
 path=next(p for p in paths if p not in beforePaths and re.fullmatch(r'files/projects/project_\d+\.json',p))
 q.click('Rename project');field('UI04_Editor_QA');q.click('Save name');wait('UI04_Editor_QA')
 time.sleep(1);before=document(path)
 with (q.ROOT/'clone_before_effects.json').open('xb') as f:f.write(before)
 q.click('Effects');wait('Video & audio effects');q.shot('effects_video_dark')
 q.click('Color filter');q.click('Invert colors');q.click('Cancel');wait('UI04_Editor_QA')
 afterCancel=document(path);assert before==afterCancel
 q.EVENTS.append({'cancelDraftByteExact':True,'projectPath':path})
 q.click('Effects');wait('Video & audio effects');section('Audio');q.shot('effects_audio_dark')
 q.click('Audio tracks (0)');wait('Audio tracks');q.shot('audio_tracks_dialog');q.click('Cancel')
 section('Subtitles');q.shot('effects_subtitles_dark')
 section('Overlays');field('UI04');hide_keyboard();q.shot('effects_overlays_dark')
 q.roundtrip('Effects_overlays','UI04',True)
 section('Export quality');q.shot('effects_export_quality_dark')
 q.click('Export format');q.click('gif');q.shot('effects_gif_controls');q.click('Export format');q.click('mp4')
 section('Video');q.click('Color filter');q.click('Invert colors');q.click('Apply to project');wait('UI04_Editor_QA');time.sleep(1)
 applied=json.loads(document(path));assert applied['effects']['filter']=='invert' and applied['effects']['text']=='UI04'
 q.EVENTS.append({'applied':applied})
 q.click('Undo edit');time.sleep(1);undone=json.loads(document(path));assert undone['effects'].get('filter','none')=='none'
 q.click('Redo edit');time.sleep(1);redone=json.loads(document(path));assert redone['effects']['filter']=='invert'
 q.roundtrip('Video_editor_after_apply','UI04_Editor_QA',True)
 q.shot('video_editor_applied');q.click('Export');wait('Export queue')
 for _ in range(18):
  jobData=q.adb('exec-out','run-as','com.xrecorder.xrecorder','cat','files/export_jobs.json')
  jobs=json.loads(jobData)
  if isinstance(jobs,dict):jobs=jobs.get('jobs',[])
  candidates=[j for j in jobs if j.get('project',{}).get('id')==applied['id']]
  if candidates and candidates[-1].get('state') in ['completed','failed','cancelled']:break
  time.sleep(1)
 q.shot('export_queue_result')
 q.EVENTS.append({'jobs':candidates})
 assert candidates[-1]['state']=='completed'
 with (q.ROOT/'video_export_job.json').open('x',encoding='utf8') as f:json.dump(candidates[-1],f,ensure_ascii=False,indent=2)
finally:
 q.restore();q.save_events('video_effects_qa_v4')
