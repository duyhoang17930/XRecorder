import qa06 as q
import json,re,time,subprocess,uuid

def bounds(node):return list(map(int,re.findall(r'-?\d+',node.get('bounds'))))

def field(value):
    node=next(n for n in q.nodes() if n.get('class')=='android.widget.EditText')
    b=bounds(node);q.tap((b[0]+b[2])//2,(b[1]+b[3])//2)
    q.adb('shell','input','text',value)

def tool(label):
    for attempt in range(6):
        nodes=q.nodes()
        # Flutter can expose scrollable=false at the leading boundary even
        # though a real horizontal drag reveals the remaining tools.
        options=[n for n in nodes if n.get('class')=='android.widget.HorizontalScrollView']
        strip=bounds(max(options,key=lambda n:bounds(n)[3])) if options else None
        for node in sorted(nodes,key=lambda n:n.get('clickable')!='true'):
            if (node.get('content-desc') or node.get('text','')).splitlines()[:1]!=[label]:continue
            x1,y1,x2,y2=bounds(node);x=(x1+x2)//2;y=(y1+y2)//2
            # Semantics can expose a child beyond its clipped horizontal
            # viewport. Never clamp that coordinate onto an unrelated button.
            if strip is not None and not (strip[0]+24<=x<=strip[2]-24 and strip[1]<=y<=strip[3]):continue
            _,(w,h)=q.pixels()
            if 24<=x<=w-24 and 24<=y<=h-24:q.tap(x,y);return
        if not options:raise RuntimeError('No visible tool or scroll strip for '+label)
        node=max(options,key=lambda n:bounds(n)[3]);x1,y1,x2,y2=bounds(node)
        # Stay outside Android's edge-Back gesture area. RTL tool strips reveal
        # their remaining entries by swiping in the opposite direction.
        rtl=any('\u0600'<=char<='\u06ff' for char in label)
        start,end=(x1+40,x2-40) if rtl else (x2-40,x1+40)
        if attempt>=3:start,end=end,start
        q.adb('shell','input','swipe',str(start),str((y1+y2)//2),str(end),str((y1+y2)//2),'250')
    raise RuntimeError('Tool not reachable: '+label)

def panel(label):
    for _ in range(5):
        try:q.click(label);return
        except RuntimeError:pass
        options=[n for n in q.nodes() if n.get('class')=='android.widget.ScrollView' and n.get('scrollable')=='true']
        if not options:raise RuntimeError('No context viewport for '+label)
        x1,y1,x2,y2=bounds(max(options,key=lambda n:bounds(n)[3]))
        q.adb('shell','input','swipe',str((x1+x2)//2),str(y2-12),str((x1+x2)//2),str(y1+12),'250')
    raise RuntimeError('Panel action not reachable: '+label)

def projects():return set(q.adb('shell','run-as','com.xrecorder.xrecorder','find','files/projects','-name','*.json').decode().splitlines())
def read_project(name):return json.loads(q.adb('exec-out','run-as','com.xrecorder.xrecorder','cat',name))

class Video:
    """Stop only the screenrecord process this instance launched and verified."""
    def __init__(self,name):self.name=name
    def __enter__(self):
        self.remote='/sdcard/ui06_'+uuid.uuid4().hex+'.mp4'
        self.process=subprocess.Popen(q.ADB+['shell','screenrecord','--bit-rate','800000','--time-limit','180',self.remote],creationflags=subprocess.CREATE_NO_WINDOW)
        time.sleep(.5)
        self.pid=None
        for pid in q.adb('shell','pidof','screenrecord').decode().split():
            if not pid.isdigit():continue
            command=q.adb('exec-out','cat','/proc/'+pid+'/cmdline').decode()
            if self.remote in command and 'screenrecord' in command:
                self.pid=pid;self.command=command;break
        assert self.pid is not None,'Cannot identify owned evidence recorder'
        return self
    def __exit__(self,*error):
        if self.process.poll() is None:
            command=q.adb('exec-out','cat','/proc/'+self.pid+'/cmdline').decode()
            assert command==self.command and self.remote in command
            q.adb('shell','kill','-2',self.pid) # own Android evidence recorder only
        self.process.wait(timeout=15)
        with (q.ROOT/(self.name+'.mp4')).open('xb') as f:f.write(q.adb('exec-out','cat',self.remote,timeout=60))
        with (q.ROOT/(self.name+'_recorder.json')).open('x') as f:json.dump({'pid':self.pid,'verifiedCommand':self.command,'remote':self.remote,'ownProcessOnly':True},f)

def event(name):
    q.EVENTS.append({'case':name,'time':time.time(),'labels':q.labels()})
    print(name,flush=True)
