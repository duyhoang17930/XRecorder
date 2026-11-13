"""Boot only the existing, identified TASK09B AVD, without snapshot rollback."""
import pathlib,os,subprocess,json,uuid
root=pathlib.Path(__file__).parent.resolve()
home=pathlib.Path('build/verification/task09b/run_20261109T113727956224Z_f64203/avds').resolve()
avd=home/'ThreeHRecorder_TASK09B_API36.avd'
assert avd.is_dir() and (avd/'userdata-qemu.img.qcow2').is_file()
assert 'path='+str(avd) in (home/'ThreeHRecorder_TASK09B_API36.ini').read_text()
name='resume_avd_'+uuid.uuid4().hex[:8]
args=[r'C:\Users\dangh\AppData\Local\Android\sdk\emulator\emulator.exe','-avd','ThreeHRecorder_TASK09B_API36','-port','5570','-gpu','swiftshader_indirect','-no-snapshot-load','-no-snapshot-save','-no-window']
env=os.environ.copy();env['ANDROID_AVD_HOME']=str(home)
with (root/(name+'.log')).open('xb') as log:
    child=subprocess.Popen(args,env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
with (root/(name+'.json')).open('x') as report:
    json.dump({'pid':child.pid,'args':args,'existingAvd':str(avd),'noSnapshotLoad':True,'noSnapshotSave':True,'noNewAvd':True},report,indent=2)
print('QA launcher PID',child.pid,'LOG',name,flush=True)
