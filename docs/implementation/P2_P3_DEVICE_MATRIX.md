# P2/P3 — device matrix 07/11/2026

Không dùng emulator cá nhân để QA. `emulator-5554` API37 của người dùng chỉ được
liệt kê read-only; không cài app, đổi settings, stop hay test trên đó.

| Thiết bị/API | Thực thi trong đợt này | Verdict và giới hạn |
|---|---|---|
| ThreeHRecorder_Task021 /5560, API36 x86_64,3GiB/4vCPU, SwiftShader |3+3 profile trials;320/411dp Light/Dark/text200;12 audio/layer outputs;photo/EXIF/ICC/subtitles;38 corpus jobs + post-patch9 inference;SAF/download/recovery/publication;30preview/20cancel soak |PASS các assertions đã ghi. Raster p95 còn40,515ms median; không phải60fps/máy thật. Debug memory không chứng minh không leak. |
| ThreeHRecorder_Final_API34 /5562, API34 x86_64,2GiB/4vCPU, SwiftShader/Vulkan off |New AVD retained data; main.dart launch, catalog/rename/drafts/MP4/GIF/cancel/retry;H264/HEVC;6 VI/EN/auto Tiny/Base inference +silence/cancel |PASS native/media/JNI assertions. Cancel request3ms, drain+next decode515ms. Pulled MP4/GIF/codec outputs full-decode PASS. Không thay cho toàn bộ SAF/photo/profile matrix API34. |
| API24/28/29/33/35 |Không có image tương ứng cài sẵn hoặc thiết bị QA được cấp quyền |NOT RUN; cần AVD/device đúng phiên bản, đặc biệt legacy file discovery và storage permissions. API34 không đại diện cho các API này. |
| ARM64 và ARMv7 runtime |Không có máy thật tương ứng được cấp quyền |NOT RUN. Build/ELF/ZIP/ABI checks chỉ chứng minh packaging, không chứng minh codec/AI latency hay runtime32bit. |
| Release và16KB runtime |Release để unsigned; không có QA device16KB được chỉ định |NOT RUN runtime; ELF/ZIP16KB static checks PASS. Không dùng AVD API37 của người dùng để đóng gate. |
| OEM/SD/removable providers |Không có thiết bị/card/provider thật |NOT RUN; cần copy/move/restore/remount/revoked-grant có fixture được phép dùng. |
| Physical60Hz/thermal/battery/10-minute speech |Không có máy thật |NOT RUN; emulator RTF/PSS không quy đổi sang pin/nhiệt/FPS máy thật. |
| Human listening/usability/TalkBack gesture |Không có người tham gia |NOT TESTED.10 tasks trong docs/ui/USABILITY_TEST_VI.md; hai cỡ máy, tay trái/phải. TalkBack service smoke đợt trước không thay gesture/focus. |
| Final P1→P2→P3 |Người1 đang làm capture |OPEN; cần bản capture sẵn sàng và chạy consent→capture→library→edit→export riêng. P1 source/hash không thay runtime test. |

API34 native portrait preview cũng được chụp ở500ms và nhìn thấy frame trắng
đúng9:16. Ảnh đầu có overlay Flutter cũ khi capture ngay sau resize; cùng product
binary, harness chờ native layout +Flutter overlay commit theo wall-clock rồi
pump/settle cho ảnh sạch `api34_preview_settled.png`. Giữ ảnh đầu để truy nguyên;
không suy steady-state snapshot thành chứng nhận mọi transient animation trên máy thật.

## Lỗi môi trường và harness đã gặp

- API36 và cold boot API34 có System UI ANR trên host/software GPU. Giữ dialog
  XML/ảnh, chọn Wait ở đúng dialog. Không gọi đó là app ANR hoặc ảnh UI đạt.
- Cold boot API34 đầu2vCPU offline; retry4vCPU, Vulkan off, show-kernel boot được.
  Không wipe/uninstall/clear-data. Logs `api34_emulator_*`, `api34_retry_*`.
- ADB-staged external-files fixture API34 bị EACCES. Dùng fixture private do app
  UID ghi, qua FileProvider root đã có sẵn; không chmod/root/đổi quyền product.
  Binary stdin transfer đầu bị truncate; đã chuyển adb file-sync→app UID copy,
  read-back SHA256 khớp cho cả7 files trước khi chạy. Failures được giữ ở
  `api34_fixture_permission_failure.log`, `api34_binary_fixture_failure.log`.
  Đây không chứng nhận API34 SAF/provider behavior; source test không giả PASS.
- Release `--no-pub` đầu lỗi generated integration-test registrant. Build thường
  tái tạo registrant; không sửa file generated hoặc thêm test plugin vào release.

## Bằng chứng và phân loại

Root `build/verification/final_p2_p3/`:API36 logs theo area trong TEST_EVIDENCE;
API34 `api34_native.log`, `api34_codecs.log`, `api34_asr.log`, `api34/*`,
`api34_fixture_hashes.json`. PNG headers xác nhận840/1080px, DPR2,625.

- **Implemented and verified now:** các row có assertions PASS nêu trên.
- **Implemented but not independently verified:** behavior ngoài subset đã chạy
  trên từng API, ABI/codec/OEM khác, toàn bộ accessibility gestures.
- **Not implemented:** không tạo bản ghi cảm nhận/người tham gia hoặc thermal
  telemetry giả để đóng gate.
- **Blocked by external access:** máy ARM/OEM/SD/người thử và P1-ready build.
  Cần đúng thiết bị/dữ liệu/consent; không dùng permission bypass.
