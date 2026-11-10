import qa04 as q,time,re,json,subprocess,uuid
import struct,pathlib

def rect(label):
 for n in sorted(q.nodes(),key=lambda n:n.get('clickable')!='true'):
  if (n.get('content-desc') or n.get('text','')).split('\n')[0]==label:
   b=list(map(int,re.findall(r'\d+',n.get('bounds'))))
   if b[2]>b[0] and b[3]>b[1]:return b
 raise AssertionError(label)
def center(r):return ((r[0]+r[2])//2,(r[1]+r[3])//2)
def tap(r):q.adb('shell','input','tap',*map(str,center(r)));time.sleep(.4)
def canvas_bounds():
 data=q.pixels()[0];w,h=struct.unpack('>II',data[16:24])
 raw=subprocess.check_output([str(pathlib.Path('build/task03/ffmpeg/ffmpeg.exe').resolve()),'-v','error','-i','pipe:0','-f','rawvideo','-pix_fmt','rgb24','pipe:1'],input=data)
 pts=[]
 for y in range(120,h-200):
  for x in range(16,w-16):
   rgb=raw[(y*w+x)*3:(y*w+x)*3+3]
   if any(rgb[c]>245 and all(rgb[j]<12 for j in range(3) if j!=c) for c in range(3)):pts.append((x,y))
 return [min(p[0] for p in pts),min(p[1] for p in pts),max(p[0] for p in pts)+1,max(p[1] for p in pts)+1]

rec=None
q.click('Crop & annotate a copy',True)
try:
 pen=rect('Pen');ink=rect('Color');undo=rect('Undo photo edit');redo=rect('Redo photo edit');alltools=rect('All tools')
 q.click('Color');cyan=rect('Cyan ink');q.click('Close')
 q.click('All tools');rectangle=rect('Rectangle');q.back()
 slider=next(n for n in q.nodes() if n.get('class')=='android.widget.SeekBar')
 sb=list(map(int,re.findall(r'\d+',slider.get('bounds'))));image=canvas_bounds()
 remote='/sdcard/ui04_interaction_'+uuid.uuid4().hex+'.mp4'
 rec=subprocess.Popen(q.ADB+['shell','screenrecord','--bit-rate','900000','--time-limit','40',remote],creationflags=subprocess.CREATE_NO_WINDOW)
 time.sleep(.4);tap(pen);tap(ink);tap(cyan)
 sy=(sb[1]+sb[3])//2
 q.adb('shell','input','swipe',str((sb[0]+sb[2])//2),str(sy),str(q.pixels()[1][0]-70),str(sy),'350');time.sleep(.3)
 y=(image[1]+image[3])//2
 q.adb('shell','input','swipe',str(image[0]+40),str(y),str(image[2]-40),str(y+15),'700');time.sleep(.5)
 q.shot('photo_drawn_v2');tap(undo);q.shot('photo_undone_v2');tap(redo);q.shot('photo_redone_v2')
 tap(alltools);tap(rectangle)
 q.rotate(1);time.sleep(1);q.shot('photo_drawn_v2_landscape')
 q.rotate(0);time.sleep(1);q.shot('photo_drawn_v2_portrait_return')
 rec.wait();q.adb('pull',remote,str(q.ROOT/'photo_interaction_v2.mp4'))
 labels=q.labels();assert 'Rectangle' in labels
 with (q.ROOT/'photo_interaction_result_v2.json').open('x',encoding='utf8') as f:json.dump({'canvasBounds':image,'sliderBounds':sb,'labelsAfter':labels,'actions':['Pen','Color','Cyan ink','Stroke width','Draw','Undo','Redo','Rectangle','Landscape','Portrait']},f,ensure_ascii=False,indent=2)
 q.click('Save copy');time.sleep(2)
 labels=q.labels();q.shot('photo_saved_copy_details_v2')
 with (q.ROOT/'photo_saved_labels_v2.json').open('x',encoding='utf8') as f:json.dump(labels,f,ensure_ascii=False,indent=2)
finally:
 if rec is not None and rec.poll() is None:rec.wait()
 q.restore()
