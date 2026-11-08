# TASK 07 — G0 baseline và ranh giới

07/11/2026. HEAD `b9aea926c1ab024dd32a139e5ab43b0e0e584908`, working tree có
47 thay đổi/untracked trước TASK07 (gồm implementation/evidence đợt trước và ba
tài liệu đầu vào mới). Không coi HEAD là source đã chạy. Snapshot toàn bộ file,
patch và17 hash P1/shared tại `build/verification/task07/{source_before.json,
initial_worktree.patch,p1_before.json,initial_status.txt}`. Giữ nguyên các thay đổi
có sẵn; không reset/clean/commit/push.

Đã đọc đủ ba tài liệu TASK07, AGENTS/local routing, UX contract và tám báo cáo
P2/P3 hiện hữu. Đối chiếu trực tiếp app/settings, P2/P3 widgets, UserMessages,
native MediaCatalog/VideoPreview, SubtitleOverlay và Flutter→Kotlin→JNI→Whisper.
Baseline mới: analyze sạch;143 unit/widget PASS20s (`baseline_*.log`). Báo cáo
P2/P3 cũ giữ nguyên là lịch sử; TASK07 có bộ evidence riêng.

| Source/owner | Thực trạng kiểm source | Gap TASK07 / kiểm chứng cần làm |
|---|---|---|
| app/AppConfiguration + MaterialApp |Forced English, supportedLocales chỉ en; không có i18n framework |Flutter localizations/intl/gen_l10n ARB;12 locale, English fallback, Follow system |
| SettingsController/Store v2 shared |Atomic document, preserve recordingSnapshot; theme notifier |Additive app locale + speech preference độc lập, giữ recording fields; restart/state tests |
| P2 Library/Photo/Trash/Details/Help/Support |Backend thật, copy English trong widget/shared helpers; UI dates/numbers chưa locale |Inventory literals/formatting, migrate copy và semantics;32O/411dp text200/RTL |
| P3 Editor/Effects/Audio/Layers/Subtitles/Exports |Các thao tác/export đã có, không làm lại |Localize labels/errors; giữ serialized tokens/user titles/URI/timecode; đổi locale không mất state |
| Dart transcription service/dialog |Request validate vi/en/auto; mới Base/VI; old jobs giữ model/lang |Typed engine catalog, search picker, new-job Auto, legacy unchanged; UI locale≠speech |
| Kotlin/JNI Whisper1.9.5 |Multilingual weights/real native engine; forced vi/en/auto validation; translate=false |Expose actual engine/model language availability + detected metadata; validate mọi tầng, không thêm translate UI |
| SubtitleOverlay/EditorLayers |Android StaticLayout/system fallback; UTF8 SRT; shared preview/export |Native CJK/Hindi/Arabic/bidi/emoji/combining evidence, timing/parity/file read-back |
| Native P2 preview/messages/shortcuts |Native player toast English; channel codes có sẵn |Localized native context/resources hoặc code→Flutter mapping, không đổi capture channel |
| P1 recording/**, two settings forms, Create capture |Read-only; snapshot17 files gồm MainActivity |Chỉ handoff keys; không đổi event/permission/capture semantics |
| Physical/OEM/ARM/SD/human review |Không có máy/người thử được chỉ định |NOT RUN/translation review pending; không lấy AVD/mock thay thực tế |

AST inventory khởi đầu có1825 string expressions toàn lib (gồm data tokens/P1).
File/offset/parent trong `dart_strings.json`; phân biệt copy hiển thị với URI,
keys, user text, parser tokens và P1. Không dịch enum/token làm hỏng contracts.

G0 source gaps đã xác nhận. Tiếp tục G1→G2→G3→G4→G5→G6. Các backend media,
DSP, durable drafts và offline model store hoạt động được giữ lại. Chỉ dùng
AVD QA5560/API36 và5562/API34; không thao tác trên5554 của người dùng.

G6 bổ sung AVD riêng5564/API37.1 với PAGESIZE16384; API34 chạy bằng bản sao offline,
giữ nguyên đĩa gốc. Kết quả sau triển khai ở [báo cáo cuối](TASK_07_FINAL_REPORT_VI.md)
và [evidence](TASK_07_TEST_EVIDENCE.md), không thay snapshot G0 bằng source mới.
