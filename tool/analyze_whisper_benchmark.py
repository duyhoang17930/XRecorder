"""Measure recorded ASR outputs against the public fixture reference."""
import json
from pathlib import Path
import unicodedata

root=Path('build/verification/p2_p3')
source=root/'whisper/native/emulator_verification.json'
result=json.loads(source.read_text(encoding='utf-8'))
small=root/'whisper/small/emulator_verification.json'
if small.exists():
    result['benchmarks'].extend(json.loads(small.read_text(encoding='utf-8'))['benchmarks'])
memory=root/'whisper/small_memory.json'
if memory.exists():
    result['smallPeakPssKiB']=json.loads(memory.read_text(encoding='utf-8'))['peakPssKiB']
reference=json.loads((root/'models/fleurs_vi_fixture.json').read_text(encoding='utf-8'))['reference']
def normalize(text):
    return ''.join(c for c in unicodedata.normalize('NFC',text.lower()) if c.isalpha())
def distance(a,b):
    previous=list(range(len(b)+1))
    for i,x in enumerate(a,1):
        current=[i]
        for j,y in enumerate(b,1):
            current.append(min(current[-1]+1,previous[j]+1,previous[j-1]+(x!=y)))
        previous=current
    return previous[-1]
for entry in result['benchmarks']:
    entry['realTimeFactor']=entry['elapsedMs']/1000/(11.34 if entry['language']=='vi' else 11.0)
    if entry['language']=='vi':
        entry['CER']=distance(normalize(reference),normalize(entry['transcript']))/len(normalize(reference))
result['scope']='One English public-domain JFK sample and one CC-BY-4.0 Google FLEURS Vietnamese sample; not a broad accuracy benchmark.'
result['referenceVi']=reference
(root/'whisper/benchmark.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps([{'model':v['model'],'language':v['language'],'RTF':v['realTimeFactor'],'CER':v.get('CER')} for v in result['benchmarks']],indent=2))
