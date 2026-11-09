# Task 04 — Video Quality, Codec & Orientation

**PARTIAL / NEEDS DEVICE VERIFICATION**, 2026-11-07, `feature/capture-live`. Tiếp tục source Task 02–03, không coi các task đó đã được nghiệm thu thiết bị.

- Giữ pipeline MediaCodec Surface → VirtualDisplay → MediaMuxer, không tạo encoder/session song song. Resolution/FPS/bitrate/codec nhận từ settings thật, bitrate đơn vị bits/s; AAC giữ 128 kbps riêng.
- Sửa capability: trước đây presets chỉ AVC dù HEVC có tồn tại. Nay mỗi preset mang codec AVC/HEVC; kiểm tra Surface color format, alignment, tổ hợp width/height/FPS; lỗi query của một codec không loại các codec hợp lệ khác. Preset shared không có orientation field nên chỉ advertise nếu cả portrait/landscape có cấu hình hợp lệ. Codec được chọn kiểm tra thêm bitrate; không reject vì chỉ xét bitrate của encoder đầu tiên. Không fallback HEVC thành AVC.
- Không advertise/chấp nhận preset lớn hơn display metrics để chỉ upscale đạt nhãn 2K/4K. Presets 720/1080/1440/2160 và 24/30/60/90/120 vẫn phụ thuộc capability. Metrics hiện tại không dự đoán kích thước app người dùng sẽ chọn sau consent.
- Forward `hardwareEncoding` sẵn có trong shared model vào native và replay snapshot; API29+ ưu tiên encoder đúng hardware/software preference, fallback sang encoder hợp lệ khác nếu không có. Đây là preference, không cam kết hardware bắt buộc. Native capability thêm tên encoder và phân loại thật; API<29 ghi unknown, không đoán theo tên. Không sửa public signature/model/persistence.
- Orientation: giữ lựa chọn kích thước initial Auto/Portrait/Landscape; API34+ dùng callback resize cùng VD từ Task 02. Encoder canvas cố định, nội dung fit không crop; đổi tỷ lệ có thể letterbox. API cũ giữ cơ chế hiện có; chưa nghiệm thu dynamic orientation hoặc xoay encoder resolution. Không thêm metadata rotation giả/GL pipeline.
- Normal giữ cấu hình hợp lệ. Performance giữ policy hiện có (tối đa 1280×720, 30 FPS, 8 Mbps), phản ánh effective config trong snapshot. Không thay policy khi chưa benchmark; **chưa xác minh** CPU/RAM/FPS hoặc chất lượng so với Normal.
- Trước MediaStore commit: ngoài duration/audio metadata hiện có, MediaExtractor kiểm tra đúng 1 video, audio 0 hoặc 1 theo mode, codec MIME và width/height trùng config. Không Saved nếu sai. Không coi metadata là bằng chứng decode frame/actual FPS/bitrate.
- Files: CaptureConfig.kt, CaptureBridge.kt (capabilities context), CaptureService.kt (output tracks validation), recording_service.dart (data mapping), recording_service_contract_test.dart; reuse VideoEncoder.kt đã sửa cleanup/timebase ở Task 02/03.
- Host checks: kết quả tổng hợp cuối báo cáo. NOT RUN thiết bị: AVC/HEVC, 720p30/1080p30/60/2K/4K, unsupported paths/init fault injection, rotation, playback/frame analysis, actual FPS/bitrate, benchmark và A/V regression. Người dùng yêu cầu chỉ code/host checks; không cài APK, không thay dữ liệu/video người dùng.
- Giữ consent/session/FGS/pause/resume/cancel/stop/MediaStore/Saved và audio Task 03. Không sửa widget/style/navigation, shared UI hoặc P2/P3; UI dirty từ task trước được giữ byte-for-byte. Không commit/push/reset; không build release hoặc thêm dependency. Không cần P2 tích hợp mới cho Task 04.

Tham chiếu: [MediaCodecInfo](https://developer.android.com/reference/android/media/MediaCodecInfo), [VideoCapabilities](https://developer.android.com/reference/android/media/MediaCodecInfo.VideoCapabilities), [MediaProjection resize](https://developer.android.com/media/grow/media-projection).

## Kết quả host lần triển khai đầu

- PASS: `flutter analyze --no-pub` (No issues found); 13 Flutter tests (controller 8, contract mapping 2, Recording Settings 320/360/411dp 3).
- PASS: `./gradlew --offline :app:compileDebugKotlin :app:testDebugUnitTest --tests '*CaptureRequestsTest' --tests '*AudioVideoMathTest' --tests '*FloatingControlGeometryTest'` — 9 JUnit tests, 0 failures/errors. Build chỉ debug; warnings Flutter Gradle có sẵn, không sửa Gradle.
- PASS: `git diff --check`; đối chiếu checksum baseline đầu Task 02: mọi presentation/shared/P2/P3 file giữ nguyên; suffix widgets trong recording_service.dart giống hệt baseline. Source mới chỉ thuộc native/controller/tests/docs P1.
- NOT RUN: toàn bộ test MP4/âm thanh/performance trên Android. Kiểm tra tiếp: consent deny/accept → Start/Pause/Resume/Stop/Cancel; system stop/recreation; quay từng audio mode; các preset codec/orientation được advertise; đo metadata, frames/timestamps và A/V bằng mẫu có dấu mốc. Không có MP4 before/after mới để tuyên bố PASS.

## Kiểm tra lại Task 04

- Sửa lỗi Auto Bitrate + Performance: trước đây chọn encoder chỉ theo size/FPS, rồi clamp bitrate xuống 8 Mbps; nếu encoder có minimum >8 Mbps, Start lỗi dù encoder sau phù hợp. Nay xét giao bitrate range với trần mode **trước khi chọn encoder**, skip candidate không có bitrate hợp lệ. Auto chọn trong giao range; Normal giữ requested bitrate và reject ngoài range. Giữ nguyên trần Performance hiện có, không thêm policy giảm chất lượng mới. Đây là lỗi nhánh source; chưa tái hiện trên driver thật.
- File đổi riêng lượt này: `CaptureConfig.kt`, `VideoBitrateTest.kt`, báo cáo này. Checksum mọi file có sẵn khác giống đầu lượt: UI, audio Task 03 (gồm AAC selection), controller/service Task 02 không đổi. Không sửa P2/P3/shared API; không cần integration request mới.
- PASS: compileDebugKotlin; 10 JUnit tests (VideoBitrateTest 4 + AudioVideoMathTest 3 + CaptureRequestsTest 3), 0 failures/errors. Tests mới kiểm tra Auto range, trần Performance, Normal giữ bitrate và reject invalid; không giả MediaCodec/device capability.
- PASS: 16 Flutter regression tests (controller 10 + audio/video contract 6); `git diff --check`, whitespace file mới và scope checksum. Không sửa Dart nên không format/analyze lại; analyze lượt Task 03 gần nhất PASS.
- NOT RUN: MP4 mới/codec probe/720p–4K/FPS/bitrate thực, encoder init/cleanup fault injection, orientation playback, benchmark Normal/Performance và A/V sync trên thiết bị. Giữ lựa chọn người dùng chỉ host checks. AVC/HEVC vẫn chọn theo capability; không khẳng định codec cụ thể đang chạy khi chưa quay. Auto/Portrait/Landscape giữ canvas cố định và giới hạn resize đã nêu.
- **Task 04: PARTIAL / NEEDS DEVICE VERIFICATION.** Không build release, cài thiết bị, commit/push/reset hoặc thay dữ liệu/video người dùng.
