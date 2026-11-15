"""Summarize retained measurements without replacing existing quality oracles."""
import json
from pathlib import Path

root = Path(__file__).parent
results = {}
for attempt in ['stab4', 'stab_gpu1', 'stab_motion2', 'stab_stress1']:
    path = root.parent / f'live_audio_{attempt}_result.json'
    if not path.exists():
        continue
    runtime = json.loads(path.read_text())
    timeline = runtime.get('audioTimeline', [])
    quality = root.parent / f'live_audio_{attempt}_output_validation.json'
    record = {'workflow': runtime.get('status'), 'error': runtime.get('error'),
              'capture': runtime.get('capture', runtime.get('captureAtFailure')),
              'observations': len(timeline), 'maxima': {}}
    for key in ['highWaterBlocks', 'internalQueuedBlocks', 'maxReadNs', 'maxQueueInputNs',
                'maxDequeueOutputNs', 'maxWriteOutputNs', 'appPssKiB']:
        record['maxima'][key] = max((x.get(key, 0) for x in timeline), default=0)
    if quality.exists():
        value = json.loads(quality.read_text())
        record['quality'] = {key: value.get(key) for key in ['mediaStatus', 'signalGateStatus',
            'packetAndSampledPixelParityStatus', 'relativeAvOffsetMs', 'sourceVideoPreview']}
    results[attempt] = record
(root / 'runtime_summary.json').write_text(json.dumps(results, indent=2))
print(json.dumps({key: {'workflow': value['workflow'], 'maxima': value['maxima'],
                       'quality': value.get('quality', {}).get('mediaStatus')} for key, value in results.items()}, indent=2))
