# TASK 07 — Global QA Checklist & Acceptance Matrix

**Ngày:** 07/11/2026 · **Áp dụng:** P2/P3, Flutter i18n, offline Whisper, subtitle renderer.  
**Nguyên tắc:** `NOT RUN` là trạng thái hợp lệ; không điền PASS khi chưa có artifact thật. P1 chỉ nhận handoff không sửa implementation.

## A. Locale matrix để Codex điền bằng chứng

Checkpoint08/11/2026 cho P2/P3; P1 chỉ handoff. Bằng chứng theo từng locale nằm
trong [matrix](implementation/TASK_07_GLOBALIZATION_MATRIX.md),
[native/widget/SRT/MP4 evidence](implementation/TASK_07_TEST_EVIDENCE.md) và
[ASR corpus/metrics](implementation/TASK_07_ASR_CONTRACT_AND_BENCHMARK.md).
PASS tự động không thay human/physical acceptance. G6 performance còn OPEN;
main-entry APK đã kiểm API36/16KB và4 native focus targets với TalkBack hoạt động;
không tuyên bố toàn app hoàn thành hoặc human accessibility PASS.

| Locale | UI + native messages | Text 200%/320dp | Subtitle preview + SRT + MP4 | ASR real speech | Human translation review |
|---|---|---|---|---|---|
| en | PASS P2/P3 | PASS automated | PASS automated | Tiny/Base/Small fixed; Base Auto PASS | NOT RUN (source English) |
| vi | PASS P2/P3 | PASS automated | PASS automated | Tiny/Base/Small fixed; Base Auto PASS | PENDING |
| es | PASS P2/P3 | PASS automated | PASS automated | Base fixed/Auto functional PASS | PENDING |
| pt_BR | PASS P2/P3 | PASS automated | PASS automated | Portuguese Base fixed/Auto functional PASS | PENDING |
| fr | PASS P2/P3 | PASS automated | PASS automated | Base fixed/Auto functional PASS | PENDING |
| de | PASS P2/P3 | PASS automated | PASS automated | Base fixed/Auto functional PASS | PENDING |
| id | PASS P2/P3 | PASS automated | PASS automated | Base fixed/Auto functional PASS | PENDING |
| ja | PASS P2/P3 | PASS automated | PASS automated | Base fixed/Auto functional PASS; quality limited corpus | PENDING |
| ko | PASS P2/P3 | PASS automated | PASS automated | Base fixed/Auto functional PASS | PENDING |
| zh_Hans | PASS P2/P3 | PASS automated | PASS automated | PARTIAL quality: model may output Traditional | PENDING |
| hi | PASS P2/P3 | PASS automated | PASS automated | PARTIAL: Base wrong script; Small Devanagari observed | PENDING |
| ar (RTL) | PASS P2/P3 +RTL | PASS automated | PASS automated | Base fixed/Auto functional PASS | PENDING |

**Không giữ chữ `Historical EN/VI only` sau khi đã chạy lần mới:** thay thành kết quả của build TASK07 kèm paths; benchmark cũ chỉ làm baseline.

## B. Acceptance cases theo hành vi

| ID | Test | Kỳ vọng / Oracle |
|---|---|---|
| L01 | Thiết bị English; Follow system | UI English; không có hardcoded Vietnamese |
| L02 | Thiết bị locale chưa hỗ trợ | UI fallback English, không crash |
| L03 | Chọn locale thủ công rồi cold restart | Lựa chọn và setting khác giữ nguyên |
| L04 | Đổi locale khi đang mở project | Không mất draft, source, playhead, undo, export job |
| L05 | Full UI screens: Library/Photo/Editor/ASR/Export/Settings | Không thiếu translation key, dialog không overflow |
| L06 | Long German/French, 320dp, text 200% | Action quan trọng luôn tới được, không clipped |
| L07 | Arabic RTL | Thứ tự UI hợp lý, không mirror video/crop/drawing/timeline frame nội dung |
| L08 | Japanese/Chinese/Korean/Hindi fonts | Không tofu glyph, không cắt combining clusters |
| L09 | Accessibility per locale | Label/hint/value rõ; TalkBack order hợp lý; human gate riêng |
| A01 | ASR manual language theo engine | Chọn được mọi supported code, reject unknown code an toàn |
| A02 | Locale UI `ja`, ASR language `es` | Lời nói được xử lý theo Spanish, không phụ thuộc UI Japanese |
| A03 | Auto Detect speech | Nhận dạng language trên real fixture; lưu detected/fixed metadata nếu contract có |
| A04 | Silence/music/noise | Không hallucinate hoặc hiển thị review warning với case chưa tránh được |
| A05 | Model chưa cài / canceled download | Error/progress/cancel thật; không transcript/mock success |
| A06 | Old transcript/job with `vi/en/auto` | Reload đúng nguyên trạng; không thay model/lang/duration |
| A07 | Low RAM / cancel mid-inference | Không crash; no late result; next job chạy được |
| S01 | UTF-8 mixed script (vi/en/es/ja/zh/hi/ar/emoji) | Cue edit + undo/redo giữ đúng text/timestamp |
| S02 | Unicode SRT save with SAF | File đọc lại UTF-8 đúng, không `?`/replacement char ngoài fixture |
| S03 | RTL mixed Arabic + Western digits | Preview đúng bidi/shaping, export frame khớp view |
| S04 | CJK long cue, no spaces | Safe area/wrap, text không clip ở frame boundaries |
| S05 | Subtitle speed/trim/reorder | Cue timestamp và pixel render đúng; source không overwrite |
| S06 | Rename/export Unicode filename | Content URI/grant và bytes được giữ; no duplicate publication |
| R01 | Old draft and old thumbnail catalog after TASK07 | Open được, source bytes/hash không đổi |
| R02 | Convert/Export MP4, GIF with locale changed | Full decode, stable PTS, output visible, correct count |
| R03 | Source protection | P1 protected files không bị TASK07 thay đổi |
| R04 | APK/ABI/size | Size delta, static 16KB check, no Whisper weights bundled |
| R05 | Performance same corpus | Report before/after, không kết luận 60fps từ SwiftShader |

## C. Input corpus cần có

- Speech sạch có reference và license/source provenance cho mỗi ngôn ngữ định benchmark.
- Mỗi script có đoạn text chủ động để test font/shaping khi audio sample chưa có.
- `digital silence`, music-only, white/babble noise, speech with noise, clipped speech, long pauses.
- SRT có combined diacritics, variation selectors, emoji, numbers và punctuation lẫn RTL/LTR.
- Media test: image JPEG/PNG EXIF, MP4 portrait/landscape H264/HEVC, audio AAC, mixed clips, Unicode filename và SAF permission edge.
- Không lấy recording/media của người dùng làm fixture khi chưa có consent.

## D. Báo cáo QA cuối mỗi checkpoint

Mỗi result phải gồm:

```
Case ID:
Status: PASS | FAIL | PARTIAL | NOT RUN
Build / git HEAD / source SHA:
Device / API / ABI / Flutter mode:
Locale / ASR model / audio language:
Input fixture & provenance:
Exact command / test function:
Expected vs actual:
Evidence paths (logs, screenshot, SRT, MP4, checksums):
Known limitations / next owner:
```

## E. Gate bàn giao cho TASK 08/09/10

**TASK07 có thể đóng phần implementation** khi source localization, language contract, Unicode subtitle và regression test đã chạy. Nhưng:

- Human native-speaker review các bản dịch chưa chạy → ghi rõ `PENDING`.
- Chưa có recording P1 ready → `P1 INTEGRATION OPEN`, không làm blocker giả cho G1/G2/G3.
- Chưa có thiết bị ARM/16KB/OEM/SD/physical thermal → `TASK08/09 EXTERNAL GATE`.
- Nếu một locale không có corpus ASR thật, UI option có thể xong nhưng **không được ghi ASR quality PASS**.
- Để tuyên bố **toàn app complete**, cần thêm TASK10 P1→P2→P3 capture real end-to-end.
