from pathlib import Path
import subprocess,os,uuid,datetime,sys
p=Path(__file__).parent
log=p/('native_test_build_'+datetime.datetime.now().strftime('%H%M%S')+'_'+uuid.uuid4().hex[:6]+'.txt')
cmd=['cmd','/c','gradlew.bat',':app:assembleDebugAndroidTest','--offline','--max-workers=2','-Ptarget-platform=android-x64','-Ptarget='+str(Path('lib/main.dart').resolve())]
env=dict(os.environ);env['JAVA_HOME']=r'D:\Android\jbr'
with log.open('x',encoding='utf8') as f:
    f.write(str(cmd)+'\n');f.flush()
    process=subprocess.Popen(cmd,cwd='android',env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
    for line in iter(process.stdout.readline,b''):
        text=line.decode('utf8',errors='replace');f.write(text);f.flush();print(text.encode('ascii',errors='replace').decode(),end='',flush=True)
    code=process.wait();f.write('\nExit='+str(code)+'\n')
print(log,flush=True);sys.exit(code)
