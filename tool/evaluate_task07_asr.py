"""Script-aware, single-utterance ASR observations; never a global quality verdict."""
import argparse
import json
import statistics
import unicodedata
from pathlib import Path

if __package__:
    from .asr_metrics import distance
else:
    from asr_metrics import distance

def normalize(text):
    # Retain letters, marks and digits: Hindi matras/virama and VI accents matter.
    text=unicodedata.normalize('NFKC',text).casefold()
    return ' '.join(''.join(c if unicodedata.category(c)[0] in 'LMN' or c.isspace() else ' ' for c in text).split())


def evaluate(corpus,report_path,memory_path):
    report=json.loads(report_path.read_text(encoding='utf8'))
    if report.get('partial') is not False:raise ValueError('Incomplete native run; retain raw evidence and do not report PASS')
    references={path.stem.split('_')[0]:json.loads(path.read_text(encoding='utf8')) for path in corpus.glob('*_source.json')}
    specs=json.loads((corpus/'task07_asr_manifest.json').read_text(encoding='utf8'))
    memory=[json.loads(line) for line in memory_path.read_text(encoding='utf8').splitlines()] if memory_path else []
    rows=[]
    for result in report['benchmarks']:
        if '\ufffd' in result['transcript'] or any(0xd800<=ord(c)<=0xdfff for c in result['transcript']):
            raise ValueError('Native transcript contains invalid/replaced Unicode; inspect raw output')
        spec=next(s for s in specs if s['file']==result['file'] and s['language']==result['language'])
        code=spec['referenceLanguage']; reference=references[code]['reference'] if code else ''
        actual=normalize(result['transcript']);ref=normalize(reference)
        characters=lambda value:''.join(value.split())
        samples=[row['pssKiB'] for row in memory if result['startedAtMs']<=row['hostUtcMs']<=result['finishedAtMs']]
        rows.append({**result,'reference':reference,'durationMs':spec['durationMs'],
          'CER':distance(characters(ref),characters(actual))/len(characters(ref)) if ref else None,
          'WER':distance(ref.split(),actual.split())/len(ref.split()) if ref and code not in ('ja','zh') else None,
          'autoLanguageMatches':result.get('detectedLanguage')==code if result['language']=='auto' and code else None,
          'falsePositiveText':bool(actual) if not code else None,'emptyTranscript':not bool(actual),
          'RTF':result['elapsedMs']/spec['durationMs'],'sampledPeakPssKiB':max(samples) if samples else None})
    models=[]
    model_names=sorted({row['model'] for row in rows})
    shared=set.intersection(*[{row['file'] for row in rows if row['model']==model and row['condition']=='real_speech'} for model in model_names])
    comparisons=[]
    for model in sorted({row['model'] for row in rows}):
        selected=[r for r in rows if r['model']==model and r['condition']=='real_speech']
        models.append({'model':model,'fixedLanguageUtterances':len(selected),
          'medianRTF':statistics.median(r['RTF'] for r in selected),
          'maximumSampledPssKiB':max((r['sampledPeakPssKiB'] or 0 for r in selected),default=0)})
        common=[row for row in selected if row['file'] in shared]
        comparisons.append({'model':model,'sameUtteranceFiles':sorted(shared),'count':len(common),
          'medianRTF':statistics.median(row['RTF'] for row in common),
          'sampledPeakPssKiB':max((row['sampledPeakPssKiB'] or 0 for row in common),default=0)})
    return {'rows':rows,'models':models,'sharedSubsetComparison':comparisons,'nativeJobRuns':len(rows),
      'engineCatalogVerified':report['engineCatalogVerified'],'cancelDrainMs':report.get('cancelDrainMs'),
      'maximumJobListMs':report['maximumJobListMs'],
      'normalization':'NFKC + casefold; retain Unicode letters/marks/numbers; punctuation to spaces. CER counts code points excluding spaces. Arabic diacritics are retained; no unreported transliteration.',
      'tokenization':'Whitespace WER for non-JA/ZH; no invented CJK word tokenizer. JA/ZH WER null, use CER. Do not compare error rates as a cross-script ranking.',
      'memoryScope':'2-second sampled PSS, host/device UTC timestamps; approximate boundaries, not exact allocation peaks. Physical/thermal behavior not measured.',
      'qualityScope':'One real FLEURS utterance per language; subset-only Tiny/Small. These observations do not certify overall ASR quality, all 99 languages, noise robustness or auto-detection accuracy.'}


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--corpus',type=Path,required=True)
    parser.add_argument('--report',type=Path,required=True);parser.add_argument('--memory',type=Path)
    parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    results=evaluate(args.corpus,args.report,args.memory)
    args.output.write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print('Evaluated',results['nativeJobRuns'],'native jobs; single-utterance observations, not global ASR PASS.')
