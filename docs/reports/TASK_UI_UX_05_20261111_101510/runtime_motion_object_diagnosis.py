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

lib=rpc("getObject",isolateId=isolate,objectId=library)
cls=next(x["id"] for x in lib["classes"] if x["name"]=="PlatformDispatcher")
c=rpc("getObject",isolateId=isolate,objectId=cls)
print(json.dumps(c.get("fields"),indent=2)[:9000])
