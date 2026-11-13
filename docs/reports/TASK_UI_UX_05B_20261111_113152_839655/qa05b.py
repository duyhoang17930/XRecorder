"""UI05B main-app QA. All artifacts exclusive; only the identified QA AVD."""
import subprocess,pathlib,xml.etree.ElementTree as ET,re,time,struct,json,uuid
ROOT=pathlib.Path(__file__).parent
ADB=[r'C:\Users\dangh\AppData\Local\Android\sdk\platform-tools\adb.exe','-s','emulator-5570']
BASE=json.loads((ROOT/'device_baseline.json').read_text(encoding='utf8'))
EVENTS=[]
def adb(*args,timeout=30):
 return subprocess.check_output(ADB+list(args),timeout=timeout)
assert adb('shell','getprop','ro.boot.qemu.avd_name').decode().strip()=='ThreeHRecorder_TASK09B_API36'
def pixels():
 data=adb('exec-out','screencap','-p')
 assert data.startswith(b'\x89PNG')
 return data,struct.unpack('>II',data[16:24])
def shot(name):
 data,size=pixels()
 path=ROOT/(name+'.png')
 with path.open('xb') as f:f.write(data)
 return size
def nodes():
 for _ in range(4):
  p='/sdcard/ui05b_'+uuid.uuid4().hex+'.xml'
  adb('shell','uiautomator','dump',p)
  raw=adb('exec-out','cat',p)
  if raw.lstrip().startswith(b'<?xml'):return list(ET.fromstring(raw).iter('node'))
  time.sleep(.5)
 raise RuntimeError('No Android UI hierarchy')
def labels():
 return [n.get('content-desc') or n.get('text','') for n in nodes() if n.get('content-desc') or n.get('text')]
def tap(x,y):
 adb('shell','input','tap',str(int(x)),str(int(y)));time.sleep(.7)
def scroll(up=True):
 _,(w,h)=pixels()
 adb('shell','input','swipe',str(w//2),str(int(h*(.78 if up else .28))),str(w//2),str(int(h*(.28 if up else .78))),'400')
 time.sleep(.5)
def click(label,scrolled=False):
 for _ in range(7 if scrolled else 2):
  ns=sorted(nodes(),key=lambda n:n.get('clickable')!='true');_,(w,h)=pixels()
  for n in ns:
   text=n.get('content-desc') or n.get('text','')
   if text.split('\n')[0]==label:
    x1,y1,x2,y2=map(int,re.findall(r'-?\d+',n.get('bounds','')))
    x=max(4,min(w-4,(x1+x2)//2));y=(y1+y2)//2
    if y2-y1>=12 and x2>x1 and 0<y<h-(90 if scrolled else 10):
     tap(x,y);return
  if scrolled:scroll()
  else:time.sleep(.6)
 raise RuntimeError('Control not reachable: '+label)
def back():
 adb('shell','input','keyevent','4');time.sleep(.6)
def rotate(r):
 adb('shell','settings','put','system','accelerometer_rotation','0')
 adb('shell','settings','put','system','user_rotation',str(r))
 for _ in range(12):
  time.sleep(.3);_,(w,h)=pixels()
  if (w>h)==(r%2==1):return (w,h)
 raise RuntimeError('Display did not rotate')
def roundtrip(name,marker,save=False):
 results=[]
 for r in [0,1,0]:
  size=rotate(r); text=labels(); ok=any(marker in t for t in text)
  result={'screen':name,'rotation':r,'size':size,'marker':marker,'markerFound':ok,'labels':text}
  if save:
   result['image']=name+('_landscape' if r else '_portrait')+'_'+str(len(EVENTS))+'.png'
   shot(result['image'][:-4])
  EVENTS.append(result);results.append(result)
  if not ok:raise AssertionError('Lost screen/state '+name)
 return results
def restore():
 adb('shell','settings','put','system','user_rotation',BASE['configuration']['rotation'])
 adb('shell','settings','put','system','accelerometer_rotation',BASE['configuration']['rotationAuto'])
def save_events(name):
 with (ROOT/(name+'.json')).open('x',encoding='utf8') as f:json.dump(EVENTS,f,ensure_ascii=False,indent=2)

