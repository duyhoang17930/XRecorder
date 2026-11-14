"""Bounded local receiver for real main-app MediaProjection E2E QA."""
import argparse
from pathlib import Path
import re
import shutil
import socket
import subprocess
import json

parser = argparse.ArgumentParser()
parser.add_argument('--attempt', required=True)
args = parser.parse_args()
assert re.fullmatch('[a-z0-9_]+', args.attempt)
assert shutil.disk_usage('D:/').free > 10 * 1024**3
root = Path(__file__).parent
destination = root / ('live_' + args.attempt + '_receiver_media')
destination.mkdir(exist_ok=False)
with socket.socket() as check:
    check.bind(('127.0.0.1', 19350))
with (root / ('live_' + args.attempt + '_receiver.log')).open('xb') as output:
    process = subprocess.Popen([
        'build/task03/ffmpeg/ffmpeg.exe', '-hide_banner', '-nostdin', '-n',
        '-listen', '1', '-timeout', '90', '-i',
        'rtmp://127.0.0.1:19350/live/task10_live_' + args.attempt,
        '-t', '45', '-c', 'copy', '-movflags', '+faststart',
        str(destination / 'received.mp4')], stdout=output, stderr=subprocess.STDOUT,
        creationflags=subprocess.CREATE_NO_WINDOW)
    print(json.dumps({'pid': process.pid, 'ready': True, 'attempt': args.attempt}), flush=True)
    try:
        code = process.wait(timeout=160)
    except subprocess.TimeoutExpired:
        process.terminate()
        code = process.wait(timeout=5)
    print(json.dumps({'exitCode': code, 'attempt': args.attempt}), flush=True)
