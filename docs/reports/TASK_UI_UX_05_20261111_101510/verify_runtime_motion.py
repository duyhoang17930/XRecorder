import qa05 as q
import json,re,time,urllib.request,urllib.parse

pid=q.adb('shell','pidof','com.xrecorder.xrecorder').decode().strip()
log=q.adb('logcat','-d','--pid='+pid).decode(errors='replace')
url=re.findall(r'http://127\.0\.0\.1:\d+/[^\s]+/',log)[-1]
parts=urllib.parse.urlsplit(url)
port=q.adb('forward','tcp:0','tcp:'+str(parts.port)).decode().strip()
base='http://127.0.0.1:'+port+parts.path
def rpc(method,**params):
    data=json.load(urllib.request.urlopen(base+method+'?'+urllib.parse.urlencode(params)))
    if 'error' in data:raise RuntimeError(data['error'])
    return data['result']
vm=rpc('getVM');isolate=next(x['id'] for x in vm['isolates'] if x['name']=='main')
info=rpc('getIsolate',isolateId=isolate)
library=next(x['id'] for x in info['libraries'] if x['uri']=='dart:ui')
original=q.adb('shell','settings','get','global','transition_animation_scale').decode().strip()
results=[]
try:
    for value in ['0','1']:
        q.adb('shell','settings','put','global','transition_animation_scale',value);time.sleep(.7)
        result=rpc('evaluate',isolateId=isolate,targetId=library,expression='PlatformDispatcher.instance.accessibilityFeatures.disableAnimations')
        results.append({'transition_animation_scale':value,'runtimeResult':result})
        assert result.get('valueAsString')==('true' if value=='0' else 'false'),result
finally:
    q.adb('shell','settings','delete','global','transition_animation_scale') if original=='null' else q.adb('shell','settings','put','global','transition_animation_scale',original)
    with (q.ROOT/'runtime_reduce_motion_verified.json').open('x',encoding='utf8') as f:json.dump({'results':results,'restored':original},f,indent=2)
print('Runtime disableAnimations: true at 0; false at 1; original restored.',flush=True)
