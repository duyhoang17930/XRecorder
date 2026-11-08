# 3HRecorder — Trạng thái chức năng và bàn giao P1/P2/P3

**Ngày đối chiếu:** 07/11/2026  
**Nguồn:** 10 báo cáo P2/P3 do chủ dự án cung cấp; current quality baseline `b9aea926c1ab024dd32a139e5ab43b0e0e584908` trong báo cáo.  
**Mức chứng nhận:** Đây là tổng hợp **bằng chứng do Codex báo cáo**; chưa phải audit độc lập từ source/APK và logs gốc.

## 1. Trả lời thẳng

> **Theo báo cáo, toàn bộ nhóm backend/chức năng P2/P3 đã được phân công trong M0–M6 đều được triển khai và có automated/native QA. Nhưng chưa thể khẳng định toàn bộ ứng dụng tham chiếu đã hoàn thiện 100%, hoặc cả app đã đủ điều kiện nghiệm thu trên máy thật.**

**Không phải chờ P1 để viết nốt tính năng P2/P3.** Các dependency hiện mở chủ yếu là **end-to-end integration** của video/audio/screenshot thực tế từ P1 vào P2 rồi P3, cùng shared Create/capture settings mà người 1 sở hữu.

## 2. Ma trận chức năng theo owner

| Owner/nhóm | Tính năng | Trạng thái theo báo cáo 07/11 | Chưa thể kết luận |
|---|---|---|---|
| P2 F24–26 | Library ảnh/video, lazy load, search, 5 sorts, observer, cache, empty/search states | **IMPLEMENTED; API36 native + UI QA** | Máy thật/OEM/SD, 60fps |
| P2 media | File SAF, copy/move xác thực SHA256, Trash/Restore, rename, content grants | **IMPLEMENTED; DocumentsUI fixture PASS** | Revoke grants/OEM/SD, disk-full/power loss |
| P2 F49 | Edit/Photo shortcuts, pinned shortcuts | **IMPLEMENTED; launcher QA PASS** | OEM/launcher đa dạng |
| P3 F27–30 | Video + still-image timeline, trim/split/reorder/duplicate/merge, flip/rotate/crop/relink, speed | **IMPLEMENTED; MP4 output QA PASS** | Captured files từ P1 và device/codec rộng |
| P3 F31–32 | Text, sticker vector, drawing layers, position/size/rotation/timing/order | **IMPLEMENTED; preview/export pixel comparison PASS** | Human usability và script/font toàn cầu |
| P3 F19/F33 | 8 audio tracks, trim, align, fades, volume/headroom, deep/bright/robot | **IMPLEMENTED; audio signal tests PASS** | Human listening/device audio diversity |
| P3 F34 | Autosave draft, undo/redo, recovery corrupt/backup, relink | **IMPLEMENTED; process kill + AtomicFile fixtures PASS** | Exact power-loss/disk-full matrix |
| P3 F35–38 | MP4/GIF, bitrate/size/loop, export queue/cancel/retry, publication | **IMPLEMENTED; native decode/queue PASS** | Exact mid-commit process death, devices rộng |
| P3 Photo | Crop/pen/shape/text/arrow/flip/rotate, EXIF 1–8, sRGB, PNG/JPEG/resize | **IMPLEMENTED; pixel QA PASS** | HDR, accessibility thực tế nếu sản phẩm yêu cầu |
| P3 F40 | RNNoise offline | **IMPLEMENTED; spectral/signal QA PASS** | Người nghe đánh giá và thermal/battery |
| P3 F41 | whisper.cpp offline Tiny/Base/Small-q5_1, download/import/delete, cancel/jobs | **IMPLEMENTED; 35 actual inferences/12 stimuli** | ASR global: hiện app contract `vi/en/auto`, độ chính xác mọi ngôn ngữ chưa chứng nhận |
| P3 F42 | Cue editor, generated/manual, style, SRT, burn-in | **IMPLEMENTED; exported SRT/MP4 PASS** | CJK/Arabic/Hindi shaping, RTL, font fallback, localization |
| Shared P2/P3 | Basic accessible controls, responsive 320/411dp, text 200%, light/dark | **Automated native/widget QA PASS** | Human TalkBack focus/gesture, ergonomics |
| P1 do người 1 | Screen recording native, audio capture source, capture configuration, Facecam/capture overlays, controls | **NOT ASSESSED HERE** | Chỉ chủ P1 có thể chốt feature completeness/native QA |

**Ghi chú về các mã F:** Các F-number là mã feature theo báo cáo master prompt hiện hữu, không tự suy diễn rằng chúng bao phủ mọi chức năng của một ứng dụng XRecorder thương mại. Muốn tuyên bố parity 100% với app tham chiếu phải có **một master feature inventory độc lập từng thao tác**, hiện chưa có trong bộ 10 file này.

## 3. Những chỗ P2/P3 dính P1 nhưng chưa nghiệm thu được

| Điểm giao | Phía đã có | Điều cần chờ P1 | Tiêu chí PASS cuối cùng |
|---|---|---|---|
| **P1 → P2 save event** | `CaptureController(onSaved: media.refresh)` và MediaStore observer | P1 tạo video/screenshot thật trên final build | Quay xong → URI hợp lệ → Library hiển thị đúng một bản, không cần restart |
| **Format/metadata** | P2 đọc URI/rotation; P3 timeline/decoder | Mẫu video quay thật với các tổ hợp mic/internal/mixed, rotation, Facecam nếu P1 hỗ trợ | Chạy full decode, duration/orientation/audio hợp lệ; không crash/black preview |
| **P2 → P3 edit** | `MediaScope`/`CatalogRepository.list/find` → `MediaItem.uri` → Editor | Nguồn capture hoàn chỉnh | Chọn bản ghi mới → trim/effects/audio/subtitle → export MP4 → mở và phát được |
| **P3 → P2 export** | MediaStore publish/observer/refresh, cancel/retry | Kiểm tra bản ghi P1 xuất phát ở nguồn thực tế | Một entry mới, không duplicate, nguồn gốc bảo toàn, file tồn tại sau process restart |
| **Shared Create UI** | `studio_create_sheet.dart` chứa capture UI | UI/capture semantics thuộc P1; ownership do người 1 giữ | Button Create/Record/Photo/Edit đúng đích, không phá route/permission/back gesture |
| **Recording settings** | `SettingsController`/Store v2 phía shared | Các settings capture do P1 sở hữu | Locale/system preference không làm đổi recording codec/audio/quality semantics |
| **Full app smoke** | Main APK routes Video/Photo/Editor/Settings đã được kiểm | Chạy consent/start/pause/resume/stop/capture/Facecam trên final P1 build | End-to-end không mất media, không leak, không crash, thao tác thật được |

**Kết luận phụ thuộc:** P2/P3 **không phải đang thiếu một editor/ASR/storage backend vì P1 chưa xong**. Phần chờ P1 là **bằng chứng integration và ownership của capture UI/settings**. Nếu người 1 đổi API/event/URI thì cần phối hợp và chỉ sửa adapter/contract của đúng owner, không chọc thẳng vào pipeline capture.

## 4. Đang mở nhưng KHÔNG phải vì P1

1. **Globalization (TASK 07):** giao diện nhiều locale, Whisper đa ngôn ngữ hơn `vi/en/auto`, Unicode subtitles/CJK/Arabic/Hindi, human translation review.
2. **Device performance (TASK 08):** raster p95 trên SwiftShader 43.711→40.515ms, vẫn vượt 16.67ms cho 60Hz; cần kiểm chứng máy thật ARM/RAM/thermal/battery.
3. **HCI/QA thực tế (TASK 09):** TalkBack human focus/gesture, thao tác một tay, listening ASR/audio, API24–35 và OEM/SD provider matrix.
4. **Reliability nâng cao:** actual ENOSPC/power loss/exact MediaStore commit-window kill chưa được chạy; historical fault tests không thay thế physical gate.
5. **Reference-feature parity:** chưa có đối chiếu một-một tất cả chức năng app XRecorder tham chiếu; không nhận `100% equivalent` chỉ từ M0–M6.

## 5. Số liệu nghiệm thu hiện có

| Hạng mục | Bằng chứng được báo cáo | Kết luận đúng phạm vi |
|---|---|---|
| Flutter analyzer | Clean | PASS trên source checkpoint đó |
| Flutter widget/unit | 143 PASS | PASS automated only |
| Native Android JUnit | 3 PASS | PASS sample assertions |
| Native audio/layer/media | 12 H264/AAC outputs và các fixture input/codec, full decode | PASS đối với fixtures được chạy |
| AI Whisper | 38 jobs/35 real inferences; 12 stimuli | Có engine thật; quality global chưa chứng nhận |
| ASR ngôn ngữ Việt | Tiny WER ~54.63%, Base ~34.09%, Small-q5_1 ~16.15% trên sample nhỏ | Cần user review; không cam kết từng quốc gia/giọng |
| Emulator | API36 broad QA + API34 subset | Chưa có runtime ARM64/ARMv7 hoặc OEM |
| Release APK | ~64,954,063 bytes, unsigned, 3 ABI | Static packaging PASS, runtime signed release NOT RUN |
| Performance | Median per-trial raster p95 43.711→40.515ms | Có cải thiện nhỏ; chưa chứng minh 60fps |
| P1 source | 16 file hash không đổi ở quality checkpoint | Không đồng nghĩa P1 native runtime PASS |

## 6. Gate để tuyên bố "app hoàn thiện"

- [ ] P1 owner bàn giao ready build/contract, native recording smoke thực hiện thật.
- [ ] P1→P2→P3 e2e consent→capture→library→edit→export trên máy thật/thiết bị QA được cấp quyền.
- [ ] TASK 07 localization + subtitles multilingual có implementation/evidence; review bản dịch được ghi đúng trạng thái.
- [ ] TASK 08 baseline/retest về FPS/RAM/storage/thermal/battery và device/API matrix.
- [ ] TASK 09 human one-hand/audio/TalkBack, data integrity và recovery gates.
- [ ] Feature-by-feature parity checklist so với app tham chiếu (nếu đây là tiêu chí chấp nhận bắt buộc của chủ dự án).
- [ ] Tất cả crash/data-loss bug nghiêm trọng được đóng hoặc nhận rủi ro minh bạch.

Billing/ads/Pro/Play publishing thuộc nhóm khác, **không dùng chúng làm blocker cho scope xây app**.

## 7. Quy tắc làm việc song song

1. Người 1 sở hữu P1 capture/native recording/settings và nhánh Create capture.
2. Người đang đảm nhiệm P2/P3 có thể tiếp tục TASK 07–09 mà không phải đợi P1, trên ranh giới file/contract đã nêu.
3. Khi hai bên cùng làm localization hoặc shared routes, chỉ trao đổi key/interface, không ghi đè file của nhau.
4. Khi có P1-ready build: freeze hai phía, chạy hợp nhất, test lại source/media/export thật, rồi mới gọi TASK10 PASS.
5. Không tự commit/merge/push trong Codex khi owner chưa yêu cầu; không mất user changes/drafts/models.

## 8. Nguồn gốc tài liệu để đối chiếu

- `P2_P3_CURRENT_AUDIT.md`: các feature và trạng thái.
- `P2_P3_MASTER_PROGRESS.md`: M0–M6 quality gates.
- `P2_P3_CONTRACTS.md`: boundaries, request codes, source/events, ASR API.
- `P2_P3_TEST_EVIDENCE.md`: chính xác test nào chạy, failures và limitations.
- `P2_P3_DEVICE_MATRIX.md`: thiết bị nào chạy và NOT RUN.
- `P2_P3_AI_SUBTITLE_EVALUATION.md`: ASR corpus/CER/WER/RTF.
- `P2_P3_FINAL_QUALITY_REPORT_VI.md`: báo cáo nghiệp thu được cung cấp.

**Status tổng hợp:** `P2/P3 FEATURE IMPLEMENTATION: REPORTED COMPLETE` · `P2/P3 PRODUCTION QA: PARTIAL` · `P1 RUNTIME: NOT ASSESSED` · `P1→P2→P3 INTEGRATION: OPEN` · `GLOBAL READINESS: TASK07 PENDING`.
