# TASK 09 — HCI, localization và accessibility

Trạng thái: **PARTIAL**. Đã sửa lỗi tương tác xác nhận được trong P2/P3 và kiểm lại; chưa có nghiệm thu bằng người dùng/TalkBack trên máy thật. HEAD `9afcb124069d905dd4b285c890ca0709f5548b68` + patch TASK09.

Retest trên **main APK v4 cuối**: 10/10 nhóm kịch bản đã đạt sau sửa harness; [lượt đầu 7 PASS/3 FAIL](../../build/verification/task09/run_20261109T091518633188Z/ui_walk_e04db7be9d22450eb07058d852403f4d/trace.json), [3 ca retest đạt](../../build/verification/task09/run_20261109T091518633188Z/ui_walk_d543d5c891434102a59f98a8cf7518fe/trace.json). Hai FAIL do fixture viết `Photo Editor/Photo Preview` khác label source `Photo editor/Photo preview`; ca còn lại giả định một Back luôn đóng DocumentsUI thay vì đi lên folder. Không có patch sản phẩm để né các assertion đó. Native Back từ root Editor và PhotoTools đều về đúng Library; warm media A→B hiển thị tên B; PhotoPreview không có lỗi load; picker cancel trở về Media Details. **41/41 PNG** của hai lượt cuối qua kiểm decode, không có ảnh hỏng.

Đã chạm native main **12/13 loại screen có route builder**, thêm unknown-route error. Route Recording Settings của P1 không mở native; không có screen nào được chứng nhận mọi control/state chỉ vì đã mở được.

## Kết quả đã kiểm chứng

- Main APK v3: bấm 4 bottom tab, mở Create rồi Android Back, đổi Dark/Light/System, mở/đóng App language và Media storage, warm Help topic A→B, Support empty validation, Exports/Trash/empty/unknown routes: **5/5 nhóm walkthrough đạt**. [Trace + PNG/XML](../../build/verification/task09/run_20261109T091518633188Z/ui_walk_2d19ec37ab3b4bab902f02d252c7e066/trace.json). Không bấm Screen recording/Screenshot để tạo capture.
- Native framework accessibility-focus đúng **5/5 target** Video/Photo/Create/Edit/Settings; có screenshot từng focus. [Kết quả](../../build/verification/task09/run_20261109T091518633188Z/native_focus_navigation_v1.json), [ảnh](../../build/verification/task09/run_20261109T091518633188Z/native_focus_navigation_v1/). Dùng `FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES`; không giả lập việc người thật nghe TalkBack.
- App language trước sửa bị gộp với Theme/mô tả và có bounds của cả card. Sau sửa có Semantics container riêng cho đúng row; host kiểm label và chiều cao target, native đã mở được row. [Đỏ](../../build/verification/task09/run_20261109T091518633188Z/settings_support_ui_red_v1.log), [green 77 test liên quan](../../build/verification/task09/run_20261109T091518633188Z/settings_support_ui_green_v1.log). Không đổi SettingsController/default/migration/capture fields.
- Support chặn double invocation trước frame kế tiếp. Nội dung trống hiện “Write a report before sharing.” qua catalog hiện có, thay vì bảo kiểm attachment. Diagnostics vẫn chỉ có khi consent. Kiểm share bằng mock; không gửi report, mở issue hay email từ tài khoản người dùng.
- Warm deep link A→B đã kiểm 5 loại nội dung; thêm 3 root exit regressions cho editor/photo/media details. Giữ autosave failure/discard guard. Lỗi Back không có history có hướng về đúng Library; không bỏ dialog giữ dữ liệu để làm test xanh.
- R3 là lỗi harness chờ animation vô định: giữ loading UI, kiểm rõ Saving/không Cancel, sau đó mới Saved/Open. Không đánh đồng spinner đang hoạt động với app hang.
- SAF copy native dùng DocumentsUI thật và dialog ALLOW cho một folder QA mới; nguồn và bản copy khớp byte. Không dùng shell grants hoặc consent giả.

## Locale/layout đã chạy

`en, vi, es, pt_BR, fr, de, id, ja, ko, zh_Hans, hi, ar`: **48 ca layout** (12×4) ở 320/360/411/840dp; 320dp dark/text200, 360dp light/text150, 411/840dp light/text200. Thêm một ca Arabic locale/effect/back-direction: tổng **49 layout cases**. Xem [global_layout_test.dart](../../test/global_layout_test.dart) và [full test cuối](../../build/verification/task09/run_20261109T091518633188Z/final_flutter_v4.log).

Mỗi ca layout chạy các widget/surface được khai báo trong test; không có nghĩa mọi route/dialog của app đã chạy ở 12 locale và mọi độ rộng. 840×411 là biến thể ngang trong host, không phải rotation lifecycle native. [ARB checker](../../build/verification/task09/run_20261109T091518633188Z/l10n_final_v1.log) đạt key sets, descriptions, placeholders và Unicode. Chất lượng dịch tự nhiên, CJK typography và ngữ cảnh tiếng Ả Rập vẫn cần người đọc bản ngữ.

Host regression còn kiểm theme editor, sort controls, query/scroll/tab reselect, picker có keyboard, photo dirty/save guards, notice placement, failed persistence và friendly errors. Một số test cũ có hit-test warning ở `refinement_test.dart`; không dùng những lần tap bị warning làm bằng chứng control đã được click thành công. Các test TASK09 mới có fixture sửa lỗi off-screen và spinner trước khi ghi kết quả green.

## Những điều chưa chứng nhận

| Hạng mục | Trạng thái / yêu cầu tiếp |
|---|---|
| Human TalkBack, đọc slider/switch, gesture/focus toàn app | NOT RUN; native framework focus 5 target không thay việc nghe và thao tác thật |
| Touch target 48dp của mọi control, one-hand tay trái/phải | PARTIAL; có layout/bounds checks, chưa có đo exhaustive và nghiệm thu người dùng |
| Contrast từng màu/state trên OLED/ánh sáng thật | NOT RUN toàn bộ; không công bố WCAG toàn app từ screenshot hoặc vài token |
| Native 12 locale, system locale switch, font200, rotation/resume mọi màn | PARTIAL; host matrix có phạm vi trên, native walkthrough chủ yếu English |
| Reduce motion trên thiết bị thật | NOT RUN đầy đủ; source dùng motion tokens, không suy source thành PASS |
| Recording/facecam/draw/overlay/screenshot permissions và latency ~3s | P1 HANDOFF / native NOT RUN; không thay đổi UI hoặc semantics P1 |
| 1k+ native library, raster jank, scrolling trong lúc capture | NOT RUN; widget lazy/cache tests và thư viện QA nhỏ không chứng nhận 60fps |
| Support external delivery / GitHub issue submit | Không thực hiện; share chooser không đảm bảo gửi thành công |
| R7 stale-photo/Trash ANR | Chưa tái hiện trong missing-source probes; cần đúng draft/input/sequence và môi trường được phép |

Hai báo cáo TASK08 follow-up được giữ nguyên byte tại TASK09. Các báo cáo TASK09 mới là UTF-8; có kiểm Unicode/link riêng trước bàn giao, không ghi tiếng Việt qua pipeline PowerShell ASCII.
