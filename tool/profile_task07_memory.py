"""Read-only PSS samples for the dedicated TASK07 AVD; no process control."""
import json
import re
import subprocess
import time
import argparse
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/verification/task07'
ADB=Path('C:/Users/dangh/AppData/Local/Android/Sdk/platform-tools/adb.exe')
SERIAL='emulator-5560'

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--run',default='g2');args=parser.parse_args()
    if not re.fullmatch(r'[a-z0-9_]+',args.run):raise SystemExit('Invalid run name')
    name=subprocess.check_output([str(ADB),'-s',SERIAL,'emu','avd','name'],text=True)
    if 'ThreeHRecorder_Task021' not in name:raise SystemExit('Dedicated QA AVD required')
    stop=OUT/f'{args.run}_memory.stop'
    if stop.exists():raise SystemExit('Previous stop marker present; choose a new run explicitly')
    end=time.monotonic()+5400
    with (OUT/f'{args.run}_memory.jsonl').open('a',encoding='utf8') as output:
        while time.monotonic()<end and not stop.exists():
            start=time.monotonic()
            result=subprocess.run([str(ADB),'-s',SERIAL,'shell','dumpsys','meminfo','com.xrecorder.xrecorder','-s'],capture_output=True,text=True,timeout=20)
            match=re.search(r'TOTAL PSS:\s*([0-9,]+)',result.stdout)
            if match:
                output.write(json.dumps({'hostUtcMs':round(time.time()*1000),'pssKiB':int(match[1].replace(',','')),'sampleQueryMs':round((time.monotonic()-start)*1000)})+'\n');output.flush()
            time.sleep(2)
