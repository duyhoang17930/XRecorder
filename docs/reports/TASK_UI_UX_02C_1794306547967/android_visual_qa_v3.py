"""Focused main-app QA on the identified dedicated AVD; no capture actions."""
import pathlib, subprocess, time, re, xml.etree.ElementTree as ET, json, uuid
ROOT=pathlib.Path(__file__).parent
ADB=[r'C:\Users\dangh\AppData\Local\Android\sdk\platform-tools\adb.exe','-s','emulator-5570']
ACTIONS=[]
def adb(*args):
    return subprocess.check_output(ADB+list(args),timeout=30)
assert b'ThreeHRecorder_TASK09B_API36' in adb('shell','getprop','ro.boot.qemu.avd_name')
def shot(name):
    (ROOT/(name+'.png')).open('xb').write(adb('exec-out','screencap','-p'))
def tap(x,y):
    adb('shell','input','tap',str(x),str(y)); time.sleep(.45)
def swipe(up=True):
    adb('shell','input','swipe','200','740' if up else '250','200','260' if up else '760','250'); time.sleep(.4)
def nodes():
    remote='/sdcard/ui02c_'+uuid.uuid4().hex+'.xml'
    adb('shell','uiautomator','dump',remote)
    return ET.fromstring(adb('exec-out','cat',remote)).iter('node')
def click(label,scroll=False):
    for attempt in range(6 if scroll else 1):
        for n in nodes():
            desc=n.get('content-desc') or n.get('text','')
            if desc.split('\n')[0]==label:
                x1,y1,x2,y2=map(int,re.findall(r'\d+',n.get('bounds')))
                if y2-y1>=25 and y2<(830 if scroll else 920):
                    tap((x1+x2)//2,(y1+y2)//2); ACTIONS.append(label); return
        if scroll: swipe()
    raise RuntimeError('Not reachable: '+label)
def tour(theme):
    tap(295,860); tap(295,860); time.sleep(.5)
    click(theme)
    shot('settings_'+theme.lower())
    click('View introduction',True)
    for i in range(3):
        shot('onboarding_'+theme.lower()+'_'+str(i+1))
        click('Get Started' if i==2 else 'Next')
    assert not any((n.get('content-desc') or '').startswith('Record Anything') for n in nodes())
    tap(295,860)
adb('shell','input','keyevent','4')
adb('shell','am','start','-n','com.xrecorder.xrecorder/.MainActivity')
time.sleep(1)
tap(295,860)
tap(295,860)
click('Light')
click('View introduction',True)
click('Next')
click('Next')
time.sleep(2)
shot('onboarding_light_3_stable')
click('Get Started')
tap(295,860)
click('Dark')
tap(373,860)
labels=[n.get('content-desc') or n.get('text','') for n in nodes()]
print(labels)
shot('create_modal_verified')
(ROOT/'actions_v3.json').open('x').write(json.dumps(ACTIONS))
