import qa05b as q
import json,re,time,sys,urllib.parse,urllib.request
phase=sys.argv[1]
began=time.monotonic()
launch=q.adb('shell','am','start','-W','-n','com.xrecorder.xrecorder/.MainActivity','--ez','enable-dart-profiling','true')
with (q.ROOT/(phase+'_launch.txt')).open('xb') as f:f.write(launch)
pid=q.adb('shell','pidof','com.xrecorder.xrecorder').decode().strip()
url=None
for _ in range(20):
    log=q.adb('logcat','-d','--pid='+pid).decode(errors='replace')
    matches=re.findall(r'http://127\.0\.0\.1:\d+/[^\s]+/',log)
    if matches:url=matches[-1];break
    time.sleep(.3)
assert url
device=urllib.parse.urlsplit(url);port=q.adb('forward','tcp:0','tcp:'+str(device.port)).decode().strip()
base='http://127.0.0.1:'+port+device.path
with (q.ROOT/('vm_'+phase+'_connection.json')).open('x') as f:json.dump({'url':base,'pid':pid},f)
with urllib.request.urlopen(base+'getVMTimeline') as response:startup=json.load(response)
with (q.ROOT/(phase+'_startup_timeline.json')).open('x') as f:json.dump(startup,f,separators=(',',':'))
labels=q.labels();assert 'Create' in labels,labels
with (q.ROOT/(phase+'_ready_observation.json')).open('x') as f:json.dump({'secondsUntilFirstSuccessfulHierarchy':time.monotonic()-began,'includesADBAndHierarchyOverhead':True,'labels':labels},f,indent=2)
print('Main profile app ready, VM timeline available.',flush=True)
