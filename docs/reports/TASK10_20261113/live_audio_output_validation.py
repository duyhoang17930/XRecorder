"""Decode and identify speech in real screen-capture output, without new deps.

The capture harness result stays independent: a cleanup-stop file cannot turn a
failed End-button workflow into PASS. Media evidence is reported separately.
"""
import argparse
from array import array
import hashlib
import json
import math
from pathlib import Path
import re
import statistics
import subprocess

ROOT = Path(__file__).parent
FF = 'build/task03/ffmpeg/ffmpeg.exe'
PROBE = 'build/task03/ffmpeg/ffprobe.exe'
p = argparse.ArgumentParser()
p.add_argument('--attempt', required=True)
p.add_argument('--report-suffix', default='')
p.add_argument('--window-diagnostic-only', action='store_true',
               help='Measure local alignment changes; diagnostic only, never an acceptance verdict')
args = p.parse_args()
assert re.fullmatch('[a-z0-9_]*', args.report_suffix)
stem = 'live_audio_' + args.attempt
directory = ROOT / (stem + '_media')
runtime = json.loads((ROOT / (stem + '_result.json')).read_text())
source = ROOT / 'asr_burnin_media/task10_asr_burnin.mp4'
assert hashlib.sha256(source.read_bytes()).hexdigest() == '8925ac2f0764e8bcdbcf1b70f5f28b373b4653f7a7aa0c8b163ebfa00001c34f'
if runtime.get('sourcePlayer') == 'static':
    source = ROOT / (stem + '_source.pcm')
    assert source.stat().st_size == runtime['sourcePcmBytes']
    assert hashlib.sha256(source.read_bytes()).hexdigest() == runtime['sourcePcmSha256']
decoded = json.loads((directory / 'validation.json').read_text())['results']
assert len(decoded) == 2 and all(x['fullDecode'] == 'PASS' for x in decoded)
assert all(x['audioRms'] > .01 for x in decoded), decoded


def pcm(path, rate=2000):
    command = [FF, '-v', 'error']
    if path.suffix == '.pcm':
        command += ['-f', 's16le', '-ar', str(runtime['sourcePcmRate']), '-ac', '1']
    raw = subprocess.check_output(command + ['-i', str(path),
        '-vn', '-ac', '1', '-ar', str(rate), '-f', 'f32le', '-'])
    values = array('f', raw)
    assert values and all(math.isfinite(x) for x in values)
    return values


def correlate(reference, captured, offset, start, length, stride=1):
    ref = reference[start:start + length:stride]
    actual = captured[start + offset:start + offset + length:stride]
    assert len(ref) == len(actual) and len(ref) > 100
    # Both paths are decoded/resampled by FFmpeg. Pearson correlation permits
    # normal gain and DC differences; it does not permit rearranging samples.
    mr, ma = statistics.fmean(ref), statistics.fmean(actual)
    rr = aa = ra = 0.0
    for r, a in zip(ref, actual):
        r -= mr
        a -= ma
        rr += r * r
        aa += a * a
        ra += r * a
    return ra / math.sqrt(rr * aa) if rr and aa else 0.0


reference = pcm(source)
native_reference = pcm(source, 48000)
if args.window_diagnostic_only:
    # Keep the original constant-offset continuity verdict intact. This locates
    # actual clock steps rather than attributing every mismatch to dropped PCM.
    previous = json.loads((ROOT / (stem + '_output_validation.json')).read_text())
    diagnostic = {'scope': 'Diagnostic only; original continuity gate unchanged', 'files': {}}
    for name in ['local.mp4', 'received.mp4']:
        captured, native = pcm(directory / name), pcm(directory / name, 48000)
        base = round(previous['speech'][name]['offsetMs'] * 2)
        windows = []
        for half_second in range(15):
            start = half_second * 1000
            coarse_score, coarse = max(
                (correlate(reference, captured, i, start, 800), i)
                for i in range(max(0, base-300), min(len(captured)-start-800, base+301)))
            score, fine = max(
                (correlate(native_reference, native, i, start*24, 19200, 3), i)
                for i in range(max(0, coarse*24-576), min(len(native)-start*24-19200, coarse*24+577), 4))
            score, offset = max(
                (correlate(native_reference, native, i, start*24, 19200), i)
                for i in range(max(0, fine-3), min(len(native)-start*24-19200, fine+4)))
            windows.append({'sourceSeconds': half_second/2, 'correlation': score,
                            'offsetMs': offset/48})
        diagnostic['files'][name] = windows
    with (ROOT / (stem + '_window_alignment_diagnostic.json')).open('x') as out:
        json.dump(diagnostic, out, indent=2)
    print(json.dumps(diagnostic, indent=2))
    raise SystemExit(0)
speech = {}
signal_failures = []
for name in ['local.mp4', 'received.mp4']:
    captured = pcm(directory / name)
    # Search ALL possible nonnegative offsets, not only the expected timer.
    # A 10ms coarse step on the envelope avoids missing waveform phase peaks.
    envelope_ref = [math.sqrt(sum(x*x for x in reference[i:i+20]) / 20)
                    for i in range(0, 10000, 20)]
    envelope_capture = [math.sqrt(sum(x*x for x in captured[i:i+20]) / 20)
                        for i in range(0, len(captured)-19, 20)]
    def envelope_score(lag):
        a = envelope_ref
        b = envelope_capture[lag:lag + len(a)]
        ma, mb = statistics.fmean(a), statistics.fmean(b)
        aa = sum((x-ma)**2 for x in a)
        bb = sum((x-mb)**2 for x in b)
        return sum((x-ma)*(y-mb) for x, y in zip(a, b)) / math.sqrt(aa*bb) if bb else 0
    candidate = max(range(len(envelope_capture) - len(envelope_ref)), key=envelope_score) * 20
    best = max(((correlate(reference, captured, offset, 0, 10000), offset)
                for offset in range(max(0, candidate-40), min(len(captured)-10000, candidate+41))),
               key=lambda x: x[0])
    correlation, offset = best
    windows = [correlate(reference, captured, offset, s, 2000) for s in [1000, 5000, 9000]]
    coarse = {'offsetMs': offset/2, 'first5sCorrelation': correlation,
              'fixedOffsetWindowCorrelations': windows}
    native = pcm(directory / name, 48000)
    # Refine waveform phase on the native sample grid, with a wide enough
    # neighborhood to reject a neighboring pitch peak from the coarse grid.
    fine = max((correlate(native_reference, native, i, 0, 240000), i)
               for i in range(max(0, offset*24-480), min(len(native)-240000, offset*24+481), 4))
    correlation, offset_native = max((correlate(native_reference, native, i, 0, 240000), i)
               for i in range(max(0, fine[1]-3), min(len(native)-240000, fine[1]+4)))
    windows = [correlate(native_reference, native, offset_native, s, 48000)
               for s in [24000, 120000, 216000]]
    speech[name] = {'offsetMs': offset_native / 48, 'first5sCorrelation': correlation,
                    'fixedOffsetWindowCorrelations': windows,
                    'alignmentSampleRate': 48000, 'coarse2kHzDiagnostic': coarse,
                    'decodedSamplesAt2kHz': len(captured),
                    'sha256': hashlib.sha256((directory / name).read_bytes()).hexdigest()}
    if correlation <= .90 or min(windows) <= .85:
        signal_failures.append(name)


def packets(path, stream):
    return json.loads(subprocess.check_output([PROBE, '-v', 'error', '-select_streams', stream,
        '-show_packets', '-show_data_hash', 'sha256', '-show_entries',
        'packet=pts_time,data_hash,size', '-of', 'json', str(path)]))['packets']


alignment = {}
for stream in ['v:0', 'a:0']:
    local = packets(directory / 'local.mp4', stream)
    received = packets(directory / 'received.mp4', stream)
    rh = [x['data_hash'] for x in received]
    lh = [x['data_hash'] for x in local]
    starts = [i for i in range(len(local)-len(received)+1) if lh[i:i+len(rh)] == rh]
    assert len(starts) == 1, (stream, len(local), len(received), starts)
    start = starts[0]
    offsets = [float(local[start+i]['pts_time'])-float(packet['pts_time'])
               for i, packet in enumerate(received)]
    alignment[stream] = {'localPackets': len(local), 'receivedPackets': len(received),
        'contiguousStart': start, 'everyPacketSha256Exact': True,
        'medianTimestampOffsetSeconds': statistics.median(offsets),
        'timestampOffsetRangeSeconds': [min(offsets), max(offsets)]}
av_offset = abs(alignment['v:0']['medianTimestampOffsetSeconds'] -
                alignment['a:0']['medianTimestampOffsetSeconds']) * 1000
assert av_offset < 2, av_offset


def frame(path, index):
    return subprocess.check_output([FF, '-v', 'error', '-i', str(path), '-vf',
        'select=eq(n\\,%d)' % index, '-frames:v', '1', '-pix_fmt', 'rgb24', '-f', 'rawvideo', '-'])


count = alignment['v:0']['receivedPackets']
samples = sorted(set([0, 1, count//4, count//2, count*3//4, count-1]))
for index in samples:
    network = frame(directory / 'received.mp4', index)
    assert len(network) == 720*1280*3
    assert network == frame(directory / 'local.mp4', index + alignment['v:0']['contiguousStart'])
    assert max(network) > 150 and statistics.fmean(network) > 10, 'Unexpected black frame'

source_picture = {'status': 'NOT_APPLICABLE', 'scope': 'Static source does not exercise VideoView'}
if runtime.get('sourcePlayer', 'video') == 'video':
    # The immutable115 export changes its caption at5.5s. A progressing player
    # clock alone does not prove the visible video advanced. Reuse the existing
    # ASR bright-glyph oracle, independent of the player's clock and color-range
    # shifts. Geometry is the verified Pixel_7 portrait720x1280 capture context.
    def picture(path, seconds, filters=None):
        command = [FF, '-v', 'error', '-ss', str(seconds), '-i', str(path)]
        if filters:
            command += ['-vf', filters]
        return subprocess.check_output(command + ['-frames:v', '1', '-pix_fmt', 'rgb24', '-f', 'rawvideo', '-'])
    def glyphs(raw):
        assert len(raw) == 320*180*3
        return {i//3 for i in range(0, len(raw), 3)
                if min(raw[i:i+3]) > 130 and max(raw[i:i+3])-min(raw[i:i+3]) < 35}
    def dice(a, b):
        return 2*len(a & b)/(len(a)+len(b)) if a or b else 0
    first, second = glyphs(picture(source, 2)), glyphs(picture(source, 8))
    assert first and second and first != second
    cue_samples = []
    assert runtime['playback']['positionMs'] >= 7000, 'Cue oracle needs at least7s actually played'
    video_epoch = runtime['initialAudioTiming'].get('videoSourceStartNs', 0)
    for source_seconds in [6, 7]:
        if video_epoch > 0:
            # Use the real encoded-video origin, not the later UI recording
            # notification. Both clocks are Android CLOCK_MONOTONIC.
            capture_seconds = (runtime['playbackStartMonotonicNs']-video_epoch)/1e9 + source_seconds-runtime['initialPlayback']['positionMs']/1000
        else:
            capture_seconds = runtime['playbackStartCaptureMs']/1000 + source_seconds - runtime['initialPlayback']['positionMs']/1000
        actual = glyphs(picture(directory / 'local.mp4', capture_seconds, 'crop=576:324:72:478,scale=320:180'))
        wrong, expected = dice(actual, first), dice(actual, second)
        cue_samples.append({'expectedSourceSeconds': source_seconds, 'captureSeconds': capture_seconds,
                            'firstCueDice': wrong, 'secondCueDice': expected,
                            'correctCue': expected > .7 and expected > wrong+.1})
    source_picture = {'status': 'PASS' if all(x['correctCue'] for x in cue_samples) else 'FAIL',
                      'samples': cue_samples, 'encodedVideoOriginUsed': video_epoch > 0,
                      'scope': 'Known115 cue2 after5.5s, within actual played interval; not all-motion/player acceptance'}

result = {'mediaStatus': 'FAIL' if signal_failures else 'PASS', 'workflowStatus': runtime['status'],
    'sourcePlayer': runtime.get('sourcePlayer', 'video'),
    'scope': 'Real Mixed capture while task115 plays; identified speech + full decodes + local/network packet and sampled pixel parity. Physical microphone quality is not tested.',
    'sessionId': runtime['sessionId'], 'uri': (runtime.get('capture') or runtime['cleanupCapture'])['outputUri'],
    'nativeEndWorkflowPassed': runtime['status'] == 'PASS', 'speech': speech,
    'signalGateStatus': 'FAIL' if signal_failures else 'PASS', 'signalFailures': signal_failures,
    'packetAndSampledPixelParityStatus': 'PASS',
    'packetAlignment': alignment, 'relativeAvOffsetMs': av_offset,
    'rgbByteExactReceivedFrameSamples': samples,
    'sourceVideoPreview': source_picture,
    'decodeEvidence': stem + '_media/validation.json'}
if source_picture['status'] == 'FAIL':
    result['mediaStatus'] = 'FAIL'
suffix = '_' + args.report_suffix if args.report_suffix else ''
with (ROOT / (stem + suffix + '_output_validation.json')).open('x') as out:
    json.dump(result, out, indent=2)
print(json.dumps(result, indent=2))
assert not signal_failures, 'Original strict speech continuity gate failed: ' + repr(signal_failures)
assert source_picture['status'] != 'FAIL', 'Source player retained the wrong caption despite an advancing clock'
