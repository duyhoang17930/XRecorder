"""Independent FFmpeg pixel oracle; includes every frame, especially frame zero."""
import argparse
import json
from pathlib import Path
import subprocess

import device_qa as q

parser = argparse.ArgumentParser()
parser.add_argument('--attempt', required=True)
parser.add_argument('--cases', nargs='+', required=True)
parser.add_argument('--report-suffix', default='')
args = parser.parse_args()
q.identity()
ff = str(Path('build/task03/ffmpeg/ffmpeg.exe'))
probe = str(Path(ff).with_name('ffprobe.exe'))
reports = []


def raw_frame(path, filters):
    return subprocess.check_output([ff, '-v', 'error', '-i', str(path), '-vf', filters,
                                    '-frames:v', '1', '-pix_fmt', 'rgb24', '-f', 'rawvideo', '-'])


for case in args.cases:
    stem = 'r4_' + args.attempt + '_' + case.replace('-', '_')
    item = json.loads((q.ROOT / (stem + '.json')).read_text())
    assert item['status'] == 'PASS'
    assert item['source'].startswith('/data/user/0/' + q.PACKAGE + '/files/task10_r4_')
    video = q.ROOT / (stem + '.mp4')
    source = q.ROOT / (stem + '_source.png')
    for path, data in [(video, q.adb('exec-out', 'content', 'read', '--uri', item['uri'])),
                       (source, q.adb('exec-out', 'run-as', q.PACKAGE, 'cat', item['source']))]:
        if path.exists():
            assert path.read_bytes() == data
        else:
            with path.open('xb') as stream:
                stream.write(data)
    info = json.loads(subprocess.check_output([probe, '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(video)]))
    stream = info['streams'][0]
    assert len(info['streams']) == 1 and (stream['width'], stream['height']) == (item['width'], item['height'])
    result = subprocess.run([ff, '-v', 'error', '-xerror', '-i', str(video), '-fps_mode', 'passthrough',
                             '-enc_time_base', '-1', '-f', 'null', '-'], capture_output=True)
    assert result.returncode == 0 and not result.stderr, result.stderr
    x, y, w, h = (item[k] for k in ['cropX', 'cropY', 'width', 'height'])
    expected = raw_frame(source, f'crop={w}:{h}:{x}:{y}')
    wrong_x = (x + item['sourceWidth'] // 2) % item['sourceWidth']
    wrong_y = (y + item['sourceHeight'] // 2) % item['sourceHeight']
    wrong = raw_frame(source, f'crop={w}:{h}:{wrong_x}:{wrong_y}')
    decoded = subprocess.check_output([ff, '-v', 'error', '-i', str(video), '-fps_mode', 'passthrough',
                                       '-enc_time_base', '-1', '-pix_fmt', 'rgb24', '-f', 'rawvideo', '-'])
    frame_size = w * h * 3
    assert len(decoded) >= frame_size and len(decoded) % frame_size == 0
    errors, wrong_errors = [], []
    for offset in range(0, len(decoded), frame_size):
        frame = decoded[offset:offset + frame_size]
        errors.append(sum(abs(a - b) for a, b in zip(frame, expected)) / frame_size)
        wrong_errors.append(sum(abs(a - b) for a, b in zip(frame, wrong)) / frame_size)
    reports.append({'case': case, 'uri': item['uri'], 'fullDecode': 'PASS', 'frames': len(errors),
                    'firstFrameError': errors[0], 'maximumFrameError': max(errors),
                    'minimumWrongOriginError': min(wrong_errors), 'allFrameErrors': errors,
                    'status': 'PASS' if max(errors) < 20 and min(wrong_errors) > 40 else 'FAIL'})
with (q.ROOT / ('r4_' + args.attempt + args.report_suffix + '_pixel_validation.json')).open('x') as output:
    json.dump(reports, output, indent=2)
print(json.dumps(reports))
assert all(row['status'] == 'PASS' for row in reports), 'Region pixel mismatch; failed media retained'
