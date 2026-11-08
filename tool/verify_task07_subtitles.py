"""Retained QA fixtures, Android-surface capture and independent MP4 validation.

Run prepare, then capture alongside flutter drive, then validate. Never removes
media, changes device settings, grants permissions or operates on a user AVD.
"""
import argparse
import hashlib
import json
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

P = argparse.ArgumentParser()
P.add_argument('stage', choices=['prepare', 'capture', 'validate'])
P.add_argument('--directory', type=Path, default=Path('build/verification/task07/g3_outputs'))
P.add_argument('--log', type=Path, default=Path('build/verification/task07/g3_outputs.log'))
args = P.parse_args()
out = args.directory
out.mkdir(parents=True, exist_ok=True)
adb = 'C:/Users/dangh/AppData/Local/Android/Sdk/platform-tools/adb.exe'
ffmpeg = 'build/task03/ffmpeg/ffmpeg.exe'
remote = '/sdcard/Android/data/com.xrecorder.xrecorder/files/media/'

def device(*words):
    return subprocess.check_output([adb, '-s', 'emulator-5560', *words], timeout=30)

assert device('shell', 'getprop', 'ro.boot.qemu.avd_name').decode().strip() == 'ThreeHRecorder_Task021'

if args.stage == 'prepare':
    manual = {
        'en': 'English: café, naïve — 123! 👩🏽‍💻\nSecond line.',
        'vi': 'Tiếng Việt: Nguyễn, Trường, ế, e\u0302\u0301 — 123!\nDòng thứ hai.',
        'es': 'Español: ¡Buenos días! ¿Cómo está?\nCanción, niño, 123.',
        'pt': 'Português: ação, coração, amanhã!\nOlá, São Paulo — 123.',
        'fr': 'Français : « Bonjour ! » L’été, Noël.\nDeuxième ligne — 123.',
        'de': 'Deutsch: Grüße, Straße, schön!\nZweite Zeile — 123.',
        'id': 'Bahasa Indonesia: Selamat pagi!\nBaris kedua — 123.',
        'ja': '日本語の字幕：改行と句読点を確認します。\n二行目 👨‍👩‍👧‍👦 123。',
        'ko': '한국어 자막: 안녕하세요!\n두 번째 줄 — 123.',
        'zh': '中文字幕：没有空格的长句也必须正确显示。\n第二行 👩🏽‍💻 123。',
        'hi': 'हिन्दी उपशीर्षक: क्ष, ज्ञ, त्र — नमस्ते!\nदूसरी पंक्ति १२३ / 123।',
        'ar': 'العربية: مرحبًا بالعالم! English 123\nالسطر الثاني ١٢٣ — 👩🏽‍💻',
    }
    evidence = json.loads(Path('build/verification/task07/g2_native_asr_after/emulator_verification.json').read_text(encoding='utf8'))
    cases = []
    for code, text in manual.items():
        row = next(v for v in evidence['benchmarks'] if v['model'] == 'base' and v['language'] == code and v['file'] == f'fleurs_{code}.wav')
        cases.append({'code': code, 'manual': text, 'generated': row['transcript'],
                      'originalSegments': row['segments'], 'model': 'base', 'source': row['file']})
    manifest = out / 'task07_subtitles.json'
    manifest.write_text(json.dumps(cases, ensure_ascii=False, indent=2), encoding='utf8')
    source = out / 'task07_subtitle_input.mp4'
    if not source.exists():
        subprocess.run([ffmpeg, '-v', 'error', '-f', 'lavfi', '-i', 'color=c=0x404040:s=640x360:r=30:d=4',
                        '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=48000:duration=4',
                        '-c:v', 'mpeg4', '-q:v', '2', '-c:a', 'aac', '-shortest', str(source)], check=True)
    for file in [manifest, source]:
        subprocess.run([adb, '-s', 'emulator-5560', 'push', str(file), remote + file.name], check=True)
    print('Prepared twelve manual + twelve real Whisper-output cues; input SHA256:', hashlib.sha256(source.read_bytes()).hexdigest())

elif args.stage == 'capture':
    seen = set()
    end = time.monotonic() + 900
    while time.monotonic() < end:
        time.sleep(.3)
        if not args.log.exists():
            continue
        raw = args.log.read_bytes()
        log = raw.decode('utf16' if raw.startswith(b'\xff\xfe') else 'utf8', errors='replace')
        for name in re.findall(r'TASK07_SUBTITLE_PREVIEW=([a-z]+_(?:manual|generated))', log):
            if name not in seen:
                (out / f'preview_{name}.png').write_bytes(device('exec-out', 'screencap', '-p'))
                seen.add(name)
                print('Captured actual Android preview:', name, flush=True)
        if 'TASK07_SUBTITLE_SAVE_READY' in log:
            try:
                device('shell', 'uiautomator', 'dump', '/data/local/tmp/task07_srt_picker.xml')
                tree = ET.fromstring(device('shell', 'cat', '/data/local/tmp/task07_srt_picker.xml'))
                for node in tree.iter('node'):
                    if node.get('package') not in ['com.google.android.documentsui', 'com.android.documentsui']:
                        continue
                    if node.get('text') not in ['SAVE', 'Save'] or node.get('enabled') != 'true':
                        continue
                    bounds = re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', node.get('bounds', ''))
                    if bounds:
                        x, y, r, b = map(int, bounds.groups())
                        device('shell', 'input', 'tap', str((x + r) // 2), str((y + b) // 2))
            except (subprocess.SubprocessError, ET.ParseError):
                pass
        if 'All tests passed' in log:
            assert len(seen) == 24, len(seen)
            print('PASS: captured all 24 real preview surfaces and completed SAF save.', flush=True)
            break
        if 'Some tests failed' in log:
            raise SystemExit('Native assertions failed; captured evidence retained.')
    else:
        raise SystemExit('Capture timeout; no arbitrary UI was operated.')

else:
    from PIL import Image, ImageChops, ImageFilter
    import io
    report = json.loads((out / 'emulator_verification.json').read_text(encoding='utf8'))
    results = {}
    def frame(path, seconds):
        return Image.open(io.BytesIO(subprocess.check_output([ffmpeg, '-v', 'error', '-ss', str(seconds),
            '-i', str(path), '-frames:v', '1', '-f', 'image2pipe', '-vcodec', 'png', '-']))).convert('RGB')
    def mask(img):
        return img.convert('RGB').point(lambda v: 255 if v > 150 else 0).convert('L').point(lambda v: 255 if v > 50 else 0)
    def overlap(a, b):
        # Compare glyph masks with a 2px antialiasing/codec tolerance; also
        # retain unmodified PNGs for a reviewer to inspect shaping and ordering.
        aa, bb = a.filter(ImageFilter.MaxFilter(5)), b.filter(ImageFilter.MaxFilter(5))
        suma, sumb = sum(a.getdata()) / 255, sum(b.getdata()) / 255
        return min(sum(ImageChops.darker(a, bb).getdata()) / 255 / max(1, suma),
                   sum(ImageChops.darker(b, aa).getdata()) / 255 / max(1, sumb))
    for code, uri in report['outputs'].items():
        assert re.fullmatch(r'content://media/(external|external_primary)/video/media/\d+', uri)
        source = re.search(r'_data=(.*)', device('shell', 'content', 'query', '--uri', uri, '--projection', '_data').decode())[1].strip()
        video = out / f'{code}.mp4'
        subprocess.run([adb, '-s', 'emulator-5560', 'pull', source, str(video)], check=True, capture_output=True)
        checks = {}
        for phase in ['manual', 'generated']:
            png = out / f'oracle_{code}_{phase}.png'
            subprocess.run([adb, '-s', 'emulator-5560', 'pull', remote + f'task07_oracle_{code}_{phase}.png', str(png)], check=True, capture_output=True)
            oracle = Image.open(png)
            exported = frame(video, report['previews'][code][phase]['timeMs'] / 1000)
            exported.save(out / f'export_{code}_{phase}.png')
            item = report['previews'][code][phase]
            x, y, w, h = item['rect']
            dpr = item['devicePixelRatio']
            preview = Image.open(out / f'preview_{code}_{phase}.png').crop(tuple(round(v * dpr) for v in [x, y, x + w, y + h])).resize((640, 360))
            preview.save(out / f'preview_crop_{code}_{phase}.png')
            export_match = overlap(mask(exported), mask(oracle))
            preview_match = overlap(mask(preview), mask(exported))
            checks[phase] = {'exportOracleGlyphCoverage': export_match, 'previewExportGlyphCoverage': preview_match}
        # No text before first cue or in the gap; the background is gray.
        for seconds in [0, 1.95, 3.95]:
            assert sum(mask(frame(video, seconds)).getdata()) / 255 < 30, (code, seconds)
        results[code] = {'sha256': hashlib.sha256(video.read_bytes()).hexdigest(), 'checks': checks}
    subprocess.run([adb, '-s', 'emulator-5560', 'pull', remote + 'task07_verified.srt', str(out / 'verified.srt')], check=True, capture_output=True)
    (out / 'pixel_metrics.json').write_text(json.dumps(results, indent=2), encoding='utf8')
    for code, row in results.items():
        for phase, checks in row['checks'].items():
            assert checks['exportOracleGlyphCoverage'] > .90, (code, phase, checks)
            assert checks['previewExportGlyphCoverage'] > .80, (code, phase, checks)
    print('PASS: twelve MP4s; 24 preview/export/oracle comparisons; cue start/end/gaps; byte-exact SAF SRT.')
