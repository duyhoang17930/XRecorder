"""Measure recorded ASR outputs against the public fixture reference."""
import json
from pathlib import Path
import unicodedata
import argparse
import array
import csv
import hashlib
import io
import math
import random
import statistics
import subprocess
import tarfile
import urllib.request
import wave
import re
import time
import urllib.parse

if __package__:
    from .asr_metrics import distance
else:
    from asr_metrics import distance

def prepare_corpus(out):
    """Small licensed subset; preserve originals and distinguish train/test."""
    out.mkdir(parents=True, exist_ok=True)
    entries = []
    ffmpeg = Path('build/task03/ffmpeg/ffmpeg.exe')
    selections = [('vi_vn', 'test', {'MALE': 3}),
                  ('vi_vn', 'train', {'FEMALE': 3}),
                  ('en_us', 'test', {'MALE': 1, 'FEMALE': 1})]
    for language, split, desired in selections:
        base = 'https://huggingface.co/datasets/google/fleurs/resolve/main/data/' + language
        metadata = urllib.request.urlopen(base + '/' + split + '.tsv', timeout=30).read()
        (out / (language + '_' + split + '.tsv')).write_bytes(metadata)
        rows = {r[1]: r for r in csv.reader(io.StringIO(metadata.decode('utf-8')), delimiter='\t')}
        counts = {g: 0 for g in desired}
        url = base + '/audio/' + split + '.tar.gz'
        with urllib.request.urlopen(url, timeout=60) as response, tarfile.open(fileobj=response, mode='r|gz') as archive:
            for member in archive:
                name = Path(member.name).name
                if name not in rows:
                    continue
                row = rows[name]
                gender = row[-1]
                if gender not in desired or counts[gender] >= desired[gender]:
                    continue
                raw = archive.extractfile(member).read()
                stem = 'quality_' + language + '_' + str(len(entries))
                source, target = out / (stem + '_original.wav'), out / (stem + '.wav')
                source.write_bytes(raw)
                subprocess.run([str(ffmpeg), '-v', 'error', '-y', '-i', str(source), '-ac', '1', '-ar', '16000', '-c:a', 'pcm_s16le', str(target)], check=True)
                with wave.open(str(target)) as wav:
                    duration = round(wav.getnframes() / wav.getframerate() * 1000)
                entries.append(dict(file=target.name, language=language[:2], reference=row[2], gender=gender,
                                    durationMs=duration, sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                                    originalSha256=hashlib.sha256(raw).hexdigest(), original=name, id=row[0],
                                    dataset='google/fleurs', subset=split, license='CC-BY-4.0', source=url,
                                    accent='not annotated', condition='clean'))
                counts[gender] += 1
                print(language, split, gender, duration, flush=True)
                if counts == desired:
                    break
        assert counts == desired
    first = entries[0]
    with wave.open(str(out / first['file'])) as wav:
        clean = array.array('h', wav.readframes(wav.getnframes()))
    def save(name, samples, metadata):
        path = out / name
        with wave.open(str(path), 'wb') as wav:
            wav.setparams((1, 2, 16000, len(samples), 'NONE', 'not compressed'))
            wav.writeframes(array.array('h', samples).tobytes())
        entries.append({**metadata, 'file': name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    rms = math.sqrt(sum(x*x for x in clean) / len(clean))
    for snr in [20, 5]:
        rng = random.Random(42)
        noise_rms = rms / 10**(snr / 20)
        mixed = [max(-32768, min(32767, round(x + rng.gauss(0, noise_rms)))) for x in clean]
        save('quality_noise_' + str(snr) + '.wav', mixed, {**first, 'condition': 'white_noise_' + str(snr) + 'dB', 'noiseSeed': 42})
    for name, samples in [('silence', [0]*64000), ('music', [round(5000*math.sin(2*math.pi*440*i/16000)+3000*math.sin(2*math.pi*660*i/16000)) for i in range(64000)])]:
        save('quality_' + name + '.wav', samples, dict(language='auto', reference='', gender='not applicable', durationMs=4000, condition=name, source='synthetic deterministic QA control'))
    (out / 'manifest.json').write_text(json.dumps(entries, ensure_ascii=False, indent=2), encoding='utf-8')
    print('Corpus retained:', len(entries), flush=True)


args_parser = argparse.ArgumentParser()
args_parser.add_argument('--prepare-corpus', type=Path)
args_parser.add_argument('--evaluate-corpus', type=Path)
args_parser.add_argument('--native-report', type=Path)
args_parser.add_argument('--output', type=Path)
args_parser.add_argument('--sample-log', type=Path)
args_parser.add_argument('--sample-seconds', type=int, default=1200)
args = args_parser.parse_args()
if args.prepare_corpus:
    prepare_corpus(args.prepare_corpus)
    raise SystemExit(0)
if args.sample_log:
    adb = 'C:/Users/dangh/AppData/Local/Android/Sdk/platform-tools/adb.exe'
    def device(*words):
        return subprocess.check_output([adb, '-s', 'emulator-5560', *words], text=True, encoding='utf-8', errors='replace', timeout=12).strip()
    assert device('shell','getprop','ro.boot.qemu.avd_name') == 'ThreeHRecorder_Task021'
    samples=[]; vm_url=None; isolate=None; retained_heap=None; deadline=time.monotonic()+args.sample_seconds
    while time.monotonic()<deadline:
        time.sleep(3)
        raw=args.sample_log.read_bytes() if args.sample_log.exists() else b''
        text=raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8',errors='replace')
        endpoints=re.findall(r'http://127\.0\.0\.1:\d+/[A-Za-z0-9_=-]+/',text)
        # Flutter prints the device port first and the host-forwarded port last.
        if endpoints:vm_url=endpoints[-1]
        markers=re.findall(r'FINALQA_(?:ASR|SOAK)=([^\r\n]+)',text)
        try:
            pids=device('shell','pidof','com.xrecorder.xrecorder').split()
            if not pids:continue
            memory=device('shell','dumpsys','meminfo','-s',pids[0])
            def value(label):
                found=re.search(label+r':\s*(\d+)',memory);return int(found[1]) if found else None
            row={'hostMonotonic':time.monotonic(),'pid':pids[0],'phase':markers[-1] if markers else 'initializing','pssKiB':value('TOTAL PSS'),'rssKiB':value('TOTAL RSS'),'raw':memory}
            if vm_url:
                def rpc(method,**params):
                    url=vm_url+method+('?' + urllib.parse.urlencode(params) if params else '')
                    with urllib.request.urlopen(url,timeout=2) as response:return json.load(response)['result']
                try:
                    if isolate is None:isolate=rpc('getVM')['isolates'][0]['id']
                    row['dartHeap']=rpc('getMemoryUsage',isolateId=isolate)
                    if row['phase']=='retained_idle' and retained_heap is None:
                        profile=rpc('getAllocationProfile',isolateId=isolate,gc='true')
                        retained_heap={'pid':pids[0],'beforeGC':row['dartHeap'],
                                       'afterGC':rpc('getMemoryUsage',isolateId=isolate),
                                       'largestClasses':sorted(profile['members'],key=lambda v:v.get('bytesCurrent',0),reverse=True)[:20]}
                except Exception:isolate=None
            samples.append(row);args.output.write_text(json.dumps({'samples':samples,'retainedHeap':retained_heap,'peakPssKiB':max(s['pssKiB'] or 0 for s in samples),'scope':'3-second sampled PSS/RSS and VM heap; optional explicit development GC at idle; not exact allocation peak or leak certification.'},indent=2),encoding='utf-8')
        except (subprocess.SubprocessError, OSError):pass
        if vm_url and ('All tests passed' in text or 'Some tests failed' in text):break
    print('Memory samples retained:',len(samples));raise SystemExit(0)

def normalize(text):
    return ''.join(c for c in unicodedata.normalize('NFC',text.lower()) if c.isalpha())
if args.evaluate_corpus:
    corpus = {v['file']:v for v in json.loads((args.evaluate_corpus/'manifest.json').read_text(encoding='utf-8'))}
    report=json.loads(args.native_report.read_text(encoding='utf-8'))
    assert not report.get('partial'), 'Do not summarize an incomplete native run as PASS'
    seen=set(); rows=[]
    def words(text):
        return ''.join(c if c.isalnum() or c.isspace() else ' ' for c in unicodedata.normalize('NFC',text.lower())).split()
    for entry in report['benchmarks']:
        spec=corpus[entry['file']]; key=(entry['model'],entry['file'])
        if key in seen:continue  # Repeated soak samples are not independent accuracy observations.
        seen.add(key)
        ref=normalize(spec['reference']); actual=normalize(entry['transcript'])
        rw,aw=words(spec['reference']),words(entry['transcript'])
        rows.append({**entry,'condition':spec['condition'],'gender':spec['gender'],'durationMs':spec['durationMs'],
                     'reference':spec['reference'],'subset':spec.get('subset','synthetic'),
                     'CER':distance(ref,actual)/len(ref) if ref else None,
                     'WER':distance(rw,aw)/len(rw) if rw else None,
                     'RTF':entry['elapsedMs']/spec['durationMs']})
    groups=[]
    for model in sorted({r['model'] for r in rows}):
        for label,select in [('vi_clean',lambda r:r['language']=='vi' and r['condition']=='clean'),('en_clean',lambda r:r['language']=='en' and r['condition']=='clean'),('vi_noisy',lambda r:r['language']=='vi' and r['condition']!='clean')]:
            selected=[r for r in rows if r['model']==model and select(r)]
            if not selected:continue
            times=sorted(r['elapsedMs'] for r in selected)
            groups.append({'model':model,'subset':label,'n':len(selected),'seconds':sum(r['durationMs'] for r in selected)/1000,
                           'meanCER':statistics.mean(r['CER'] for r in selected), 'meanWER':statistics.mean(r['WER'] for r in selected),
                           'medianRTF':statistics.median(r['RTF'] for r in selected),'medianMs':statistics.median(times),'p95Ms':times[math.ceil(len(times)*.95)-1]})
    output={'rows':rows,'groups':groups,'nativeJobRuns':len(report['benchmarks']),
            'nativeInferenceRuns':sum((r.get('inferenceMs') or 0)>0 for r in report['benchmarks']),
            'counterNote':'Digital-silence jobs intentionally skip Whisper. The first raw harness labeled all jobs nativeInferenceRuns; actual inference count is derived from recorded native timings.',
            'normalization':'NFC lowercase; CER alphabetic only, spaces/punctuation removed, diacritics retained; WER alphanumeric words, punctuation replaced by spaces.',
            'scope':'Six VI utterances (three test MALE, three train FEMALE labels), two EN utterances, deterministic noise/silence/music. Speaker identity/accent unannotated; not broad population or held-out training certification.'}
    args.output.write_text(json.dumps(output,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(groups,indent=2));raise SystemExit(0)
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
for entry in result['benchmarks']:
    entry['realTimeFactor']=entry['elapsedMs']/1000/(11.34 if entry['language']=='vi' else 11.0)
    if entry['language']=='vi':
        entry['CER']=distance(normalize(reference),normalize(entry['transcript']))/len(normalize(reference))
result['scope']='One English public-domain JFK sample and one CC-BY-4.0 Google FLEURS Vietnamese sample; not a broad accuracy benchmark.'
result['referenceVi']=reference
(root/'whisper/benchmark.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps([{'model':v['model'],'language':v['language'],'RTF':v['realTimeFactor'],'CER':v.get('CER')} for v in result['benchmarks']],indent=2))
