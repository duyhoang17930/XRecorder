import qa05b as q
import json,re,hashlib,pathlib

apk=pathlib.Path('build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk')
installed=q.adb('install','-r',str(apk.resolve()),timeout=120)
with (q.ROOT/'install_native_test_final.txt').open('xb') as f:f.write(installed)
assert b'Success' in installed,installed
result=q.adb('shell','am','instrument','-w','-e','ui05b','player','-e','uri','content://media/external/video/media/1536',
    '-e','sha256','81f4af10f09032118ecdfb8e20a23c48dce68da4573582b00e55a0f0f577a6e3',
    'com.xrecorder.xrecorder.test/com.xrecorder.xrecorder.qa.Task07AccessibilityInstrumentation',timeout=180)
with (q.ROOT/'native_player_result_final.txt').open('xb') as f:f.write(result)
text=result.decode(errors='replace');print(text.encode('ascii',errors='replace').decode(),flush=True)
line=next((line for line in text.splitlines() if line.startswith('INSTRUMENTATION_RESULT: ui05b=')),None)
assert line is not None and json.loads(line.split('=',1)[1])['status']=='PASS',text
q.restore()
