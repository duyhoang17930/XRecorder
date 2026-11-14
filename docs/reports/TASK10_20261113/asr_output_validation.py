"""Independent ASR/SRT/burn-in proof using the existing FFmpeg validator outputs.

Preserves the initial zero-lag audio failure and measures AAC priming explicitly.
No oracle requires exact PCM after an Android AAC transcode.
"""
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).parent
FF = 'build/task03/ffmpeg/ffmpeg.exe'
source = ROOT / 'TASK10_asr_jfk_mpeg4.mp4'
output = ROOT / 'asr_burnin_media/task10_asr_burnin.mp4'


def frame(path, seconds, filters=None):
    command = [FF, '-v', 'error', '-ss', str(seconds), '-i', str(path)]
    if filters:
        command += ['-vf', filters]
    return subprocess.check_output(command + [
        '-frames:v', '1', '-pix_fmt', 'rgb24', '-f', 'rawvideo', '-'])


def bright(raw):
    points = []
    for offset in range(0, len(raw), 3):
        pixel = raw[offset:offset + 3]
        if min(pixel) > 130 and max(pixel) - min(pixel) < 35:
            points.append((offset // 3 % 320, offset // 3 // 320))
    if not points:
        return {'pixels': 0}
    return {'pixels': len(points), 'bounds': [
        min(x for x, y in points), min(y for x, y in points),
        max(x for x, y in points), max(y for x, y in points)]}


decoded = json.loads((ROOT / 'asr_burnin_media/validation.json').read_text())['results']
assert len(decoded) == 1 and decoded[0]['fullDecode'] == 'PASS'
assert decoded[0]['decodedVideoFrames'] == 264 and decoded[0]['audioRms'] > .1
frames = {t: frame(output, t) for t in [0, 2, 5.4, 5.6, 8, 10.9]}
samples = {str(t): bright(raw) for t, raw in frames.items()}
assert all(s['pixels'] > 100 and s['bounds'][1] >= 120 and
           s['bounds'][3] < 180 and s['bounds'][0] >= 10 and
           s['bounds'][2] < 310 for s in samples.values()), samples
assert bright(frame(source, 0))['pixels'] == 0
assert frames[2] != frames[8], 'Cue pixels must change at the 5.5s boundary'
preview = frame(ROOT / 'asr_burnin_preview_first_frame.png', 0,
                'crop=1017:572:31:410,scale=320:180')
assert len(preview) == len(frames[0])
mae = sum(abs(a - b) for a, b in zip(preview, frames[0])) / len(preview)
assert mae < 8, mae
alignment = json.loads((ROOT / 'asr_audio_alignment_diagnostic.json').read_text())
# Explicit <=50ms sample alignment bound, below one 64ms AAC frame at16kHz.
# This is measured output behavior, not physical-device A/V certification.
assert abs(alignment['bestOffsetMs']) <= 50 and alignment['best'][0] > .99
srt = (ROOT / 'asr_actual_split.srt').read_text(encoding='utf8')
expected = ('1\n00:00:00,000 --> 00:00:05,500\n'
            'And so my fellow Americans ask not what your country can\n\n'
            '2\n00:00:05,500 --> 00:00:11,000\n'
            'do for you, ask what you can do for your country.\n')
assert srt == expected
jobs = json.loads((ROOT / 'asr_3gb_first_jobs.json').read_text())
job = next(j for j in jobs if j['id'] == 'speech_1794600711119887')
assert job['state'] == 'completed' and job['detectedLanguage'] == 'en'
assert 'what your country can do for you' in job['segments'][0]['text']
result = {
    'status': 'PASS', 'scope': 'Tiny auto-English -> review/split -> SRT -> MP4 burn-in',
    'projectId': job['projectId'], 'speechJob': job['id'],
    'inferenceMs': job['inferenceMs'], 'modelLoadMs': job['modelLoadMs'],
    'elapsedMs': job['elapsedMs'], 'memoryPreflight': job['memoryPreflight'],
    'srtSha256': hashlib.sha256((ROOT / 'asr_actual_split.srt').read_bytes()).hexdigest(),
    'mediaUri': 'content://media/external/video/media/115',
    'mediaBytes': output.stat().st_size,
    'mediaSha256': hashlib.sha256(output.read_bytes()).hexdigest(),
    'frames': 264, 'duration': 11.036, 'subtitlePixelSamples': samples,
    'previewExportRgbMAE': mae, 'audioAlignment': alignment,
    'originalFixtureSha256': hashlib.sha256(source.read_bytes()).hexdigest(),
}
with (ROOT / 'asr_e2e_validation.json').open('x') as stream:
    json.dump(result, stream, indent=2)
print(json.dumps(result, indent=2))
