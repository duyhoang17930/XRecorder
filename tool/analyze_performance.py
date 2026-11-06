"""Summarize Task 03 raw measurements; no device mutations or media deletion."""
import collections
import json
import math
import pathlib
import re
import statistics
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / 'build/verification/performance/task03'
SCRATCH = ROOT / '.claude-local/scratchpad/task03'


def summary(values):
    values = sorted(values)
    return {'n': len(values), 'median': round(statistics.median(values), 3),
            'p95': round(values[math.ceil(len(values) * .95) - 1], 3),
            'min': round(values[0], 3), 'max': round(values[-1], 3)} if values else None


def inspect_outputs(phase, data):
    folder = SCRATCH / phase / 'outputs'
    ffdir = ROOT / 'build/task03/ffmpeg'
    result = []
    assert collections.Counter(o['kind'] for o in data['outputs']) == {'video': 3, 'export': 3, 'screenshot': 3}
    for output in data['outputs']:
        path = folder / output['name']
        assert path.is_file() and path.stat().st_size == output['bytes'], path
        if path.suffix != '.mp4':
            assert path.read_bytes()[:8] == b'\x89PNG\r\n\x1a\n', path
            continue
        args = [str(ffdir / 'ffprobe.exe'), '-v', 'error', '-count_frames', '-show_streams', '-show_format', '-of', 'json', str(path)]
        probe = json.loads(subprocess.check_output(args))
        frames = json.loads(subprocess.check_output([str(ffdir / 'ffprobe.exe'), '-v', 'error', '-select_streams', 'v:0', '-show_frames', '-show_entries', 'frame=best_effort_timestamp_time', '-of', 'json', str(path)]))
        pts = [float(f['best_effort_timestamp_time']) for f in frames['frames'] if 'best_effort_timestamp_time' in f]
        gaps = [(b-a)*1000 for a, b in zip(pts, pts[1:])]
        # Preserve source time base for VFR; default output-rate rounding can
        # create duplicate DTS in the null muxer even when input PTS is valid.
        decode = subprocess.run([str(ffdir / 'ffmpeg.exe'), '-v', 'error', '-i', str(path), '-fps_mode', 'passthrough', '-enc_time_base', '-1', '-f', 'null', '-'], capture_output=True, timeout=300)
        assert decode.returncode == 0 and not decode.stderr.strip(), (path, decode.stderr.decode(errors='replace'))
        result.append({'name': path.name, 'kind': output['kind'], 'probe': probe,
                       'ptsMs': summary(gaps), 'nonIncreasingPts': sum(g <= 0 for g in gaps),
                       'gapsOver50ms': sum(g > 50 for g in gaps), 'decodeErrors': 0})
    (OUT / phase / 'output_validation.json').write_text(json.dumps(result, indent=2), encoding='utf8')
    return [{k: v for k, v in item.items() if k != 'probe'} | {
        'streams': [{k: s.get(k) for k in ['codec_type', 'codec_name', 'width', 'height', 'avg_frame_rate', 'nb_read_frames', 'duration']} for s in item['probe']['streams']]
    } for item in result]


def summarize_phase(phase):
    data = json.loads((OUT / phase / 'emulator_verification.json').read_text())['performance03']
    assert data['mode'] == 'profile' and data['iterations'] == 3
    groups = collections.defaultdict(list)
    for sample in data['samples']:
        groups[sample['name']].append(sample)
    result = {'windows': {}, 'rpcMs': {}, 'startup': {}}
    for name, samples in groups.items():
        window = {k: summary([s[k] for s in samples if k in s]) for k in ['elapsedMs', 'captureConsumerBuilds', 'captureNotifications', 'thumbnailRequests', 'catalogLists', 'imageCacheBytes', 'imageCacheEntries']}
        window['trials'] = [{k: v for k, v in s.items() if k != 'frames'} for s in samples]
        window['frames'] = {k: summary([f[k] / 1000 for s in samples for f in s.get('frames', [])]) for k in ['buildUs', 'rasterUs', 'totalUs']}
        window['buildMsPerSecond'] = summary([sum(f['buildUs'] for f in s['frames']) / s['elapsedMs'] for s in samples if 'frames' in s])
        window['rasterMsPerSecond'] = summary([sum(f['rasterUs'] for f in s['frames']) / s['elapsedMs'] for s in samples if 'frames' in s])
        result['windows'][name] = window
    for method, values in data['nativeTimesUs'].items():
        result['rpcMs'][method] = summary([v / 1000 for v in values])
    startup_path = OUT / phase / 'startup.json'
    if startup_path.is_file():
        startup = json.loads(startup_path.read_text())
        for key, metric in [('processCold', 'TotalTime'), ('warmResume', 'WaitTime')]:
            result['startup'][key + metric] = summary([t[key][metric] for t in startup['trials'] if metric in t[key]])
    resources = json.loads((OUT / phase / 'resource_samples.json').read_text())
    rgroups = collections.defaultdict(list)
    for r in resources:
        rgroups[r['phase'].split(':')[0]].append(r)
    result['resources'] = {}
    for name, rows in rgroups.items():
        cpus = []
        for r in rows:
            matches = [line.split() for line in r['top'].splitlines() if re.match(r'\s*\d+\s+u0_', line) and 'com.xrecorder.xrecorder' in line]
            if matches:
                cpus.append(float(matches[-1][8]))
        values = {k: summary([r[k] / 1024 for r in rows if r.get(k) is not None]) for k in ['pssKiB', 'rssKiB']}
        values['cpuPercentOneCore100'] = summary(cpus)
        for k in ['heapUsage', 'heapCapacity', 'externalUsage']:
            values[k + 'MiB'] = summary([r['dart'][k] / 1048576 for r in rows if r.get('dart') and k in r['dart']])
        result['resources'][name] = values
    sessions = collections.defaultdict(list)
    for t in data['transitions']:
        sessions[t['id']].append(t)
    result['screenshotTimingMs'] = []
    for rows in sessions.values():
        if not rows[0]['screenshot']:
            continue
        times = {state: next((r['atMs'] for r in rows if r['state'] == state), None) for state in ['awaitingPermission', 'countdown', 'starting', 'completed']}
        if times['completed'] is not None and times['starting'] is not None:
            result['screenshotTimingMs'].append({'firstStateMs': times, 'startingToSavedMs': times['completed'] - times['starting']})
    result['outputs'] = inspect_outputs(phase, data)
    return result


if __name__ == '__main__':
    results = {phase: summarize_phase(phase) for phase in ['before', 'after']}
    (OUT / 'comparison.json').write_text(json.dumps(results, indent=2), encoding='utf8')
    lines = ['# Task 03 raw measurement summary', '',
             'Three trials per phase; heartbeat n=9; 90s diagnostic n=1. p95 is nearest rank. Durations include test waits. Frame percentiles pool frames of each phase.', '',
             '| Window | Duration median / p95 ms BEFORE | AFTER | Build p95 ms BEFORE / AFTER | Raster p95 ms BEFORE / AFTER |',
             '|---|---:|---:|---:|---:|']
    def fmt(value):
        return '-' if value is None else f"{value['median']:.2f} / {value['p95']:.2f}"
    def p95(value):
        return '-' if value is None else f"{value['p95']:.2f}"
    for name, before in results['before']['windows'].items():
        after = results['after']['windows'][name]
        lines.append(f"| {name} | {fmt(before['elapsedMs'])} | {fmt(after['elapsedMs'])} | {p95(before['frames']['buildUs'])} / {p95(after['frames']['buildUs'])} | {p95(before['frames']['rasterUs'])} / {p95(after['frames']['rasterUs'])} |")
    lines += ['', '## Resource snapshots', '',
              'CPU 100%=one core. Samples every ~5s, coarse phase assignment, observer overhead. Do not compare export_2s CPU as it also includes screenshot/host activity. Memory values MiB, median / p95. Not leak/battery/thermal proof.', '',
              '| Window | Phase | CPU % | PSS MiB | RSS MiB | Dart heap MiB | Dart external MiB |',
              '|---|---|---:|---:|---:|---:|---:|']
    for phase, result in results.items():
        for name, r in result['resources'].items():
            lines.append(f"| {name} | {phase} | {fmt(r['cpuPercentOneCore100'])} | {fmt(r['pssKiB'])} | {fmt(r['rssKiB'])} | {fmt(r['heapUsageMiB'])} | {fmt(r['externalUsageMiB'])} |")
    lines += ['', '## Native method round trips', '', '| Method | BEFORE median / p95 ms | AFTER median / p95 ms |', '|---|---:|---:|']
    for method, values in results['before']['rpcMs'].items():
        lines.append(f"| {method} | {fmt(values)} | {fmt(results['after']['rpcMs'].get(method))} |")
    (OUT / 'MEASUREMENTS.md').write_text('\n'.join(lines) + '\n', encoding='utf8')
    print('Validated both phases: 3 trials, 9 outputs each; 12 MP4 decode without errors.')
