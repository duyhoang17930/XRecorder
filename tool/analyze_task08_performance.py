"""Summarize preserved raw TASK08 frames; writes new evidence only."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import statistics


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def distribution(values):
    ordered = sorted(values)
    if not ordered:
        raise ValueError('Missing raw frame timings')
    return {
        'frames': len(ordered),
        **{f'p{int(p * 100)}Ms': ordered[math.ceil(len(ordered) * p) - 1] / 1000
           for p in [.5, .9, .95, .99]},
        'over16_67Ms': sum(v > 16670 for v in ordered),
        'over33_33Ms': sum(v > 33330 for v in ordered),
        'maxMs': ordered[-1] / 1000,
    }


def summarize(path):
    data = json.loads(path.read_text(encoding='utf8'))
    if data.get('partial') is not False or data.get('profile') is not True:
        raise ValueError('Incomplete or non-profile run is not performance evidence')
    if data.get('warmups') != 3 or len(data['trials']) != 5:
        raise ValueError('Require three warmups and five measured trials')
    trials = []
    for trial in data['trials']:
        trials.append({
            'index': trial['index'],
            **{name: distribution(trial[name + 'Us']) for name in ['build', 'raster', 'totalSpan']},
            **{name: trial[name] for name in ['elapsedUs', 'thumbnailReads', 'cacheBytes',
                                             'decodedCacheEntries', 'decodedCacheBytes', 'scrollOffsetEnd']},
        })
    memory = path.parent / 'memory.jsonl'
    samples = [json.loads(line) for line in memory.read_text().splitlines()] if memory.exists() else []
    return {
        'rawPath': str(path), 'rawSha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'percentileMethod': 'nearest-rank ceil(n*p), microseconds converted to milliseconds',
        'corpusRows': len(data['corpus']), 'corpusMetadataOrderSha256': digest(data['corpus']),
        'viewport': data['viewport'], 'theme': data['theme'], 'locale': data['locale'],
        'nativeItems': data['nativeItems'], 'queries': data['queries'],
        'thumbnailFailures': data['thumbnailFailures'], 'queryMs': data['queryUs'] / 1000,
        'testMountToContentMs': data['testMountToContentUs'] / 1000,
        'coldAndroidLaunchMeasured': data['coldAndroidLaunch'],
        'trials': trials,
        'medianTrialP95Ms': {k: statistics.median(t[k]['p95Ms'] for t in trials) for k in ['build', 'raster', 'totalSpan']},
        'medianDecodedBytes': statistics.median(t['decodedCacheBytes'] for t in trials),
        'medianDecodedEntries': statistics.median(t['decodedCacheEntries'] for t in trials),
        'profilerInclusivePeakPssKiB': max((s['pssKiB'] or 0 for s in samples), default=None),
        'pssIncludesCpuProfileTransfer': True,
        'cpuSampleCount': data['trials'][0]['cpu'].get('sampleCount'),
        'cpuReferencedFunctions': len(data['trials'][0]['cpu'].get('functions', [])),
        'limitations': ['Shared Windows host, SwiftShader, five trials, no physical FPS/thermal certification',
                        'CPU query transfers the VM function table outside measured frame windows; PSS peak includes it'],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before', type=Path, required=True)
    parser.add_argument('--after', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    before = summarize(args.before)
    report = {'before': before}
    if args.after:
        after = summarize(args.after)
        comparable = all(before[k] == after[k] for k in [
            'corpusMetadataOrderSha256', 'viewport', 'theme', 'locale', 'nativeItems'])
        report.update(after=after, comparable=comparable)
        if comparable:
            report['descriptiveChangePercent'] = {
                **{k + 'P95': (after['medianTrialP95Ms'][k] / before['medianTrialP95Ms'][k] - 1) * 100
                   for k in ['build', 'raster', 'totalSpan']},
                'decodedBytes': (after['medianDecodedBytes'] / before['medianDecodedBytes'] - 1) * 100,
                'decodedEntries': (after['medianDecodedEntries'] / before['medianDecodedEntries'] - 1) * 100,
            }
    with args.output.open('x', encoding='utf8') as stream:
        json.dump(report, stream, indent=2)
    print(json.dumps({k: v for k, v in report.items() if k not in ['before', 'after']}))
    print('Before median p95 ms:', before['medianTrialP95Ms'])


if __name__ == '__main__':
    main()
