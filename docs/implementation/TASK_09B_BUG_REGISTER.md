# TASK 09B — Bug register và red → green

HEAD `9afcb124069d905dd4b285c890ca0709f5548b68` + dirty patches. Evidence paths dưới đây tính từ [run mới](../../build/verification/task09b/run_20261109T113727956224Z_f64203/). Không xóa log đỏ, đổi expected P1 hay biến lỗi harness thành lỗi sản phẩm.

| ID / severity | Repro và nguyên nhân | Thay đổi có scope | Red → green / verdict |
|---|---|---|---|
| G1-01 / P2 | Hai Semantics action About được enqueue trước await tạo hai overlay | SettingsHub giữ guard đồng bộ cho overlay, release sau dismiss | `g1_host_red_v4` → `g1_host_green_v2`; expanded/native editor regression **FIXED** |
| G1-02 / P2 | Double tap Help đẩy hai route | Guard route riêng, await route đóng; không timer debounce | Cùng red/green G1; host direct pointer + native journey **FIXED** |
| G3-01 / P1 | Add drawing mở AlertDialog gặp intrinsic sizing của LayoutBuilder, chức năng không dùng được | `layers_editor.dart`: Builder và actual render size khi pan | `g3_host_red_v2` → `g3_host_green_v1`; native drawing gesture **FIXED** |
| G3-02 / P1 | Snapshot drawing có null phân cách stroke bị cast/list non-null từ chối; draft/export không nhận nét | `models.dart` helper P3 deep-freeze giữ `Object?`/null | `drawing_snapshot_red_v1` → `drawing_snapshot_green_v1`; native output 480px + pixel oracle **FIXED** |
| X04-01 / P1 | Restart gặp published URI rỗng nhưng journal báo completed/Saved | `ExportQueue.kt`: chỉ hoàn tất khi URI published đọc được và statSize > 0 | `native_export_empty_publication_red_v1` → `native_export_recovery_green_v4` **FIXED**; không xóa published row |
| X04-02 / P1 | Pending URI malformed làm query throw trong constructor queue; export list init thất bại | Query recovery bọc failure, chuyển failed; giữ owner/pending cleanup contract | `native_export_invalid_uri_red_v2` → `native_export_recovery_green_v4` **FIXED**. Không gọi là toàn app startup crash |
| G4-01 / P2 | Undo/Redo ảnh có bản dịch vô nghĩa, trùng nhau ở ja/ko/zh; test native gặp ambiguous locator | Sửa 4 key history ở 13 ARB; test actual PhotoTools controls và label khác nhau | `history_localization_red_v3` (en PASS/11 FAIL) → `history_localization_green_v2` (80 PASS); native 12 locales **FIXED** |
| G4-02 / P2 | Crop bị dịch thành nông nghiệp/đồ uống, ví dụ Reset tanaman/植物/زراعة/Cerveza | Sửa 5 key crop ở 13 ARB; guard từ sai domain trong widget regression | `crop_localization_red_v1` (en PASS/11 FAIL) → `crop_localization_green_v1` (80 PASS); native G4 mới **FIXED** trong phạm vi 9 key; chưa phải linguistic review toàn app |

Hai nhóm locale sửa tổng **117 values = 9 keys × 13 ARB**; English không đổi. Alias pt/zh vẫn giữ. Không thêm paid API, dependency hoặc transcript giả.

## Giữ nguyên bảy patch TASK09

1. Export retry refresh không nhận snapshot Failed cũ đè Running.
2. Preview load serialize và bỏ request stale.
3. Năm route identity theo tham số.
4. Support khóa submit đồng bộ.
5. Empty Support validation localized.
6. Settings language Semantics container.
7. Editor/Photo root Back fallback; đóng Details sau Move/Trash thành công.

Source ban đầu đã chứa các patch trên và được snapshot trước TASK09B. Full regression mới đạt **317 PASS/4 FAIL P1**, native JUnit **137/137**. Chi tiết provenance TASK09 giữ tại [register cũ](TASK_09_BUG_REGISTER.md); không viết lại báo cáo cũ.

## Harness/environment findings — không đánh đồng lỗi sản phẩm

| Finding | Xử lý và evidence được giữ |
|---|---|
| SDK driver timeout vẫn exit 0 với partial report | QA runner bắt buộc final `status=PASS` khi `--require-complete-report`; `qa_completion_green_v1.log`, 12 Python tests |
| First-launch external directory chưa tồn tại | Chỉ coi ABSENT sau khi parent đọc/traverse được; permission error vẫn chặn install |
| Flutter screenshot channel treo; Arabic About Close dùng Material label; lazy Undo chưa reveal ở 320dp | Giữ raw failed attempts; native PNG/XML capture + locator/reveal sửa trong harness; không đổi product timeout/layout để che lỗi |
| `pumpAndSettle` chờ busy spinner phía sau Rename | Dùng bounded frame pumps + assertion dialog; native Media UI v3 PASS |
| SRT picker Back đầu chỉ đóng IME, verified notice hết trước host ACK | Dismiss IME/Cancel tách bước; quan sát notice liên tục, không kéo dài feedback sản phẩm |
| Global companion đọc request JSON khi producer chưa ghi xong | Capture v3 retry parse và batch ACK polling; landscape v2 PASS |
| Fault fixture dùng outputWidth/outputHeight ngoài contract | Giữ output 96×64 và failed oracle; fixture mới dùng effects.height/aspect đúng contract; output mới 640×480 PASS |
| Hugging Face DNS trên AVD không resolve | Host resolve; đã kiểm và thử cấu hình DNS trên AVD riêng, vẫn lỗi; local checksum import thật PASS. Download model đầy đủ qua mạng AVD **BLOCKED environment** |
| Library DTO optional revision khác nhau giữa find/list; sort locator trước layout | So identity URI + canonical metadata, pump/reveal rồi hit-test; giữ failed logs và chạy lại |

Thumbnail RepaintBoundary đã đo A/B trên cùng1.013ảnh: median raster p95 giảm4,45%/3,69% tại320/411dp, memory không tăng trong workload; giữ patch nhỏ. Kết quả có3trial mỗi viewport/fixed order, chưa chứng nhận physical FPS. [Evidence cuối](TASK_09B_TEST_EVIDENCE.md) giữ raw frames và memory.

## Các lỗi/gate còn mở

P1 R1/R2 có repro host, R4/R5/R6 giữ source findings và native acceptance gate tại [handoff](TASK_09B_P1_HANDOFF_UPDATE.md). R7 missing-source ANR lịch sử chưa tái hiện; không ghi đã sửa. Không còn lỗi P0/P1 P2/P3 mới nào **đã tái hiện trong các test này** mà chưa xử lý; điều này không chứng nhận mọi control-state chưa test. Hiệu năng SwiftShader trên thư viện lớn vẫn cần đo và máy thật, không được gọi 60 FPS nếu raster vượt 16,67 ms.

**START-OBS-01 — PARTIAL / performance observation:** process-cold Android framework launch khoảng5–8s trên AVD; controlled same-QA TASK09/current medians5.375/5.502ms (3samples mỗi bản), variance lớn, không đủ chứng minh regression do patch mới. Giữ raw am-start/PNG/XML, kiểm P2 init worker/lazy source; chưa khoanh root cause/Flutter first frame hoặc chứng nhận physical startup. Không ghi startup optimized hoặc tự quy lỗi cho P1. Xem A/B path trong evidence; current APK đã được trả lại và Settings/drafts/journals giữ hash.
