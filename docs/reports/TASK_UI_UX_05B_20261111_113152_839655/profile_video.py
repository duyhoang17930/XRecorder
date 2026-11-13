"""Supplemental profile scenario; paused preview never starts recording/export."""
import qa05b as q,sys,json,re,time,urllib.request,urllib.parse,ast,statistics,math
phase=sys.argv[1];url=json.loads((q.ROOT/('vm_'+phase+'_connection.json')).read_text())['url']
def rpc(method,**params):
 with urllib.request.urlopen(url+method+('?' + urllib.parse.urlencode(params) if params else ''),timeout=30) as response:body=json.load(response)
 if 'error' in body:raise RuntimeError(body['error'])
 return body['result']
tree=ast.parse((q.ROOT/'profile_scenarios.py').read_text());fn=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='stats')
ns={'math':math,'statistics':statistics};exec(compile(ast.Module(body=[fn],type_ignores=[]),'<shared stats>','exec'),ns)
rows=[]
def measure(name,action):
 rpc('clearVMTimeline');action();time.sleep(.7);data=rpc('getVMTimeline')
 with (q.ROOT/(phase+'_'+name+'_timeline.json')).open('x',encoding='utf8') as f:json.dump(data,f,separators=(',',':'))
 row={'scenario':name,'build':ns['stats'](data['traceEvents'],'Frame'),'raster':ns['stats'](data['traceEvents'],'GPURasterizer::Draw')};rows.append(row);print(json.dumps(row),flush=True)
try:
 q.click('Edit');q.click('UI04_Editor_QA',True);time.sleep(2)
 seek=next(n for n in q.nodes() if n.get('class')=='android.widget.SeekBar');b=list(map(int,re.findall(r'\d+',seek.get('bounds'))));y=(b[1]+b[3])//2
 def scrub():
  start=(b[0]+b[2])//2
  for x in [205,355,70,250,150,205]:
   q.adb('shell','input','swipe',str(start),str(y),str(x),str(y),'350');start=x;time.sleep(.2)
 rpc('setVMTimelineFlags',recordedStreams='[Dart,Embedder,GC]')
 measure('video_scrub',scrub)
 measure('video_rotation',lambda:(q.rotate(1),time.sleep(.7),q.rotate(0),time.sleep(.7)))
 q.shot(phase+'_paused_video_after_rotation');q.EVENTS.append({'position':q.labels()})
 q.back();q.click('Settings');q.click('Settings')
finally:
 rpc('setVMTimelineFlags',recordedStreams='[]');q.restore();q.save_events(phase+'_video_profile_actions')
 with (q.ROOT/(phase+'_video_profile_summary.json')).open('x',encoding='utf8') as f:json.dump(rows,f,indent=2)
