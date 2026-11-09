# TASK08 — Storage / package size

09/11/2026. Không xóa hoặc dọn file trong task. Source cuối dùng suffixAPK
**v5**;v1–v4 và logs thất bại được giữ để truy vết, không phải bản bàn giao.

## APK thực tế

`build/verification/task08/m5_final_apk_manifest_v5.json` chứa bytes/SHA256,
native/AOT/assets breakdown và kết quả kiểm từng APK. MiB=bytes/1048576.

| Artifact dưới `build/verification/task08/apk_v1/` | MiB | Loại |
|---|---:|---|
|3HRecorder-TASK08-QA-profile-v5.apk|89.774143|Main universal,SDK debug certificate|
|3HRecorder-TASK08-QA-arm64-v8a-profile-v5.apk|35.304121|True arm64 split,QA|
|3HRecorder-TASK08-QA-armeabi-v7a-profile-v5.apk|32.397575|True armv7 split,QA|
|3HRecorder-TASK08-QA-x86_64-profile-v5.apk|36.960357|True x64 split,QA|
|3HRecorder-TASK08-release-unsigned-v5.apk|66.580554|Unsigned release universal|
|3HRecorder-TASK08-arm64-v8a-unsigned-v5.apk|23.746024|Unsigned release true arm64|
|3HRecorder-TASK08-armeabi-v7a-unsigned-v5.apk|20.687507|Unsigned release true armv7|
|3HRecorder-TASK08-x86_64-unsigned-v5.apk|25.376857|Unsigned release true x64|

Tất cả8 PASS ABI completeness/licenses/64bit ELF+ZIP16KB static.4 QA APK
PASS apksigner verify; không dùng production key, không ký release hoặc publish.
Không bundle Whisper weights hoặc WAV/MP4 fixtures. Native RNNoise weights nhỏ
vốn có trong DSP không phải Whisper download model.

TASK07 unsigned universal69683699B→69814771B: **+131072B(128KiB)**.
Arm64 release24899511B→24899511B: không tăng byte count; hash khác, không phải
cùng artifact. x64 release26478491B→26609563B:+128KiB. Không cắt feature/font
hoặc model management để giảm size.

QA universal TASK07 95905745B→94135012B. Không quy toàn bộ thay đổi container
cho tối ưu app: so với TASK08v3, ZIP compressed payload chỉ tăng691B trong
classes4.dex nhưng tổng APK giảm2049261B; phần chênh chủ yếu ở packing/header/
signing overhead. Không gọi đây là giảm payload chức năng2MB.

Build release đầu dùng `--no-pub` sau profile FAIL vì GeneratedPluginRegistrant
còn dev-only integration_test trong khi Gradle release loại plugin. Dùng quy
trình Flutter build bình thường để SDK regenerate đúng mode; không sửa generated
Java thủ công. `pubspec.lock` giữ SHA; xem `m5_dependency_integrity_v1.json`.
Kiểm analyze/test vẫn dùng `--no-pub` theo yêu cầu. Warning CupertinoIcons của
SDK còn từ trước; không thêm font/dependency không dùng để che warning.

## Workspace khác installed data

`m5_workspace_inventory_v3.json`: **106.963GiB logical /20352files**,0 lỗi stat,
không follow symlinks. Snapshot sau finalsoak/mainrestore backups;không phải
download/install size và không suy thành physical allocated size của sparse AVD.

| Nhóm | GiB logical |
|---|---:|
|build/verification/task08|62.087|
|build/verification/task07|16.838|
|build/task021_avd|9.098|
|.dart_tool/flutter_build|5.454|
|build/final_api34_avd|5.109|
|build/app|3.771|

Tăng so với40.922GiB TASK07 gồm AVD TASK08, nhiều whole offline checkpoints,
backups/data từ AVD cũ, partial transfers, raw profiles, model/fixture copies và
APK versions. Giữ chúng theo yêu cầu safe evidence; không cleanup để làm metric
đẹp. Không thao tác thư mục AVD API34 gốc; test dùng clone riêng.

API36 `m5_installed_private_v1.log`:874524KiB private, gồm files468412KiB,
no_backup406016KiB,cache8KiB,code_cache48KiB. External26336KiB. Phần lớn là
3 model415728665B và QA copies của model/input để FileProvider tests; không phải
thumbnail cache tự tăng vô hạn. Thực tế máy người dùng phụ thuộc model đã chọn,
media và draft; không lấy QA staging thành install-size mặc định.

20 cancel thực giữuri=null/source exact; model cancel/import lỗi giữ model đã
verified. Backend chỉ dọn temporary thuộc job; source fixtures/foreign trash
được giữ. ADB backup stages cố ý retained là evidence QA ngoài app, không phải
orphan export production. ENOSPC toàn đĩa không chạy bằng filler vì task cấm
cleanup/deletion; EISDIR write-failure và install-space guards đã kiểm riêng.
