# TASK 09B — Global UI, HCI và accessibility

**G4 automated native scope: PASS. Human/global full acceptance: PARTIAL.** Chạy profile trên `emulator-5570`, AVD `ThreeHRecorder_TASK09B_API36`, Android API36/x86_64/SwiftShader; không thao tác emulator5554/QA5560. Text scale test 200%, actual density160/PNG dimensions được kiểm. Không dùng resource-key validation thay runtime.

## 12 ngôn ngữ và viewport

| Viewport thực | Locale | Evidence hoàn tất | Lưu ý raw run |
|---|---|---|---|
| 411×920 dp | en, vi, es, pt_BR, fr, de, id, ja, ko, zh_Hans, hi | `native_global_411_v6`: 11 locale completed; capture `global_capture_b695f90ecd894436851337ab29a516fd` | Whole run FAIL ở harness Arabic About Close; chỉ dùng 11 locale đã hoàn tất, không gọi cả run PASS |
| 411×920 dp | ar | `native_global_ar_411_v1` PASS; capture `global_capture_7efedbe1601e4616b42107cf62d15304` | Material close label khác app custom label; harness đã sửa |
| 320×920 dp | en, vi, es, pt_BR | `native_global_320_v1`: 4 locale completed; capture `global_capture_51793bfd52744a24813d013af46ea392` | Whole run FAIL vì lazy Undo chưa reveal ở fr; không phải product assertion FAIL |
| 320×920 dp | fr, de, id, ja, ko, zh_Hans, hi, ar | `native_global_320_remaining_v2` PASS; capture `global_capture_5fb5ea7401594a37b03c4f1731af5fef` | Reveal + hit-test trước thao tác, không bỏ assertion |
| 920×411 dp landscape | en, vi, ja, ar | `native_global_landscape_v2` PASS; capture `global_capture_06ad9d9c9c8643a493cfd8bfc5a0be55` | 76 states, 60 PNG/XML; v1 companion race được giữ riêng |

Tất cả thư mục nằm trong [run evidence](../../build/verification/task09b/run_20261109T113727956224Z_f64203/). `pt_BR` và `zh_Hans` trong test config tương ứng locale tags `pt-BR`, `zh-Hans` trong report. Đây là union các locale assertions đã hoàn tất; không cộng retries thành locale mới.

Per-locale flow: chọn language thật ở Settings → controller mới read-back selection; bốn tab có heading đúng locale; Create open/Back; Storage/Privacy/About dismiss; Help/Back; Support empty validation localized; Export/Trash back; PhotoPreview back; PhotoTools Rotate→Undo state; Editor→Subtitles→AI dialog đóng; Light theme ở Settings; RTL/text200/no Flutter exception; nguồn ảnh giữ nguyên bytes, active preview về 0. Mỗi screenshot là một state, không chứng minh mọi control trong ảnh được thao tác. Cold process restart cho **mỗi** locale riêng lẻ chưa chạy.

## Hai lỗi locale đã sửa

4 key Undo/Redo và 5 key crop ở 13 ARB có nghĩa sai hoặc trùng label. Đã sửa **117 values**, giữ English và locale aliases. Host actual PhotoTools widget ở 320dp/font200: red en PASS/11 FAIL → **80 focused tests PASS** sau generate l10n. Native G4 mới kiểm label/control thực và Undo có hậu quả đúng. [Bug register](TASK_09B_BUG_REGISTER.md) giữ red/green chi tiết.

Không coi 9 key đã sửa là đã được người bản ngữ duyệt toàn bộ văn phong của 12 ngôn ngữ. Date/plural/units có resource/host regression; mọi giá trị số, bidi caret, chọn vùng chữ và font fallback input chưa exhaustively test.

## Accessibility/HCI: bằng chứng và giới hạn

| Yêu cầu | Kết quả trong scope | Chưa được chứng minh |
|---|---|---|
| Icon labels/state, dialog exit, keyboard validation | Widget semantics + native XML, actual tap/back/invalid field tests; About/Help duplicate guards fixed | Human TalkBack focus/gesture, mọi icon-only action toàn app |
| Chữ 200%, 320/411dp, landscape | Global flow nêu trên không Flutter overflow/exception; lazy control reveal/hit-test trước action | Mọi composition dài/layer count/IME combination |
| Light/Dark | Native global Settings Light/Dark; host editor/photo/layout regression | Physical contrast/vision/usability; không tự ghi WCAG toàn app PASS |
| Touch ≥48dp | `touch_bounds_global_411_v1.json`: 170 XML/1.030 enabled clickable node states, 36 bounds nhỏ hơn48 thường bị clip mép viewport | 36 observations **không phải** 36 product defects; cần hit-area/focus audit từng node/human test |
| Arabic RTL | Native Directionality + UI navigation/layout; localized dialogs, landscape; không exception | Caret/selection/focus order với TalkBack, bidi editing do người thử |
| CJK/Vietnamese/emoji filenames | Real Rename/Copy/Restore qua DocumentsUI giữ bytes; Unicode SRT thật Save/read-back | Mọi filesystem normalization/OEM/SD card |
| Drawing accessible path | Host preset/coordinate actions và native actual pan/draft/export pixel | Trải nghiệm motor impairment/ngón tay/bút trên phone |
| Screenshot camera icon/manual refresh/Back/Older first | Reuse TASK09 source/layout checks và ảnh native mới; không redesign P1 | Screenshot target ~3s cần real capture timing của P1, chưa đo trong TASK09B |
| Human one-hand/listening/media scrub | **BLOCKED external human/device** | Không có người ký nghiệm thu; emulator `-no-audio` không chứng minh nghe thật |

Không có user study, sign-off TalkBack hay physical phone trong task này. Điều kiện đóng: người thử trên thiết bị được phép thực hiện TalkBack traversal/actions, RTL caret/selection, left/right one-hand, reduced motion, scrub và nghe các output thật. Ghi tên/thiết bị/ngày/kết quả riêng; không sửa báo cáo này thành human PASS từ automated evidence.
