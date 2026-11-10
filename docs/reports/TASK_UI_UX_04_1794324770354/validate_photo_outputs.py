import qa04 as q,json,re,subprocess,pathlib,struct,hashlib
ffmpeg=str(pathlib.Path('build/task03/ffmpeg/ffmpeg.exe').resolve())
def decode(blob):
 return subprocess.check_output([ffmpeg,'-v','error','-i','pipe:0','-f','rawvideo','-pix_fmt','rgb24','pipe:1'],input=blob)
def changed(a,b):
 assert len(a)==len(b)
 return sum(a[i:i+3]!=b[i:i+3] for i in range(0,len(a),3))
source=q.adb('exec-out','cat','/sdcard/Download/UI02C_1794308051935/slider_fixture.png')
original=decode(source);result={'sourceSha256':hashlib.sha256(source).hexdigest(),'outputs':[]}
previous=original
for labelsFile in ['photo_saved_labels.json','photo_saved_labels_v2.json']:
 labels=json.loads((q.ROOT/labelsFile).read_text(encoding='utf8'))
 name=next(s for s in labels if re.fullmatch(r'Edited_\d+\.png',s))
 command='content query --uri content://media/external/images/media --projection _id:_display_name:width:height --where "_display_name=\''+name+'\'"'
 query=q.adb('shell',command).decode()
 mediaId=re.search(r'_id=(\d+)',query).group(1)
 uri='content://media/external/images/media/'+mediaId
 blob=q.adb('exec-out','content','read','--uri',uri)
 with (q.ROOT/name).open('xb') as f:f.write(blob)
 decoded=decode(blob);difference=changed(previous,decoded)
 assert difference>20
 result['outputs'].append({'name':name,'uri':uri,'sha256':hashlib.sha256(blob).hexdigest(),'size':len(blob),'dimensions':struct.unpack('>II',blob[16:24]),'changedPixelsFromInput':difference,'fullDecode':True})
 previous=decoded
bounds=json.loads((q.ROOT/'photo_interaction_result_v2.json').read_text())['canvasBounds']
def canvas(name):
 data=(q.ROOT/name).read_bytes();w,h=struct.unpack('>II',data[16:24]);raw=decode(data)
 return b''.join(raw[(y*w+bounds[0])*3:(y*w+bounds[2])*3] for y in range(bounds[1],bounds[3]))
drawn=canvas('photo_drawn_v2.png');undo=canvas('photo_undone_v2.png');redo=canvas('photo_redone_v2.png');rotated=canvas('photo_drawn_v2_portrait_return.png')
result['previewPixelComparison']={'undoChangedPixels':changed(drawn,undo),'redoChangedPixels':changed(drawn,redo),'rotationReturnChangedPixels':changed(drawn,rotated)}
assert result['previewPixelComparison']['undoChangedPixels']>20
assert result['previewPixelComparison']['redoChangedPixels']==0
with (q.ROOT/'photo_output_validation.json').open('x',encoding='utf8') as f:json.dump(result,f,indent=2)
print(json.dumps(result,indent=2))
