# TASK 15 — Recording Reliability & Conditional MP4 Recovery (F52–F53) Report

**Project:** 3HRecorder / XRecorder  
**Branch:** `feature/capture-live`  
**Owner:** P1 — Capture, Realtime & Livestream  
**Scope:** F52 — Stability, Lifecycle, Race & Leak Protection; F53 — Conditional MP4 Repair & Recovery  
**Status:** 
- **F52 (Stability / Race / Lifecycle / Leaks): FIXED LOCALLY**
- **F53 (Conditional MP4 Recovery & Inspection): PARTIAL / CONDITIONAL (ISO-BMFF Compliant)**

---

## 1. Existing Pipeline & Verified Issues

### 1.1 Phân loại Issues
| Issue ID | Severity | Phân loại | Mô tả chi tiết & Bằng chứng Code |
| :--- | :--- | :--- | :--- |
| **ISSUE-52-1** | **CRITICAL** | Concurrency / Race Condition | `CaptureService.stopCapture()` và `cancelCapture()` trước đây dùng biến `ending: Boolean` thông thường không đồng bộ. Khi có nhiều nguồn gọi Stop cùng lúc (manual Stop qua UI, Floating Ball stop, Notification action STOP, Shake-to-Stop detector, auto-stop timer, system `MediaProjection.Callback.onStop()`), có nguy cơ race condition dẫn đến double finalize, double `MediaMuxer.stop()/release()` hoặc crash process. |
| **ISSUE-52-2** | **MAJOR** | Storage & Temp Cleanup Safety | Nếu quá trình ghi hình bị ngắt đột ngột (crash/OOM/kill), các file tạm `capture_${id}.mp4` và `capture_${id}.m4a` trong cache cần được dọn dẹp có giới hạn đúng theo session ID UUID, tuyệt đối không được xóa nhầm các file MP4/PNG người dùng. |
| **ISSUE-52-3** | **MAJOR** | Idempotent Resource Release | Trong `release()`, nếu một tài nguyên ném ngoại lệ khi đóng (ví dụ `projection.stop()`, `video.abort()`), các tài nguyên phía sau (như `sensorManager`, `drawingOverlay`, `facecam`) có nguy cơ bị bỏ qua dẫn đến rò rỉ tài nguyên (leak). |
| **ISSUE-53-1** | **CRITICAL** | ISO-BMFF Missing `moov` Box Limit | Trong Android `MediaMuxer` tiêu chuẩn, bảng index mẫu (`stbl`: `stts`, `stsz`, `stco`/`co64`) chỉ được sinh trong RAM C++ và chỉ được ghi xuống đĩa trong atom `moov` khi gọi `MediaMuxer.stop()`. Nếu app bị kill trước khi finalize, file trên đĩa chỉ có `ftyp` và raw `mdat`. **Về mặt kỹ thuật, file này là UNRECOVERABLE nếu không có bảng index mẫu hoặc external checkpoint journal.** Cần cơ chế phát hiện chuẩn xác và không được tạo file giả mạo hoặc ghi đè file người dùng. |

---

## 2. Minimal Fixes & Files Changed

### 2.1 Files Changed
1. `android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/Mp4RecoveryEngine.kt` (NEW):
   - Parser thuần Kotlin cho container ISO-BMFF (MP4).
   - Phân tích và nhận diện cấu trúc box (`ftyp`, `moov`, `mdat`, `free`, `skip`), hỗ trợ cả 32-bit và 64-bit box size.
   - Triển khai Recovery Matrix và Conditional Recovery an toàn:
     - Làm việc trên file temporary cô lập (`.recovery_*.tmp`).
     - Bắt buộc kiểm tra tính hợp lệ (`inspect`) trước khi promote/commit.
     - Rollback và xóa file tạm nếu thất bại, bảo tồn 100% file gốc.
2. `android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/CaptureService.kt` (UPDATED):
   - Bổ sung `isEnding = AtomicBoolean(false)` và `isFinalizing = AtomicBoolean(false)`: đảm bảo chỉ duy nhất một thread/path thực hiện finalize hoặc teardown session.
   - Triển khai Idempotent Release: toàn bộ tài nguyên (`controls`, `drawingOverlay`, `facecam`, `imageReader`, `audio`, `video`, `display`, `projection`, `descriptor`) được release độc lập trong khối `try-catch`, gán null an toàn.
   - `captureImage()` được bảo vệ chống race condition, không bao giờ reset `ending = false` gây tái kích hoạt lỗi.
3. `android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/RecordingMuxer.kt` (UPDATED):
   - Wrap toàn bộ release trong khối `finally` bằng các khối `try-catch` riêng biệt cho `muxer`, `videoReader`, và `audioReader`.
4. `android/app/src/test/kotlin/com/xrecorder/xrecorder/recording/Mp4RecoveryEngineTest.kt` (NEW):
   - Kiểm thử toàn diện 7 kịch bản của Recovery Matrix.
5. `android/app/src/test/kotlin/com/xrecorder/xrecorder/recording/CaptureReliabilityEngineTest.kt` (NEW):
   - Kiểm thử đa luồng (8 threads đồng thời) bảo vệ atomic stop, session token validation, busy states và state snapshot integrity.

---

## 3. Terminal Transitions & Invariants Được Bảo Vệ

1. **Single Terminal Transition Invariant:**
   - Mỗi recording session chỉ có đúng 1 trạng thái kết thúc: `completed` (khi commit MediaStore thành công) hoặc `failed` (khi có lỗi) hoặc `idle` (khi bị cancel).
   - **No Fake Success:** Không bao giờ phát trạng thái `completed` hoặc sinh `Saved` event nếu `MediaOutput.commit()` chưa thành công hoặc file bị 0 bytes/corrupted.
2. **Atomic Stop Invariant:**
   - Dù lệnh Stop được kích hoạt từ Notification, Floating Ball, Shake, Auto-stop timeout, low disk hay projection onStop, `isEnding.compareAndSet(false, true)` bảo đảm chỉ 1 luồng xử lý finalize.
3. **Storage & Media Preservation Invariant:**
   - Không bao giờ xóa file media đã publish hoặc file ngoài session ID.
   - File tạm chỉ xóa đúng format `capture_${sessionId}.mp4` và `capture_${sessionId}.m4a`.
   - Nếu recovery thất bại: file tạm `.tmp` tự động bị xóa, file gốc của người dùng được bảo tồn nguyên vẹn.

---

## 4. Recovery Matrix (ISO-BMFF / Android MediaStack)

| Trạng thái file | Đặc điểm nhận diện (`Mp4RecoveryEngine`) | Khả năng phục hồi | Hành động xử lý |
| :--- | :--- | :--- | :--- |
| **VALID** | Có cả `moov` và `mdat`, box size hợp lệ, không lỗi cấu trúc. | **Không cần sửa** | Bỏ qua (`Skip`), giữ nguyên file, không duplicate. |
| **EMPTY (0-byte)** | File size = 0 bytes. | **UNRECOVERABLE** | Trả về `Unrecoverable`. Không thể tái tạo dữ liệu video từ 0 bytes. Không tạo file giả. |
| **TINY / CORRUPTED** | File size < 8 bytes hoặc header không phải ISO-BMFF. | **UNRECOVERABLE** | Trả về `Unrecoverable` (Lỗi cấu trúc container). |
| **TRUNCATED_MISSING_MOOV (Không có Journal)** | Có `mdat` nhưng thiếu `moov`. Không còn session checkpoint/temp streams. | **UNRECOVERABLE (Standard Android)** | Chuẩn ISO-BMFF: `stbl` (sample table offsets) nằm trong `moov`. Android MediaMuxer lưu bảng này trong RAM và bị mất khi kill process. Trả về `Unrecoverable`, giải thích rõ giới hạn kỹ thuật. Bảo tồn file gốc. |
| **TRUNCATED_MISSING_MOOV (Có Journal & Temp Streams)** | Thiếu `moov`, nhưng cache còn `capture_${id}.mp4` và `capture_${id}.m4a` hợp lệ. | **RECOVERABLE** | Thực hiện conditional recovery sang file tạm `.recovery_*.tmp`, chạy `inspect` xác thực; nếu PASS thì đổi tên thành output, nếu FAIL thì rollback. |

---

## 5. Kết quả Kiểm thử Local

### 5.1 Android JVM Unit Tests
- Lệnh chạy: `cd android && ./gradlew :app:testDebugUnitTest`
- Kết quả: **BUILD SUCCESSFUL**
- Số lượng test: **124/124 tests PASS (100%)**
- Bao gồm:
  - `Mp4RecoveryEngineTest` (7 tests: Empty, Tiny, Valid skip, Missing moov unrecoverable, Recovery with checkpoint, Rollback on error, 64-bit box size) — **ALL PASS**
  - `CaptureReliabilityEngineTest` (5 tests: Multi-thread stop race, Session token validation, Busy states, Terminal transitions, Failure transition) — **ALL PASS**
  - Tất cả các test trước đó: `ShakeDetectorEngineTest`, `TouchIndicatorEngineTest`, `AudioDuckingEngineTest`, `AudioVideoMathTest`, `CaptureJournalTest`, `CaptureNotificationPolicyTest`, `CaptureRequestsTest`, `CaptureTimingTest`, `DrawingStrokeEngineTest`, `FacecamGeometryTest`, `FloatingControlGeometryTest`, `RegionCropGeometryTest`, `ScreenshotPixelsTest`, `VideoBitrateTest` — **ALL PASS**

### 5.2 Flutter Unit & Widget Tests
- Lệnh chạy: `/home/hieu/Documents/development/flutter/bin/flutter test --no-pub`
- Kết quả: **183/183 tests PASS (100%)**
- Zero regressions trên toàn bộ luồng recording, cancel, settings, library, editor.

### 5.3 Static Analysis & Whitespace Check
- `flutter analyze --no-pub`: **No issues found!**
- `git diff --check`: **Clean (0 errors, no whitespace issues).**

---

## 6. UI & Icon Freeze Check

- Widget tree: **KHÔNG THAY ĐỔI (0 diff)**.
- Layout, themes, colors, typography, routes, icons: **KHÔNG THAY ĐỔI (0 diff)**.
- Strictly Functionality Only.

---

## 7. Kết luận Độc lập F52 & F53

1. **F52 — Stability / Lifecycle / Race / Leak Protection:** **FIXED LOCALLY**
   - Đã loại bỏ triệt để race conditions giữa mọi nguồn kích hoạt Stop.
   - Resource release an toàn, idempotent, chống rò rỉ bộ nhớ và unhandled exceptions.
   - Storage safety và MediaStore commit đảm bảo atomicity cao nhất.
2. **F53 — Conditional MP4 Repair & Recovery:** **PARTIAL / CONDITIONAL**
   - Đã xây dựng engine kiểm tra container ISO-BMFF chính xác, phân biệt rõ file hợp lệ, file 0-byte, file hỏng và file dở dang.
   - Khôi phục có điều kiện thành công với các session còn stream checkpoint hợp lệ kèm cơ chế rollback an toàn.
   - Báo cáo trung thực: đối với file MP4 mất `moov` mà không có sample table index, chuẩn Android/ISO-BMFF không cho phép phục hồi an toàn mà không dùng công cụ chuyên sâu từ bên thứ ba (như untrunc/ffmpeg với donor file).
