"""Sequential Flutter CLI check with a collision-safe UTF-8 log."""
import pathlib,subprocess,sys,uuid,datetime
root=pathlib.Path(__file__).parent
label=sys.argv[1]
command=[r'D:\Android\flutter\bin\cache\dart-sdk\bin\dart.exe',r'D:\Android\flutter\bin\cache\flutter_tools.snapshot']+sys.argv[2:]
path=root/(label+'_'+datetime.datetime.now().strftime('%H%M%S')+'_'+uuid.uuid4().hex[:8]+'.txt')
with path.open('x',encoding='utf8') as log:
 log.write(subprocess.list2cmdline(command)+'\n');log.flush()
 process=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
 for line in iter(process.stdout.readline,b''):
  text=line.decode('utf8',errors='replace');log.write(text);log.flush()
  print(text.encode('ascii',errors='replace').decode(),end='',flush=True)
 code=process.wait();log.write('\nExit='+str(code)+'\n')
print('LOG='+str(path),flush=True)
sys.exit(code)
