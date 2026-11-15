"""Compare every received encoded payload against a contiguous local range."""
import argparse
import json
import re
from pathlib import Path
import statistics
import subprocess

p = argparse.ArgumentParser()
p.add_argument('--attempt', required=True)
args = p.parse_args()
assert re.fullmatch('[a-z0-9_]+', args.attempt)
root = Path(__file__).parent
directory = root.parent / ('live_audio_' + args.attempt + '_media')
probe = 'build/task03/ffmpeg/ffprobe.exe'
report = {'scope': 'All received packets; local startup prefix/tail reported, not hidden', 'streams': {}}
for stream in ['v:0', 'a:0']:
    def packets(name):
        return json.loads(subprocess.check_output([probe, '-v', 'error', '-select_streams', stream,
            '-show_packets', '-show_data_hash', 'sha256', '-show_entries',
            'packet=pts_time,dts_time,data_hash', '-of', 'json', str(directory / name)]))['packets']
    local, received = packets('local.mp4'), packets('received.mp4')
    assert local and received
    wanted = [x['data_hash'] for x in received]
    hashes = [x['data_hash'] for x in local]
    matches = [i for i in range(len(local) - len(received) + 1)
        if hashes[i] == wanted[0] and hashes[i:i + len(received)] == wanted]
    assert len(matches) == 1, (stream, 'No unique contiguous packet identity', matches)
    start = matches[0]
    offsets = [float(a['pts_time']) - float(b['pts_time'])
        for a, b in zip(local[start:], received)]
    for clock in ['pts_time', 'dts_time']:
        times = [float(x[clock]) for x in received]
        assert all(b >= a for a, b in zip(times, times[1:])), (stream, clock)
    report['streams'][stream] = {'localPackets': len(local), 'receivedPackets': len(received),
        'localPrefixNotReceived': start, 'localTailNotReceived': len(local) - start - len(received),
        'everyReceivedPacketSha256Exact': True, 'medianOffsetSeconds': statistics.median(offsets),
        'offsetRangeSeconds': [min(offsets), max(offsets)]}
report['relativeAvOffsetMs'] = abs(report['streams']['v:0']['medianOffsetSeconds'] -
                                    report['streams']['a:0']['medianOffsetSeconds']) * 1000
report['status'] = 'PASS'
with (root / (args.attempt + '_packet_parity.json')).open('x') as stream:
    json.dump(report, stream, indent=2)
print(json.dumps(report, indent=2))
