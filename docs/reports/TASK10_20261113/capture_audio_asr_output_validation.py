"""Independent output checks for recording154 -> main editor -> Tiny -> burn-in.

This checks export fidelity to the recording, not the still-failing recording
waveform fidelity to the original playback source115.
"""
from array import array
import hashlib
import json
import math
from pathlib import Path
import statistics
import subprocess

ROOT = Path(__file__).parent
FF = 'build/task03/ffmpeg/ffmpeg.exe'
source = ROOT / 'live_audio_audio8_media/local.mp4'
output = ROOT / 'capture_audio_asr_export_media/recording_subtitles.mp4'
assert hashlib.sha256(source.read_bytes()).hexdigest() == 'f2d15a2ed548f81f8899793bca63b743f3f67fbeb4a5b656914926f4aa98e527'
decoded = json.loads((output.parent / 'validation.json').read_text())['results'][0]
assert decoded['fullDecode'] == 'PASS' and decoded['decodedVideoFrames'] == 152
video = next(s for s in decoded['streams'] if s['codec_type'] == 'video')
assert (video['width'], video['height']) == (1280, 720)
assert any(abs(s.get('rotation', 0)) == 90 for s in video.get('side_data_list', []))
assert abs(float(decoded['format']['duration']) - 16.886) < .1


def frame(path, seconds):
    raw = subprocess.check_output([FF, '-v', 'error', '-ss', str(seconds), '-i', str(path),
        '-frames:v', '1', '-pix_fmt', 'rgb24', '-f', 'rawvideo', '-'])
    assert len(raw) == 720*1280*3  # Includes declared display rotation.
    return raw


pixels = []
for seconds in [1, 3, 6, 11.5, 12.5, 16]:
    a, b = frame(source, seconds), frame(output, seconds)
    difference = []
    additional_white = 0
    for y in range(1280*15//100, 1280*75//100):
        for x in range(720*5//100, 720*95//100):
            i = (y*720+x)*3
            difference.extend(abs(a[i+c]-b[i+c]) for c in range(3))
    mae = statistics.fmean(difference)
    for y in range(1280*79//100, 1280*94//100):
        for x in range(720*6//100, 720*94//100):
            i = (y*720+x)*3
            if min(b[i:i+3]) > 170 and max(b[i:i+3])-min(b[i:i+3]) < 35 and max(a[i:i+3]) < 100:
                additional_white += 1
    pixels.append({'seconds': seconds, 'unannotatedRegionMae': mae,
                   'additionalNeutralBrightCaptionPixels': additional_white})
    assert mae < 8, pixels[-1]
    assert additional_white > 5000 if seconds < 12 else additional_white < 1500, pixels[-1]


def pcm(path, rate=2000):
    return array('f', subprocess.check_output([FF, '-v', 'error', '-i', str(path),
        '-vn', '-ac', '1', '-ar', str(rate), '-f', 'f32le', '-']))


ref, actual = pcm(source), pcm(output)
ref = ref[2000:30000]  #1..15s includes actual captured voice and quiet regions.
mean = statistics.fmean(ref)
centered = [x-mean for x in ref]
energy = sum(x*x for x in centered)
scores = []
for lag in range(-200, 201):  # Explicit bounded +/-100ms AAC priming search.
    values = actual[2000+lag:30000+lag]
    assert len(values) == len(ref)
    other_mean = statistics.fmean(values)
    other_energy = sum((x-other_mean)**2 for x in values)
    corr = sum(x*(y-other_mean) for x, y in zip(centered, values)) / math.sqrt(energy*other_energy)
    scores.append((corr, lag))
coarse_correlation, coarse_lag = max(scores)
# A half-millisecond2kHz grid is too coarse for AAC waveform comparison.
# Preserve that failed raw run, then refine at the native48kHz sample rate.
ref, actual = pcm(source, 48000)[48000:720000], pcm(output, 48000)
mean = statistics.fmean(ref)
centered = [x-mean for x in ref]
energy = sum(x*x for x in centered)
scores = []
for offset in range(coarse_lag*24-20, coarse_lag*24+21):
    values = actual[48000+offset:720000+offset]
    other_mean = statistics.fmean(values)
    other_energy = sum(x*x for x in values)-len(values)*other_mean*other_mean
    scores.append((sum(x*y for x, y in zip(centered, values))/math.sqrt(energy*other_energy), offset))
correlation, lag = max(scores)
assert correlation > .98, (correlation, lag)

result = {'status': 'PASS', 'scope': 'main recording154 -> Library -> Editor -> Tiny -> reviewed/applied cue -> MP4 -> Gallery/native player; export parity to recording, not capture-quality acceptance',
    'sourceUri': 'content://media/external/video/media/154',
    'outputUri': 'content://media/external/video/media/155',
    'bytes': output.stat().st_size, 'sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
    'displaySize': [720, 1280], 'codedSize': [1280, 720], 'rotationDegrees': -90,
    'durationSeconds': float(decoded['format']['duration']), 'decodedFrames': 152,
    'subtitleCueMs': [0, 12000], 'pixelChecks': pixels,
    'recordingToExportAudioCorrelation': correlation, 'aacAlignmentMs': lag/48,
    'alignmentSampleRate': 48000, 'coarse2kHzCorrelation': coarse_correlation,
    'sourceRecordingQualityGate': 'FAIL remains in live_audio_audio8_output_validation.json'}
with (ROOT / 'capture_audio_asr_output_validation.json').open('x') as out:
    json.dump(result, out, indent=2)
print(json.dumps(result, indent=2))
