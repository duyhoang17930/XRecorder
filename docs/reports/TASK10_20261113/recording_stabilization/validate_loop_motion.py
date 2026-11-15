"""Independent oracle for the explicitly looping PCM/frame-ID QA source.

Keep the original non-loop waveform validator unchanged. Its global alignment
can select a later identical loop and then run beyond the captured tail.
This oracle aligns only the first occurrence and checks one fixed sample offset
throughout capture. Threshold .98 is inherited, not relaxed.
"""
import argparse
from array import array
import json
import hashlib
import math
import re
import statistics
from pathlib import Path
import subprocess

p = argparse.ArgumentParser()
p.add_argument('--attempt', required=True)
p.add_argument('--report-suffix', default='speech_anchor')
p.add_argument('--diagnose-drift', action='store_true')
args = p.parse_args()
assert re.fullmatch('[a-z0-9_]+', args.attempt)
assert re.fullmatch('[a-z0-9_]+', args.report_suffix)
root = Path(__file__).parent
parent = root.parent
stem = 'live_audio_' + args.attempt
runtime = json.loads((parent / (stem + '_result.json')).read_text())
assert runtime['sourceLoops'] and runtime['sourcePlayer'] == 'static'
directory = parent / (stem + '_media')
ff = 'build/task03/ffmpeg/ffmpeg.exe'
probe = 'build/task03/ffmpeg/ffprobe.exe'
source = parent / (stem + '_source.pcm')
assert hashlib.sha256(source.read_bytes()).hexdigest() == runtime['sourcePcmSha256']

def pcm(path, rate):
    command = [ff, '-v', 'error']
    if path.suffix == '.pcm':
        command += ['-f', 's16le', '-ar', '16000', '-ac', '1']
    return array('h', subprocess.check_output(command + ['-i', str(path), '-vn',
        '-ac', '1', '-ar', str(rate), '-f', 's16le', '-']))

def correlation(a, b):
    assert len(a) == len(b) and len(a) > 100
    ma, mb = sum(a) / len(a), sum(b) / len(b)
    dot = aa = bb = 0.0
    for x, y in zip(a, b):
        x -= ma
        y -= mb
        dot += x * y
        aa += x * x
        bb += y * y
    return dot / math.sqrt(aa * bb) if aa and bb else 0.0

reference = pcm(source, 48000)
coarse_ref = pcm(source, 2000)
report = {'scope': 'Loop source only; fixed-offset waveform and monotonic visual frame IDs',
          'threshold': .98, 'audio': {}, 'video': {}}
for name in ['local.mp4', 'received.mp4']:
    path = directory / name
    actual = pcm(path, 48000)
    coarse = pcm(path, 2000)
    # First five seconds cannot contain a second 11s source loop.
    # Use a voiced interior anchor for alignment; still evaluate the initial
    # samples below. Silent/weak startup is unsuitable for selecting a lag.
    offset2k = max(range(min(8000, len(coarse) - 6000)),
        key=lambda lag: correlation(coarse_ref[4000:6000:4], coarse[lag + 4000:lag + 6000:4]))
    center = offset2k * 24
    fine = max(range(max(0, center - 576), center + 577, 4),
        key=lambda lag: correlation(reference[96000:115200:3], actual[lag + 96000:lag + 115200:3]))
    offset = max(range(max(0, fine - 3), fine + 4),
        key=lambda lag: correlation(reference[96000:115200], actual[lag + 96000:lag + 115200]))
    windows = []
    for position in range(0, len(actual) - offset - 24000, 48000):
        begin = position % len(reference)
        expected = (reference + reference)[begin:begin + 24000]
        value = correlation(expected, actual[offset + position:offset + position + 24000])
        windows.append({'sourceSeconds': position / 48000, 'correlation': value})
    report['audio'][name] = {'offsetSamples': offset, 'offsetMs': offset / 48,
        'decodedSamples': len(actual), 'referenceLoopSamples': len(reference),
        'windows': windows, 'minimumCorrelation': min(x['correlation'] for x in windows),
        'status': 'PASS' if all(x['correlation'] >= .98 for x in windows) else 'FAIL'}
    if args.diagnose_drift:
        diagnostic = []
        for second in [2, 75, 78, 79, 80, 120, 180, 240, 299]:
            pos = second * 48000
            if offset + pos + 19200 >= len(actual):
                continue
            coarse_start = (second * 2000) % len(coarse_ref)
            ref2k = (coarse_ref + coarse_ref)[coarse_start:coarse_start + 800:2]
            center2k = offset // 24
            lag2k = max(range(max(0, center2k - 400), center2k + 401),
                key=lambda lag: correlation(ref2k, coarse[second * 2000 + lag:second * 2000 + lag + 800:2]))
            begin = pos % len(reference)
            ref48k = (reference + reference)[begin:begin + 19200]
            lag = max(range(max(0, lag2k * 24 - 24), lag2k * 24 + 25),
                key=lambda lag: correlation(ref48k[::3], actual[pos + lag:pos + lag + 19200:3]))
            diagnostic.append({'sourceSeconds': second,
                'bestCorrelation': correlation(ref48k, actual[pos + lag:pos + lag + 19200]),
                'deltaFromFixedMs': (lag - offset) / 48})
        report['audio'][name]['driftDiagnosticOnly'] = diagnostic

path = directory / 'local.mp4'
frames = json.loads(subprocess.check_output([probe, '-v', 'error', '-select_streams', 'v:0',
    '-show_frames', '-show_entries', 'frame=best_effort_timestamp_time', '-of', 'json', str(path)]))['frames']
top = round(runtime.get('visualSourceTopPixels', 0) * 1280 / 2400)
raw = subprocess.check_output([ff, '-v', 'error', '-i', str(path), '-vf',
    f'crop=274:137:72:{top},scale=8:4:flags=neighbor', '-vsync', '0', '-pix_fmt', 'rgb24', '-f', 'rawvideo', '-'])
assert len(raw) == len(frames) * 96
video_origin = runtime['initialAudioTiming']['videoSourceStartNs']
visual_origin = runtime['visualSourceOriginNs']
mask = 65535 if top else 0xffc7  # Old marker was partly covered by Android's chip.
observed = []
bad = []
ages_ms = []
visual_end = (runtime['audioTimeline'][-1]['monotonicNs'] - visual_origin) / 1e9
for index, frame in enumerate(frames):
    pts = float(frame['best_effort_timestamp_time'])
    expected = (video_origin - visual_origin) / 1e9 + pts
    if expected < .5 or expected > visual_end - .5:
        continue
    pixels = raw[index * 96:(index + 1) * 96]
    value = sum((1 << bit) for bit in range(16) if sum(pixels[bit * 3:bit * 3 + 3]) > 540)
    wanted = int(expected * 30)
    # At most 1s presentation lag is allowed; this does not certify 30fps.
    candidates = [n for n in range(max(0, wanted - 30), wanted + 4) if n & mask == value & mask]
    observed.append({'pts': pts, 'decodedIdMasked': value & mask, 'expectedId': wanted})
    if not candidates:
        bad.append(observed[-1])
    elif mask == 65535:
        ages_ms.append(expected * 1000 - value * 1000 / 30)
report['video'] = {'checkedFrames': len(observed), 'uniqueIds': len({x['decodedIdMasked'] for x in observed}),
    'mismatches': bad, 'mask': mask, 'status': 'PASS' if len(observed) > 10 and not bad else 'FAIL',
    'scope': 'Known 720x1280 canvas, 1080x2400 display; no source ID older than 1s; not an FPS certificate'}
if ages_ms:
    report['video']['frameAgeMs'] = {'min': min(ages_ms), 'median': statistics.median(ages_ms), 'max': max(ages_ms)}
report['status'] = 'PASS' if all(x['status'] == 'PASS' for x in report['audio'].values()) and report['video']['status'] == 'PASS' else 'FAIL'
with (root / (args.attempt + '_loop_motion_' + args.report_suffix + '.json')).open('x') as stream:
    json.dump(report, stream, indent=2)
print(json.dumps({'status': report['status'], 'audio': {k: {'status': v['status'],
    'minimumCorrelation': v['minimumCorrelation']} for k, v in report['audio'].items()}, 'video': report['video']}))
assert report['status'] == 'PASS'
