"""Reuse checked QA helpers, with this task's fresh identity/data baseline."""
import sys,json,pathlib
sys.dont_write_bytecode=True
ROOT=pathlib.Path(__file__).parent
PREVIOUS=ROOT.parent/'TASK_UI_UX_05B_20261111_113152_839655'
sys.path.insert(0,str(PREVIOUS))
import qa05b as _helpers
baseline=json.loads((ROOT/'device_baseline.json').read_text(encoding='utf8'))
_helpers.ROOT=ROOT
_helpers.BASE={'configuration':{
    'rotation':baseline['configuration']['user_rotation'],
    'rotationAuto':baseline['configuration']['accelerometer_rotation'],
}}
_helpers.EVENTS=[]
for name in ['ADB','EVENTS','adb','pixels','shot','nodes','labels','tap','scroll','click','back','rotate','roundtrip','restore','save_events']:
    globals()[name]=getattr(_helpers,name)

_original_click = _helpers.click
def click(label,scrolled=False):
    # Date and filename can be merged into one accessibility node. Match the
    # complete filename line, never an ellipsis or an unrelated substring.
    if not label.lower().endswith(('.png','.jpg','.jpeg','.mp4')):
        return _original_click(label,scrolled)
    import re,time
    for _ in range(7 if scrolled else 2):
        for node in sorted(nodes(),key=lambda n:n.get('clickable')!='true'):
            if label in (node.get('content-desc') or node.get('text','')).splitlines():
                x1,y1,x2,y2=map(int,re.findall(r'-?\d+',node.get('bounds')))
                _,(w,h)=pixels()
                if x2>x1 and y2>y1 and 0<(y1+y2)//2<h-90:
                    tap((x1+x2)//2,(y1+y2)//2);return
        if scrolled:scroll()
        else:time.sleep(.3)
    raise RuntimeError('Media not reachable: '+label)
_helpers.click=click

_physical_scroll=scroll
def scroll(up=True):
    import re,time
    options=[n for n in nodes() if n.get('class')=='android.widget.ScrollView']
    if not options:return _physical_scroll(up)
    boxes=[list(map(int,re.findall(r'-?\d+',n.get('bounds')))) for n in options]
    x1,y1,x2,y2=max(boxes,key=lambda b:(b[2]-b[0])*(b[3]-b[1]))
    _,(_,height)=pixels();top=max(y1+24,100);bottom=min(y2-24,height-110)
    start,end=(bottom,top) if up else (top,bottom)
    adb('shell','input','swipe',str((x1+x2)//2),str(start),str((x1+x2)//2),str(end),'350')
    time.sleep(.4)
# Generic control searches keep their previously verified root-page scroll.
# File lookup above uses this scoped scroll for the media-picker viewport.
_helpers.scroll=_physical_scroll

_physical_rotate=rotate
def rotate(rotation):
    # ADB reports the new display dimensions before Flutter/platform surfaces
    # finish their configuration frame. This is a QA settle, not app latency.
    import time
    size=_physical_rotate(rotation)
    time.sleep(1.2)
    return size
