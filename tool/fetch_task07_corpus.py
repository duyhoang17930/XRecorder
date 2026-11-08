"""Stream one real FLEURS test recording and reference per language into QA output.

No full-corpus download, arbitrary archive extraction, user-media access or upload.
"""
import csv
import hashlib
import io
import json
import tarfile
import urllib.request
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/verification/task07/corpus'
REVISION='70bb2e84b976b7e960aa89f1c648e09c59f894dd'
CONFIGS={'en':'en_us','vi':'vi_vn','es':'es_419','pt':'pt_br','fr':'fr_fr','de':'de_de',
         'id':'id_id','ja':'ja_jp','ko':'ko_kr','zh':'cmn_hans_cn','hi':'hi_in','ar':'ar_eg'}

def url(config,path):
    return f'https://huggingface.co/datasets/google/fleurs/resolve/{REVISION}/data/{config}/{path}'

class LimitedStream:
    def __init__(self,response):self.response,self.read_bytes=response,0
    def read(self,size=-1):
        if size<0 or self.read_bytes+size>64*1024*1024:raise ValueError('Archive fixture exceeded 64 MiB stream budget')
        data=self.response.read(size);self.read_bytes+=len(data);return data

def fetch(code,config):
    path=OUT/f'{code}_source.json'
    if path.exists():
        old=json.loads(path.read_text(encoding='utf8'));audio=OUT/old['file']
        if audio.exists() and hashlib.sha256(audio.read_bytes()).hexdigest()==old['sha256']:return old
        raise ValueError('Existing QA fixture changed; preserving it for inspection')
    with urllib.request.urlopen(url(config,'test.tsv'),timeout=60) as response:tsv=response.read()
    (OUT/f'{config}_test.tsv').write_bytes(tsv)
    records={row[1]:row for row in csv.reader(io.StringIO(tsv.decode('utf8')),delimiter='\t')}
    with urllib.request.urlopen(url(config,'audio/test.tar.gz'),timeout=60) as response:
        stream=LimitedStream(response)
        with tarfile.open(fileobj=stream,mode='r|gz') as archive:
            for member in archive:
                row=records.get(Path(member.name).name)
                if not member.isfile() or row is None or not member.name.endswith('.wav'):continue
                duration=int(row[5])/16000
                if not 2<=duration<=30 or not 0<member.size<=5*1024*1024:continue
                audio=archive.extractfile(member).read()
                local=f'fleurs_{code}_source.wav';raw_path=OUT/local
                if raw_path.exists() and raw_path.read_bytes()!=audio:raise ValueError('Existing raw fixture differs; preserving it')
                raw_path.write_bytes(audio)
                probe=json.loads(subprocess.check_output([str(ROOT/'build/task03/ffmpeg/ffprobe.exe'),'-v','error','-show_streams','-of','json',str(raw_path)]))['streams'][0]
                actual=float(probe['duration']);rate=int(probe['sample_rate']);channels=probe['channels']
                assert abs(actual-duration)<.05
                canonical=OUT/f'fleurs_{code}.wav'
                subprocess.run([str(ROOT/'build/task03/ffmpeg/ffmpeg.exe'),'-v','error','-n','-i',str(raw_path),'-ar','16000','-ac','1','-c:a','pcm_s16le',str(canonical)],check=True)
                data={'dataset':'google/fleurs','revision':REVISION,'license':'CC-BY-4.0',
                      'source':url(config,'audio/test.tar.gz'),'config':config,'split':'test','id':row[0],
                      'archiveMember':member.name,'reference':row[2],'normalizedReference':row[3],
                      'durationMs':round(actual*1000),'sampleRate':rate,'channels':channels,'file':local,
                      'sha256':hashlib.sha256(audio).hexdigest(),'archiveBytesRead':stream.read_bytes,
                      'canonicalFile':canonical.name,'canonicalSha256':hashlib.sha256(canonical.read_bytes()).hexdigest(),
                      'conversion':'FFmpeg PCM s16le, mono, 16000 Hz; original raw WAV retained unchanged.',
                      'selection':'First matching archive member lasting 2–30 seconds; no recognition-based selection.'}
                path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8');return data
    raise ValueError('No eligible recording')

if __name__=='__main__':
    OUT.mkdir(exist_ok=True,parents=True)
    for code,config in CONFIGS.items():
        try:
            data=fetch(code,config);print(f'{code}: real speech {data["durationMs"]} ms; archive bytes read {data["archiveBytesRead"]}',flush=True)
        except Exception as error:print(f'{code}: {type(error).__name__}: {error}',flush=True)
