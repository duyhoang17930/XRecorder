import qa04 as q,time,json,re,subprocess
def section(label):
 names=['Video','Audio','Subtitles','Overlays','Export quality']
 for _ in range(4):
  try:q.click(label);return
  except RuntimeError:
   visible=[n for n in q.nodes() if n.get('clickable')=='true' and (n.get('content-desc') or n.get('text','')) in names]
   assert visible
   b=list(map(int,re.findall(r'\d+',visible[0].get('bounds'))));y=(b[1]+b[3])//2
   goRight=names.index(label)<min(names.index(n.get('content-desc') or n.get('text')) for n in visible)
   q.adb('shell','input','swipe','60' if goRight else '360',str(y),'360' if goRight else '60',str(y),'400')
 raise AssertionError(label)
path='files/projects/project_1794327848468607.json'
def doc():return json.loads(q.adb('exec-out','run-as','com.xrecorder.xrecorder','cat',path))
try:
 section('Video');q.click('Color filter');q.click('Invert colors');q.click('Apply to project');time.sleep(2)
 applied=doc();assert applied['effects']['filter']=='invert' and applied['effects']['text']=='UI04'
 q.EVENTS.append({'applied':applied})
 q.click('Undo edit');time.sleep(1);assert doc()['effects'].get('filter','none')=='none'
 q.click('Redo edit');time.sleep(1);assert doc()['effects']['filter']=='invert'
 q.roundtrip('Video_editor_after_apply','UI04_Editor_QA',True)
 q.shot('video_editor_applied');q.click('Export');time.sleep(1)
 candidates=[]
 for _ in range(20):
  try:
   data=q.adb('exec-out','run-as','com.xrecorder.xrecorder','cat','files/export_jobs.json')
   jobs=json.loads(data)
   if isinstance(jobs,dict):jobs=jobs.get('jobs',[])
   candidates=[j for j in jobs if j.get('project',{}).get('id')==applied['id']]
   if candidates and candidates[-1].get('state') in ['completed','failed','cancelled']:break
  except subprocess.CalledProcessError:pass
  time.sleep(1)
 q.shot('export_queue_result');q.EVENTS.append({'jobs':candidates})
 assert candidates and candidates[-1]['state']=='completed'
 with (q.ROOT/'video_export_job.json').open('x',encoding='utf8') as f:json.dump(candidates[-1],f,ensure_ascii=False,indent=2)
finally:
 q.restore();q.save_events('video_effects_resume_v5')
