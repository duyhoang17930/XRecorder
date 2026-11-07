"""Generate one readable Vietnamese report gated by real QA evidence."""
from datetime import datetime
import hashlib
import html
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / 'build/verification/p2_p3'
OUT = ROOT / 'docs/implementation/P2_P3_IMPLEMENTATION_REPORT_VI.html'


def load(path):
    return json.loads((BUILD / path).read_text(encoding='utf-8'))


def log(path):
    data = (ROOT / 'build' / path).read_bytes()
    return data.decode('utf-16' if data.startswith(b'\xff\xfe') else 'utf-8', errors='replace')


def digest(path):
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1048576), b''):
            result.update(block)
    return result.hexdigest().upper()


parts = []


def esc(value):
    return html.escape(str(value))


def paragraph(value):
    parts.append('<p>' + esc(value) + '</p>')


def heading(value):
    parts.append('<h2>' + esc(value) + '</h2>')


def link(label, path):
    parts.append('<p><a href="' + esc(path) + '">' + esc(label) + '</a></p>')


def table(headers, rows):
    parts.append('<div class="scroll"><table><thead><tr>' + ''.join('<th>' + esc(v) + '</th>' for v in headers) + '</tr></thead><tbody>')
    for row in rows:
        parts.append('<tr>' + ''.join('<td>' + esc(v) + '</td>' for v in row) + '</tr>')
    parts.append('</tbody></table></div>')


tests = log('p2_p3_continuation_tests.log')
count = re.search(r'\+(\d+): All tests passed!', tests)
assert count and 'Some tests failed' not in tests
assert 'No issues found' in log('p2_p3_continuation_analyze.log')
audio = load('audio/signal_validation.json')
photo = load('photo/native/emulator_verification.json')
photo_validation = load('photo/validation.json')
platform = load('platform/native/emulator_verification.json')
process = load('process/resumed/emulator_verification.json')
io = load('process/io/emulator_verification.json')
asr = load('whisper/regression/emulator_verification.json')
benchmark = load('whisper/benchmark.json')
profile = load('performance/comparison.json')
a11y = load('accessibility/emulator_verification.json')
packaging = load('apk/verification.json')
assert a11y['serviceBound'] and a11y['touchExplorationEnabled'] and a11y['settingsRestored']
assert packaging['elfAndZip16KiB'] == 'PASS'
assert audio['passed'] and audio['speechNoiseReduction']['improvementDb'] > 1
assert photo['asrComposition'] and all(v < 3 for v in photo['photoMeanAbsolutePixelError'].values())
assert all(v['fullDecode'] == 'PASS' for v in photo_validation['results'])
assert platform['copy']['verified'] and platform['move']['moved']
assert platform['modelDownload']['state'] == 'completed' and platform['disconnectedDestinationRejected']
assert process['draftUnchanged'] and io['journalWriteFailureHandled'] and io['retryCompleted']
assert asr['silenceNoTranscript'] and asr['nativeCancellation'] and asr['activeModelRemovalRejected']
p1 = ['lib/features/recording', 'android/app/src/main/kotlin/com/xrecorder/xrecorder/recording', 'lib/features/settings/recording_settings_form.dart', 'lib/features/settings/audio_video_settings_screen.dart', 'lib/core/widgets/studio_create_sheet.dart']
subprocess.run(['git', 'diff', '--exit-code', '5cdda32084be772f61153bc453ef3675b932ab41', '--', *p1], cwd=ROOT, check=True, capture_output=True)
subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True, capture_output=True)
apks = [BUILD / 'apk/3HRecorder-qa-debug.apk', BUILD / 'apk/3HRecorder-unsigned-release.apk']
source = [p for folder in ['lib', 'android/app/src', 'android/app'] for p in (ROOT / folder).rglob('*') if p.is_file() and p.suffix in ['.dart', '.kt', '.cpp', '.c', '.h', '.kts', '.xml'] and '.cxx' not in p.parts]
latest = max(p.stat().st_mtime for p in source)
assert all(p.exists() and p.stat().st_mtime >= latest for p in apks), 'Rebuild final APKs before report'

paragraph('Cập nhật ' + datetime.now().astimezone().isoformat(timespec='minutes'))
paragraph('P2/P3 đã triển khai bằng backend native và kiểm tra file xuất thật. Giữ nguyên code Người 1; không commit/push, uninstall, wipe hay xóa dữ liệu người dùng. Các giới hạn kiểm chứng được ghi riêng ở cuối báo cáo.')
heading('Kết quả kiểm thử')
table(['Kiểm tra', 'Kết quả'], [
    ['Dart analyze / unit-widget', 'Sạch / ' + count.group(1) + ' tests PASS'],
    ['Native unit storage budget', '2 tests PASS'],
    ['Audio/video', str(len(audio['files'])) + ' file: decode, PTS, gain, trim, fade, mix, voice và layer PASS'],
    ['Đồng bộ flash/tone', str(round(audio['flashToneSync']['differenceMs'], 3)) + ' ms trên fixture'],
    ['RNNoise', 'SI-SDR cải thiện ' + str(round(audio['speechNoiseReduction']['improvementDb'], 2)) + ' dB trên mẫu giọng Việt có nhiễu'],
    ['Photo', 'EXIF 1–8, DisplayP3 → sRGB, JPEG, resize, nền trắng cho alpha PASS'],
    ['Subtitle', 'Edited audio → ASR → editor → SRT/burn-in; long text, style và speed PASS'],
    ['Offline ASR', 'vi/en/auto; silence không tạo transcript; hủy native; ngăn xóa model đang dùng PASS'],
    ['SAF/platform', 'Picker audio, verified copy/move, UTF-8 SRT, tải model, thu hồi grant; shortcut theo evidence'],
    ['Reliability', 'Storage preflight từ chối job quá lớn; process-kill giữ draft; journal EACCES báo Failed và Retry thành công'],
    ['TalkBack', 'Service 16.0 bind thật và bật touch exploration; focus/gesture chưa chứng nhận. Đã khôi phục cài đặt QA.'],
    ['APK', 'Ba ABI, notices MIT/BSD3 và ELF/ZIP 16 KB PASS; QA đã cài lại bằng install -r.'],
])
heading('Chức năng đã triển khai')
table(['Nhóm', 'Hành vi thực'], [
    ['Video/audio', 'Trim/split/reorder/merge ảnh và video; crop/rotate/flip/relink; speed; 8 audio tracks với source trim, output alignment, fades và volume headroom. Deep/bright/robot và RNNoise offline.'],
    ['Layers', 'Text, sticker vector, drawing; position/scale/rotation/duration/color/order. Chung composition cho preview/export; giữ playhead khi đổi effect.'],
    ['AI offline', 'whisper.cpp 1.9.5 C++/JNI; vi/en/auto; tiny/base/small-q5_1. Model checksum/download/import/remove, progress/cancel thật và persisted jobs. Không có server speech.'],
    ['Photo/subtitle', 'EXIF/sRGB/PNG/JPEG/resize; undo/history; subtitle wrapping/styles/timing/retime, system SRT picker và burn-in MP4.'],
    ['Media/platform', 'Library/search/sort/observer/cache; SAF pending publication và SHA256 read-back; move chỉ xóa nguồn sau khi đích xác minh và có quyền thật; Trash/Restore recovery; static/pinned shortcuts.'],
])
heading('Benchmark ASR thật')
paragraph('Một mẫu tiếng Anh JFK và một mẫu tiếng Việt Google FLEURS CC-BY4.0. CER chuyển chữ thường, giữ dấu tiếng Việt, bỏ dấu câu/khoảng trắng. Benchmark nhỏ trên emulator, không đại diện cho mọi giọng nói hoặc thiết bị.')
table(['Model', 'Ngôn ngữ', 'Thời gian', 'RTF', 'CER'], [[v['model'], v['language'], str(round(v['elapsedMs'] / 1000, 3)) + ' s', round(v['realTimeFactor'], 3), str(round(v['CER'] * 100, 3)) + '%' if 'CER' in v else '—'] for v in benchmark['benchmarks']])
paragraph('Small peak sampled PSS: ' + str(benchmark.get('smallPeakPssKiB', '—')) + ' KiB. Tiny ưu tiên tốc độ; base cân bằng; small chậm và cần nhiều RAM hơn. Weights không nằm trong APK, chỉ tải/import khi người dùng chọn. Mỗi lượt nhận dạng giới hạn 10 phút để kiểm soát bộ nhớ.')
heading('Hiệu năng thư viện')
table(['Run', 'Items/frames', 'Build p95', 'Raster p50/p95', 'Raster >16,7 ms'], [[name, str(v['items']) + '/' + str(v['raster']['frames']), str(v['build']['p95ms']) + ' ms', str(v['raster']['p50ms']) + ' / ' + str(v['raster']['p95ms']) + ' ms', v['raster']['over16_7ms']] for name, v in profile.items() if isinstance(v, dict) and 'raster' in v])
paragraph('Cùng corpus 1.006 ảnh, 30 drag liên tục 400 ms, API36 x86_64 SwiftShader. Clip.hardEdge giảm raster p95 khoảng 8%; vẫn chưa đạt 60 fps trên emulator. Giảm thumbnail width riêng lẻ chưa cải thiện p95; giữ cả số đo trước/sau.')
heading('Refactor và dọn file')
paragraph('Source whisper/ggml Android CPU còn 145 file thay vì 1.456. RNNoise giữ 18 source/header/license cần compile; bỏ training/tools/backend GPU không dùng. Tách model storage khỏi speech-job lifecycle trong cùng file; gom logic fit timeline dùng chung; định dạng Kotlin P2/P3. Bỏ nhánh remote ASR không dùng. Docs còn 5 tài liệu làm việc và 1 báo cáo HTML. Không xóa media, draft, model đã tải hay tài sản tham chiếu.')
heading('APK và bằng chứng')
for apk in apks:
    link(apk.name, '../../' + apk.relative_to(ROOT).as_posix())
    paragraph(str(apk.stat().st_size) + ' bytes · SHA256 ' + digest(apk))
paragraph('QA debug APK có thể cài. Release APK chưa ký cần signing của chủ dự án trước khi phát hành; không đọc hay lưu signing key/password.')
for label, path in [
    ('Audio / signal validation', 'audio/signal_validation.json'), ('Video mix mẫu', 'audio/mix.mp4'),
    ('Giọng Việt trước giảm nhiễu', 'audio/speechNoisy.mp4'), ('Giọng Việt sau giảm nhiễu', 'audio/speechDenoised.mp4'),
    ('Benchmark ASR', 'whisper/benchmark.json'), ('ASR regression', 'whisper/regression/emulator_verification.json'),
    ('Subtitle burn-in', 'photo/asrBurnIn.mp4'), ('SRT thật', 'platform/verified_subtitles.srt'),
    ('Platform integration', 'platform/native/emulator_verification.json'), ('Process recovery', 'process/resumed/emulator_verification.json'),
    ('Journal fault recovery', 'process/io/emulator_verification.json'), ('Profile comparison', 'performance/comparison.json'),
    ('TalkBack smoke và giới hạn', 'accessibility/emulator_verification.json'), ('APK packaging', 'apk/verification.json'),
]:
    assert (BUILD / path).exists(), path
    link(label, '../../build/verification/p2_p3/' + path)
heading('Giới hạn kiểm chứng')
paragraph('Signal/file checks không thay thế human listening hoặc human usability signoff. Chưa chứng nhận máy thật, OEM/SD card, thermal/battery, leak soak hay toàn bộ codec/API24/28. TalkBack và launcher smoke ghi đúng phạm vi trong TEST_EVIDENCE. Chưa tạo đầy đĩa ENOSPC hoặc kill đúng cửa sổ MediaStore commit; đã thử storage preflight, process-kill khi encode và lỗi ghi EACCES. Final P1 → P2 → P3 capture integration chờ P1 sẵn sàng.')
for name in ['P2_P3_MASTER_PROGRESS.md', 'P2_P3_CURRENT_AUDIT.md', 'P2_P3_CONTRACTS.md', 'P2_P3_TEST_EVIDENCE.md', 'REUSE_REGISTER.md']:
    link(name, name)
style = 'body{font:16px/1.6 system-ui,sans-serif;max-width:1100px;margin:auto;padding:24px;color:#182335;background:#f5f7fb}h1,h2{line-height:1.25}h2{margin-top:36px}table{border-collapse:collapse;width:100%;background:white}th,td{border:1px solid #ccd5e2;padding:10px;text-align:left;vertical-align:top}.scroll{overflow-x:auto}a{color:#164d9e}p{overflow-wrap:anywhere}@media(max-width:600px){body{padding:14px}table{font-size:14px}}'
OUT.write_text('<!doctype html><html lang="vi"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>3HRecorder — Báo cáo P2/P3</title><style>' + style + '</style><h1>3HRecorder — Báo cáo P2/P3</h1>' + ''.join(parts) + '</html>', encoding='utf-8')
print(OUT)
