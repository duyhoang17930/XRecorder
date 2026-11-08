# TASK 07 — GLOBAL READINESS, INTERNATIONALIZATION & MULTILINGUAL AI

**Dự án:** 3HRecorder / XRecorder (Flutter + Android native)  
**Ngày lập:** 07/11/2026 · **Người thực hiện:** Codex GPT-6 Astra · **Reasoning đề xuất:** Extra High / xhigh  
**Loại công việc:** Audit → implement phần thiếu → native verification → báo cáo. Không phải một task chỉ viết kế hoạch.

## 0. Mệnh lệnh và mục tiêu

Bạn tiếp quản **TASK 07** trên **working tree hiện tại** của 3HRecorder. Hãy biến P2/P3 từ một bộ chức năng đã triển khai thành trải nghiệm **global-ready**, đồng thời **giữ nguyên tất cả thành quả hiện có**.

Đọc kỹ các tài liệu đang có trong repo trước khi hành động:

1. `P2_P3_CONTRACTS.md`
2. `P2_P3_CURRENT_AUDIT.md`
3. `P2_P3_MASTER_PROGRESS.md`
4. `P2_P3_TEST_EVIDENCE.md`
5. `P2_P3_FINAL_QUALITY_REPORT_VI.md`
6. `P2_P3_DEVICE_MATRIX.md`
7. `P2_P3_AI_SUBTITLE_EVALUATION.md`
8. `REUSE_REGISTER.md`
9. Tài liệu phạm vi và handoff P1/P2/P3 đính kèm prompt này.

Các tài liệu là **bằng chứng lịch sử**, không được mặc định rằng mã đang chạy ở HEAD trùng hoàn toàn với chúng. Xác minh code và trạng thái working tree hiện tại trước. Nếu file đổi tên/chưa có, tìm theo nội dung; ghi rõ nguồn thực tế.

### Success definition

- Người dùng từ nhiều quốc gia có thể hiểu giao diện, chọn ngôn ngữ ứng dụng và thao tác trọn vẹn với P2/P3.
- Phụ đề nhập thủ công và phụ đề sinh bởi Whisper có thể xử lý đúng các hệ chữ khác nhau trong **preview, edit, SRT, MP4**.
- Whisper sử dụng danh sách ngôn ngữ thực sự được hỗ trợ bởi **multilingual model hiện có**, thay vì cố định UI/API chỉ `vi/en/auto`.
- Tôn trọng khả năng người dùng chọn **ngôn ngữ nói khác ngôn ngữ giao diện**.
- Không hồi quy capture P1, media source, drafts, saved jobs, performance và thao tác cũ.
- Chỉ dùng trạng thái `DONE` khi có implementation + evidence; ngôn ngữ chưa được người bản ngữ kiểm tra phải ghi `TRANSLATION REVIEW PENDING`, không được nhận là đã chứng nhận bản dịch.

## 1. Ownership và giới hạn bất biến

**P1 do một người khác phụ trách và đang có khả năng thay đổi song song. KHÔNG sửa hoặc tái cấu trúc P1.**

Read-only trong TASK 07:

- `lib/features/recording/**`
- `android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/**`
- `lib/features/settings/recording_settings_form.dart`
- `lib/features/settings/audio_video_settings_screen.dart`
- `lib/core/widgets/studio_create_sheet.dart` đối với capture UI và semantics.
- Native capture channels, capture event contracts, recording muxer và capture settings.

`MainActivity` nếu thực sự cần sửa chỉ được thêm thay đổi **P2/P3-specific** và phải chứng minh không ảnh hưởng registration/callback P1. Không tùy tiện thay global request-code/channel dispatch. P2/P3 activity requests `1701–1705`, P1 permission requests `702–706`; `704` của SupportBridge activity result nằm namespace callback khác — không tự coi là collision.

Nếu localization P1 đòi sửa màn hình thuộc người 1, **không sửa**, chỉ lập danh sách key và handoff/PR proposal trong `TASK_07_P1_I18N_HANDOFF.md` cho chủ P1. Có thể làm localization shared shell ở nơi thuộc phạm vi chung **chỉ sau khi chứng minh không động vào capture semantics**. Không tự giải quyết conflict bằng cách ghi đè code đang được người 1 phát triển.

**Không:** commit, push, PR, publish, ký APK, truy cập release credentials, xóa media/drafts/models/reference fixtures, uninstall/clear-data/wipe emulator của người dùng, dọn 24GB project hay nâng dependencies không liên quan.

**Không thuộc scope:** billing/ads/Pro F54–F56, Play Console, chi phí, pháp lý phát hành (nhóm khác làm). Vẫn phải giữ bản quyền/attribution metadata của source được reuse.

## 2. G0 — Audit thật trước khi triển khai

1. Chạy read-only `git status --short`, `git branch --show-current`, `git rev-parse HEAD`. Ghi nhận các thay đổi có sẵn; tuyệt đối không reset/clean.
2. Lập **feature/locale inventory** từ mã thực: mọi screen, route, dialog, SnackBar, tooltip, empty/loading/error, permission rationale, accessibility semantics, notifications, Kotlin resources, MediaStore/export messages và ASR controls.
3. Đối chiếu với tài liệu để phân nhóm `already supported`, `needs implementation`, `needs native verification`, `P1-owned`, `outside scope`.
4. Audit cụ thể ASR Flutter → platform channel → Kotlin/JNI → whisper.cpp v1.9.5: danh sách ngôn ngữ, validation, forced default `vi`, job restore, model type và detection logic.
5. Audit font/UI, `Directionality`, RTL, preview painter/render, Media3 TextOverlay/burn-in, SRT UTF-8, filename SAF, text length/word-wrap và selection.
6. Audit cơ chế cài ngôn ngữ hiện có; **không tạo framework i18n song song** nếu dự án đã có.
7. Snapshot/trích hash hoặc patch view các file P1 trước khi đụng repo; cuối task chứng minh **chính task này không thay P1**. Vì P1 có thể được sửa song song, không giả định diff về commit cũ là bằng chứng đủ.

Xuất `TASK_07_BASELINE_AUDIT.md` có bảng file/owner/status/gap/verification. Sau G0, triển khai ngay các gap không bị chặn; chỉ dừng để hỏi nếu phát hiện mâu thuẫn quyền sở hữu hoặc quyết định sản phẩm không thể suy ra.

## 3. G1 — Kiến trúc localization bền vững

**Dùng Flutter chuẩn:** `flutter_localizations`, `intl` và `gen_l10n`/ARB (hoặc hệ thống sẵn có nếu tương đương), không viết `if(language == ...)` rải rác.

### Locale mục tiêu ban đầu

`en`, `vi`, `es`, `pt_BR`, `fr`, `de`, `id`, `ja`, `ko`, `zh_Hans`, `hi`, `ar`.

**Quy tắc:**

- `en` làm source locale và fallback khi thiết bị chọn ngôn ngữ chưa hỗ trợ.
- Mặc định là **Follow system**. Settings cho chọn thủ công; thay đổi được lưu và restore qua settings hiện có theo kiểu additive, backward-compatible.
- Không ép `AI speech language = UI locale`; chúng là hai settings độc lập.
- Dịch toàn bộ P2/P3 và shell/navigation được phép sửa: menu, buttons, titles, settings P2/P3, dialogues, tooltips, validation messages, voice/speed/bitrate labels, date/duration/file-size formatting, media actions, errors, notifications, accessibility label/hint/value, empty states, model manager và ASR states.
- Các thông báo từ Kotlin phải có error code ổn định; dịch ở Flutter nếu phù hợp; giữ log kỹ thuật bằng tiếng Anh và không lộ stacktrace vào UI.
- Pluralization, placeholders, khoảng trắng, giờ/ngày, number grouping, `%`, thập phân, kích thước file và số đo theo locale. Duration/timecode kỹ thuật phải rõ, nhất quán và không bị locale làm hỏng parser.
- Không để hardcoded copy hoặc English string ngầm trong UI được tuyên bố localized. Dùng script/lint kiểm kê những vị trí còn lại; ngoại lệ được giải thích.
- Không chạy translator tự động rồi coi bản dịch là chuẩn. Có thể tạo draft có kiểm tra glossary, nhưng đánh dấu `REVIEW PENDING` theo từng locale nếu chưa có human review.
- English source strings, localization keys, placeholder descriptions và glossary cần có tài liệu cho người review bản dịch.

### Chất lượng giao diện

- Locale `ar` phải hỗ trợ RTL cho **UI điều hướng** mà không lật hình/video, timeline frame order, waveform, crop canvas hay tọa độ thao tác. Chỉ mirror directional icons nơi đúng semantics.
- Các script CJK, Devanagari và Arabic phải có glyph, shaping, line-break và bidi đúng; cân nhắc system font fallback trước khi bundle font lớn làm tăng APK.
- Độ dài bản dịch tăng 30–70% vẫn không overflow; kiểm tra 320/360/411dp, text scale 100/150/200%, orientation, keyboard, landscape nếu màn đó hỗ trợ, Light/Dark và gesture back.
- Layout không che nút Export/Save/Cancel; tap target, TalkBack labels và keyboard navigation nhất quán.
- Chuyển ngôn ngữ khi đang mở draft/editor không làm mất project, scroll, timeline playhead, undo history hoặc job đang chạy; không reload media vô cớ.

## 4. G2 — Whisper multilingual thực sự (F41)

**Reuse:** whisper.cpp v1.9.5 và model Tiny/Base/Small-q5_1 multilingual đã được tích hợp. Không thay engine hoặc tải toàn bộ weights vào APK. Giữ offline-first, download/import theo lựa chọn, SHA256/size, job progress/cancel, RAM preflight, model deletion guard, persisted job recovery và ngưỡng 10 phút hiện hữu.

### Bắt buộc làm

1. Xác định tập ngôn ngữ hợp lệ mà multilingual model/engine hiện có hỗ trợ. Xây một typed language catalog với `code`, native code, localized display name, English fallback name, auto-detect option, availability. Không quảng cáo ngôn ngữ không được engine hỗ trợ.
2. Thay validation `vi/en/auto` ở UI, Dart, Kotlin/JNI và serialization theo contract versioned/additive. Cũ `vi/en/auto` vẫn mở lại đúng; job không có language → `auto` nếu quy tắc legacy hiện tại yêu cầu. Không migrate phá dữ liệu.
3. UI Language picker có search, danh sách dễ hiểu và ghi nhớ lựa chọn. Auto Detect là lựa chọn mặc định **cho job mới** theo mục tiêu global; **không tự đổi job/draft đã tạo**. Nếu hiện tại mặc định `Base/VI`, thay đổi có regression test và viết rõ migration.
4. Model picker giữ `Base` là balanced recommendation khi có; fallback model đã cài nếu chưa tải Base. Không nói Small luôn chính xác hơn trong mọi trường hợp.
5. Phân biệt `transcribe` (ngôn ngữ gốc) với `translate`; không vô tình chuyển lời nói nước ngoài thành tiếng Anh. Nếu engine hỗ trợ translate nhưng tính năng chưa được định nghĩa/kiểm thử, không tự thêm toggle giả.
6. Input silence/music/no-speech phải tránh transcript rác; giữ digital silence fast-path. Không nhận định Auto Detect luôn chính xác. Có warning và bước **Review subtitles** trước khi burn-in/export.
7. Không upload file audio lên server/API trả phí; không tạo endpoint giả. Không đưa model weights, data corpus người dùng hay transcript vào logs/telemetry.
8. Progress/cancel, process restart, model remove/re-download, bad URI, job queue full, document permissions, low RAM và cancellation after editor close phải ổn định cho mọi ngôn ngữ.

### Verification

- Test ngôn ngữ native tối thiểu: `en`, `vi`, `es`, `pt`, `fr`, `de`, `id`, `ja`, `ko`, `zh`, `hi`, `ar` nếu model thực hỗ trợ, cộng Auto Detect.
- Mỗi ngôn ngữ cần ít nhất một mẫu lời nói thật có reference và ghi nguồn, nhưng **1 mẫu không đủ để chứng nhận chất lượng tổng quát**. Với ngôn ngữ chưa có corpus, để `NOT VERIFIED` (không bịa reference).
- Tách CER/WER theo script và phép normalize; với CJK phải giải thích cách tokenization, không so sánh WER bất công giữa hệ chữ.
- Benchmark Tiny/Base/Small trên subset đại diện, đo latency, RTF, peak RAM/PSS, cancel responsiveness, false-positive trên music/noise; giữ logs và generated SRT để audit.
- Không ghi `GLOBAL ASR PASS` chỉ vì unit test, một ngôn ngữ hoặc auto-detect trả text.

## 5. G3 — Phụ đề đa hệ chữ và xuất file (F42/P3)

Kiểm thử **end-to-end** cho:

- Latin + dấu: English, Vietnamese, Spanish, Portuguese, French, German, Indonesian.
- CJK: Chinese (Simplified), Japanese, Korean.
- Devanagari: Hindi.
- RTL/Bidi: Arabic, kết hợp số Latin, thời gian và ký tự trái/phải trong cùng cue.
- Emoji, combining marks, Unicode normalization, xuống dòng, script-mixed, từ dài, không có khoảng trắng, ký tự điều khiển, empty/overlap/range và text dài ở giới hạn hiện tại.

Giữ workflow `manual/generated cue → preview → edit/split/merge/style → SRT UTF-8 → MP4 burn-in`.

Yêu cầu preview/export parity bằng frame/pixel evidence; bảo toàn thời điểm khi speed/trim/reorder; font fallback và shaping không làm thay đổi image/video source. SRT Unicode read-back phải đúng byte/content sau picker, không biến Unicode thành dấu `?`, không mất xuống dòng hay timestamp. Nếu style/renderer không hỗ trợ một hệ chữ, **nêu gap và khắc phục thực sự** trước khi đánh DONE.

## 6. G4 — HCI toàn cầu và tính nhất quán của app

- Soát P2 Library, Photo, Video Editor, Effects, AI dialog, Export Queue, Drafts, Trash/Restore, Settings và bottom navigation bằng device matrix.
- Cải thiện các lỗi thực đo: overflow, clipped dialog, action bị che, tap area quá nhỏ, focus order, language picker search, confusing model download/storage consent, save/export progress.
- Thống nhất thông báo progress/success/error/cancel/retry, không ghi Saved trước khi actual MediaStore commit.
- Kiểm thử source/output integrity khi đổi locale và khi ngôn ngữ trong SRT khác UI language.
- Không làm animation hay layout refactor lớn thiếu evidence; không thêm dependencies chỉ để đẹp hơn.
- Nếu có shared Create/capture UI text thuộc P1, lập **handoff key list**; không can thiệp behavior người 1.

## 7. G5 — App size và tài nguyên (READ-ONLY size audit)

Hiện docs ghi APK debug ~192 MB, unsigned release ~65 MB (3 ABI), workspace PC có thể ~24 GB do build/QA/models. **Không suy ra 24 GB sẽ được cài lên thiết bị.**

- Chạy breakdown read-only các thư mục lớn, phân loại source/cache/QA fixtures/models/user media, kèm bytes và top offenders.
- Dùng Flutter release size analysis và per-ABI assessment nếu môi trường phù hợp; không đánh đồng uncompressed APK với on-device installed size.
- Kiểm tra assets/font/localization làm tăng APK bao nhiêu; tránh bundle model AI và unnecessary font packs.
- Đo disk của downloaded model, drafts, temporary audio render, export files và thumbnail caches bằng QA fixtures; kiểm tra orphan/duplicate artifacts.
- **Không `flutter clean`, `git clean`, xóa `build`, xóa media/model đã có hoặc dọn user-data** để cải thiện số đo nếu chưa có quyền và danh sách chính xác.
- Viết `TASK_07_SIZE_REPORT.md` có baseline/after và recommendations; chỉ tối ưu các phần an toàn trong phạm vi task.

## 8. G6 — Regression, thiết bị và mức độ tin cậy

### Minimum gates

1. `flutter analyze --no-pub` clean; `flutter test --no-pub --reporter expanded` pass hoặc nêu blocker.
2. Android native tests liên quan i18n, Unicode/SRT, error mapping, ASR language validation.
3. ARB generation/key parity/placeholder/plural validators; missing keys fail CI hoặc test tương đương.
4. Widget/golden/layout screenshot matrix: 12 locales × representative screens; deep focus `ar`, `ja`, `zh_Hans`, `hi`, long `de/fr`, device 320/411dp, text 200%, Light/Dark.
5. Native ASR vi/en baseline không hồi quy, multilingual real inference theo corpus sẵn có và các samples mới có nguồn. Cancellation/progress/persisted jobs/empty-speech checks.
6. Real subtitles: original Unicode → cue edit → SRT file read-back → MP4 visible at correct timestamps. Preview/export parity evidence.
7. Real SAF Unicode filenames, no grants, permission revoked, storage preflight; no double publication, preserve source bytes and old drafts.
8. Kiểm tra release packaging 16KB alignment/ABI và APK `lib/main.dart`; **16KB static PASS không tương đương runtime 16KB PASS**.
9. Ít nhất một test reopen existing English/Vietnamese drafts, transcript and jobs created before TASK 07.
10. Check `git diff --check`, `git diff --stat`, P1 files hash/diff relative to TASK07 start snapshot. Ghi mọi unrelated changes là user-owned.

### Test environment safety

- Ưu tiên isolated QA AVD vốn có (`ThreeHRecorder_Task021`/API36 và `ThreeHRecorder_Final_API34` nếu còn tồn tại), không dùng emulator cá nhân `emulator-5554`/API37 để ghi dữ liệu, cài APK, clear-data, wipe hoặc đổi settings.
- Device/ABI/OEM/SD/thermal/human testing không có điều kiện thực thì ghi `NOT RUN`, không tạo chứng cứ giả. Có thể thực hiện non-destructive host tests thay thế, nhưng không đánh thành equivalent.
- Performance Flutter raster p95 trước đó 43.711→40.515ms trên SwiftShader: giữ đúng thực tế, không hứa 60fps. Đo kiểm chứng không hồi quy khi đổi locales bằng cùng corpus.
- P1→P2→P3 native recording flow chỉ nghiệm thu sau khi P1-ready build được người 1 bàn giao; TASK07 không tự gọi capture hoặc đổi recording pipeline.

## 9. Tài liệu bàn giao BẮT BUỘC

Tạo/cập nhật riêng trong repo, không ghi đè báo cáo cũ:

1. `TASK_07_BASELINE_AUDIT.md` — source of truth, owner, gap, affected files.
2. `TASK_07_GLOBALIZATION_MATRIX.md` — mỗi locale, UI status, RTL/font, subtitle/SRT/burn-in, ASR status, evidence, human review status.
3. `TASK_07_ASR_CONTRACT_AND_BENCHMARK.md` — engine/model/lang/API changes, legacy migration, corpora/licenses, CER/WER/RTF, limitations.
4. `TASK_07_P1_I18N_HANDOFF.md` — yêu cầu text/UI thuộc P1 cho người 1, không áp patch vào P1.
5. `TASK_07_SIZE_REPORT.md` — disk tree, APK baseline/delta, fonts/models/cache.
6. `TASK_07_TEST_EVIDENCE.md` — test commands, exit codes, logs/PNG/MP4/SRT paths, failures và retests, devices.
7. `TASK_07_FINAL_REPORT_VI.md` — tính năng đã chạy thật, còn partial, blocked/external, source diff, APK QA nếu build, handoff cho TASK08/09/10.

Ghi **evidence** cho từng `DONE`; không nói "all global languages supported" nếu chỉ UI có option. Phân biệt code implemented, automated verified, physical verified và human translation signed off.

## 10. Cách làm việc và báo cáo

- Thực hiện theo thứ tự **G0 → G1 → G2 → G3 → G4 → G5 → G6**; checkpoints ngắn sau mỗi phase, tiếp tục không cần xin phép trừ khi quyền sở hữu/P1 hoặc thay đổi phá dữ liệu bị vướng.
- Ưu tiên sửa code + kiểm chứng thật, không dừng ở plan. Test red không được giấu; phân biệt harness flake với product failure và chứng minh khi rerun.
- Hạn chế tối đa native dependency mới. Reuse Flutter i18n và Whisper/Media3 đã pin; chỉ nghiên cứu repo khác khi có gap chứng minh được, lưu URL/tag/commit/license, tradeoff và attribution vào reuse register.
- Nếu môi trường không đủ thời gian/context, kết thúc với checkpoint và bảng `DONE/PARTIAL/BLOCKED/NOT RUN`, **không tự nhận task hoàn tất**.
- Không xóa/ghi đè file untracked do người khác tạo. Không giả lập success từ mock UI nếu chức năng cần native output.

### Output cuối cùng cho chủ dự án

Viết bằng **tiếng Việt**: `1) Đã làm`, `2) Cái gì chưa`, `3) Có thay P1 không`, `4) 12 locales thực trạng`, `5) ASR language coverage`, `6) file size`, `7) test evidence`, `8) QA APK`, `9) blockers`, `10) next task`.

**Bắt đầu bằng audit working tree và triển khai, đừng chỉ gửi đề xuất.**
