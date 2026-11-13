"""Main-app profile scenarios: same ADB actions for before/after, no capture/export."""
import qa05b as q,sys,json,urllib.request,urllib.parse,time,re,statistics,math,hashlib
phase=sys.argv[1]
connection=json.loads((q.ROOT/('vm_'+phase+'_connection.json')).read_text())
def rpc(method,**params):
 query=urllib.parse.urlencode({k:str(v) for k,v in params.items()})
 with urllib.request.urlopen(connection['url']+method+('?' + query if query else ''),timeout=30) as response:body=json.load(response)
 if 'error' in body:raise RuntimeError(body['error'])
 return body.get('result',body)
def center(label):
 for n in sorted(q.nodes(),key=lambda n:n.get('clickable')!='true'):
  if (n.get('content-desc') or n.get('text','')).split('\n')[0]==label:
   b=list(map(int,re.findall(r'\d+',n.get('bounds'))))
   if b[2]>b[0] and b[3]>b[1]:return ((b[0]+b[2])//2,(b[1]+b[3])//2)
 raise AssertionError(label)
def tap(point,delay=.32):
 q.adb('shell','input','tap',*map(str,point));time.sleep(delay)
def stats(events,name):
 values=[];stack={}
 for e in events:
  if e.get('name')!=name:continue
  key=(e.get('pid'),e.get('id')) if e.get('ph') in ['b','e'] else (e.get('pid'),e.get('tid'))
  if e.get('ph')=='X':values.append(e['dur']/1000)
  elif e.get('ph') in ['B','b']:stack.setdefault(key,[]).append(e['ts'])
  elif e.get('ph') in ['E','e'] and stack.get(key):values.append((e['ts']-stack[key].pop())/1000)
 values.sort()
 if not values:return {'frames':0}
 pct=lambda p:values[min(len(values)-1,math.ceil(len(values)*p)-1)]
 return {'frames':len(values),'meanMs':statistics.mean(values),'p50Ms':pct(.5),'p90Ms':pct(.9),'p99Ms':pct(.99),'maxMs':max(values),'over16_67ms':sum(v>1000/60 for v in values)}
results=[]
def measure(name,action):
 time.sleep(.6);rpc('clearVMTimeline');start=time.monotonic()
 action();time.sleep(.6)
 timeline=rpc('getVMTimeline')
 with (q.ROOT/(phase+'_'+name+'_timeline.json')).open('x',encoding='utf8') as f:json.dump(timeline,f,separators=(',',':'))
 events=timeline['traceEvents'];result={'scenario':name,'phase':phase,'wallSeconds':time.monotonic()-start,'build':stats(events,'Frame'),'raster':stats(events,'GPURasterizer::Draw')}
 results.append(result);print(json.dumps(result),flush=True)
rpc('setVMTimelineFlags',recordedStreams='[Dart,Embedder,GC]')
try:
 for _ in range(6):
  if 'Create' in q.labels():break
  q.back()
 nav={label:center(label) for label in ['Video','Photo','Edit','Settings','Create']}
 for label in ['Photo','Edit','Settings','Video']:tap(nav[label])
 q.shot(phase+'_navigation_dark')
 with (q.ROOT/(phase+'_mem_before.txt')).open('xb') as f:f.write(q.adb('shell','dumpsys','meminfo','com.xrecorder.xrecorder'))
 def tabs():
  for _ in range(3):
   for label in ['Photo','Edit','Settings','Video']:tap(nav[label],.3)
 measure('tabs',tabs)
 def sheets():
  for _ in range(5):tap(nav['Create'],.35);q.back()
 measure('create_sheets',sheets)
 tap(nav['Settings'])
 def scrolls():
  for _ in range(3):
   q.adb('shell','input','swipe','205','670','205','220','280');time.sleep(.2)
   q.adb('shell','input','swipe','205','220','205','670','280');time.sleep(.2)
 measure('settings_scroll',scrolls)
 q.adb('shell','input','swipe','205','700','205','200','300')
 measure('reselect',lambda:tap(nav['Settings'],.6))
 q.EVENTS.append({'reselectLabels':q.labels()})
finally:
 rpc('setVMTimelineFlags',recordedStreams='[]');q.restore()
 with (q.ROOT/(phase+'_profile_summary.json')).open('x',encoding='utf8') as f:json.dump(results,f,indent=2)
 q.save_events(phase+'_profile_actions')
