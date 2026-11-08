# TASK07 — Dung lượng và tài nguyên

Checkpoint G5: build từ `lib/main.dart`, release **unsigned**, không dùng signing
credentials, không publish. Không clean cache/build, không xóa media/model/draft.
Các số G5 dưới đây được giữ làm checkpoint; bảng G6 cuối ở cuối tài liệu.

## APK thực đo

| Artifact | Bytes | MiB | ABI |
|---|---:|---:|---|
| P2/P3 unsigned release lưu trước TASK07 |64954063|61.945|armv7/arm64/x86_64|
| TASK07 G5 universal |69601779|66.377|armv7/arm64/x86_64|
| TASK07 G5 split arm64 |24833975|23.684|arm64-v8a|
| TASK07 G5 split armv7 |21676039|20.672|armeabi-v7a|
| TASK07 G5 split x86_64 |26478491|25.252|x86_64|

Universal tăng4647716 bytes (**7.16%**). Đây là so sánh với artifact P2/P3 được
lưu, không phải thí nghiệm cô lập từng thay đổi giữa hai working tree. Bản arm64
tách ABI nhỏ hơn universal khoảng64.3%; không cắt tính năng hay model management.
Các file G5 nằm trong `build/verification/task07/apk/`; chưa phải APK bàn giao G6.

Flutter AOT size analysis arm64 ghi nhận phần quy cho l10n của app686080 bytes,
`flutter_localizations`254059 bytes, `intl`97252 bytes. Đây là attributed AOT
bytes, **không phải** compressed APK delta và không được cộng/trừ như số đo download.
Native payload chiếm67785296 compressed bytes trong universal. Font vẫn169180
bytes trước nén/70031 bytes trong ZIP, bằng baseline; không thêm font pack.
Licenses tăng16243→17913 compressed bytes, gồm notice CLDR/Babel.

Không bundle Whisper weights, corpus FLEURS, host translation model hay reference
media. RNNoise dùng weights nhỏ vốn có trong native DSP; G2 reuse chúng để kiểm
tra speech activity, không thêm một bản model mới.12 locale và standard Flutter
delegates là chi phí chức năng; không loại delegates cần thiết chỉ để giảm số đo.

## Packaging đã kiểm tra

Universal và cả3 split đều PASS: đầy đủ `libapp.so`, `libflutter.so`,
`libthreeh_whisper.so`, `libc++_shared.so` cho ABI tương ứng; notices/assets;
ELF LOAD/ZIP alignment16KB cho thư viện64bit. SDK `zipalign -c -P 16 -v 4`
PASS trên universal. Đây là static checks, chưa thay runtime16KB/ARM.

Một artifact phân tích dùng riêng `--target-platform android-arm64` vẫn chứa JNI
CMake của các ABI khác mà không có Flutter engine tương ứng. Nó được giữ làm
**negative control, không phân phối/cài**:
`3HRecorder-TASK07-G5-arm64-unsigned.apk`. Validator nay từ chối partial ABI;
split chính thức được build bằng `--split-per-abi`. Bản phân tích vẫn hữu ích để
đọc AOT tree, nhưng tên target không chứng minh APK chỉ có một ABI hoàn chỉnh.

Build vẫn có warning CupertinoIcons của SDK. App Android dùng Lucide/Material;
không thêm dependency/font không dùng chỉ để giấu warning. Không dùng release
unsigned để tuyên bố runtime release đã PASS.

## Workspace và dữ liệu AVD (read-only)

Metadata inventory ban đầu khoảng25.6GiB logical file sizes:

| Nhóm | GiB | Ý nghĩa |
|---|---:|---|
| `build` |21.106|APK, native/compiler output, QA media, traces, host models/fixtures, AVD artifacts|
| `.dart_tool` |3.848|Flutter/Dart cache và output trung gian|
| `android` |0.356|Android source, vendored C/C++, build metadata|
| `.claude-local` |0.222|Harness/tham chiếu local, Git-ignored|
| `.git` |0.028|Git metadata|
| `lib` |~0.002|Source Dart/ARB, không phải installed app size|

Sau G5, build21.390GiB và `.dart_tool`3.920GiB vì giữ thêm artifacts và size
analysis. Không xóa chúng để tạo số đo giảm giả. Inventory dùng logical file
length; file sparse/AVD và allocated disk có thể khác. Không có stat failure.

AVD QA5560 `du -sk` (allocated KiB):

| Dữ liệu | KiB | Phân loại |
|---|---:|---|
| `no_backup/speech_models` |406012|3 model đã tải/import,~396.5MiB; không nằm trong APK|
| `files/projects` |736|Drafts hiện có, giữ nguyên|
| `cache` |8|Cache tại thời điểm đo; không phải peak render RAM/disk|
| `files` tổng |1288|Private app files, gồm drafts/history/trash metadata|
| External QA media |422188|Fixtures và bản import model; dữ liệu QA riêng|
| Movies/XRecorder |118776|Các file đã xuất, không phải APK/assets|

Không suy installed size từ workspace hay APK ZIP. Installed footprint còn tùy
ABI, Android code/cache và model người dùng chọn tải. G6 sẽ bổ sung runtime/
recovery/peak measurements; dữ liệu người dùng không phải cache tự động xóa.

Evidence: `g5_size_before_release.json`, `g5_size_after_release.json`,
`g5_release_build.log`, `g5_arm64_size_analysis.log`, `g5_split_abi_build.log`,
`g5_verify_*.log`, `g5_partial_abi_negative_control.log`, `g5_zipalign.log`,
`size_analysis/` dưới `build/verification/task07/`. JSON có SHA256 từng APK.

## Artifact G6 cuối — main.dart,08/11/2026

| Artifact | Bytes | MiB | ABI / versionCode |
|---|---:|---:|---|
| Release unsigned universal |69683699|66.456|3 ABI /1|
| Release unsigned arm64 |24899511|23.746|arm64 /2001|
| Release unsigned armv7 |21692423|20.688|armv7 /1001|
| Release unsigned x64 |26478491|25.252|x64 /4001|
| QA profile universal |95905745|91.463|3 ABI /1|
| QA profile arm64 |36855789|35.148|arm64 /2001|
| QA profile armv7 |33857207|32.289|armv7 /1001|
| QA profile x64 |38658014|36.867|x64 /4001|

Release universal tăng4729636 bytes (**7.282%**) so với artifact trước TASK07,
tăng81920 bytes so với checkpoint G5. Không so QA profile với release như cùng
build mode. Font bundle release vẫn169180 bytes/raw và70031 bytes/compressed,
không thêm font pack/model/corpus. `AssetManifest.bin` và `DebugProbesKt.bin` là
metadata hợp lệ; kiểm `.bin` cấm mọi file đã gây một false failure của helper
audit, sau đó được sửa thành allowlist chính xác, không loại model khỏi kiểm tra.

Cả8 artifact PASS full ABI/native library/license/ELF/ZIP16KB. DEX và từng
`libapp.so`/`libthreeh_whisper.so` của3 release split khớp final release universal,
tránh lấy nhầm output cũ. Evidence: `g6_release_binary_parity.json`,
`g6_artifact_manifest.json` (bytes/SHA256/ABI/versionCode/fonts),
`g6_verify_*.log`, `g6_*build.log`.

QA APK dùng profile AOT và SDK debug certificate; release vẫn **unsigned**.
Một thử nghiệm override version bằng biến môi trường Gradle không có tác dụng:
`aapt` xác nhận split vẫn mang versionCode ABI mặc định, không phải1. Ba alias
`-v1-` đã được chứng minh byte-identical rồi xóa; giữ artifact canonical và log
thất bại cấu hình, không đổi version dự án/P1.

QA5560 từ chối cài universal với `INSTALL_FAILED_INSUFFICIENT_STORAGE` khi
`/data` còn443672KiB/6082144KiB (~7%). Đây là kết quả thực tế, không xóa dữ liệu
để làm test xanh. Backup files/preferences805376 bytes/SHA256
`2b0cb6bb8b368284f53e9120e67fd380ff5a4d9671bf375048c149dfd536decb`.
Bản QA x64 split cài `install -r` thành công, main app chạy; dữ liệu được giữ lại.
Split version4001 có thể ảnh hưởng cập nhật từ universal version1 trong QA;
không uninstall để đổi artifact. Universal vẫn là bản QA đa ABI để bàn giao.

Universal main runtime PASS API34 và actual16KB; API36 main dùng x64 split.
Native focus test9.9KB là APK riêng cho instrumentation, không nằm trong8 APK
bàn giao và không được coi là tăng app production size. Cuối G6 host metadata
inventory40.922GiB logical:build35.499GiB, `.dart_tool`4.799GiB,0 stat failures.
Chênh lệch so G5 gồm AVD16KB/bản sao API34, APK/trace/corpus và debug native build;
không suy installed size. `g6_final_workspace_size.json` ghi từng root.
