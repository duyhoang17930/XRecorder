# TASK08 — Data safety (verdict PARTIAL, chưa nghiệm thu toàn app)

## Final main restore09/11

`m6_api36_main_restore_v1/`:backup private/external device-host SHA exact trước
update,install-r thành công,UID giữ nguyên;main v5 mở và screenshot được kiểm.
`main_integrity_v2.json`:19job journal byte-exact,62source/model hashes nguyên.
Speech-model preferences byte-exact;native `p2_locale.xml` đổi ar→en do main
`NativeLocaleSync` đồng bộ locale thực sau harness Arabic dùng settings trong
memory. App Settings document không tồn tại trước/sau,main dùng defaults.
Không gọi mọi preference byte-exact;attempt oracle v1 giữ riêng trong
`preferences_probe_v1_failure.json`. Không sửa/khôi phục preferences thủ công.
Main v5 cũng đã được giữ trên API34/16KB;QA5560 recovery gate vẫn PARTIAL.

## Checkpoint09/11 — native durability / paging

`m3_pagination_green_v1.log`:0/20/21/77/100/1001 metadata-only fixture jobs
đều giữ đủ, legacyvi/en/auto/Unicode/timing fields đúng; queued/running mở
lại thành failed/interrupted. Cursor(createdAt,id), page17 và latest
matching/project/source filter kiểm đủ ID, không trùng/mất ở timestamp bằng
nhau; invalid limit/cursor bị reject. Red control trước fix:
`m3_pagination_red_v1.log` (Invalid page accepted).

`m3_history_matrix_metrics_v1.json`:1001 record legacy channel440628B so với
latest matching444B; restore+list85ms, toàn bộ pages/filter220ms trong lượt
này. Không gọi single sample là universal latency guarantee. Registry/journal
vẫn giữ toàn bộ jobs, memory load theo history size; tối ưu transfer/page,
không thêm retention cap hoặc đổi storage schema.

`m3_history_process_reopen_v1.log`:mở lại cùng6 fixture directories trong
process mới PASS,1001 metadata/IDs/interruption đúng. Write obstruction sau
restore, future/corrupt/strictUTF8 giữ original bytes. Attempt đầu
`m3_history_matrix_v1.log` là fixture fault đặt quá sớm bị AtomicFile.openRead
dọn; failure giữ nguyên, không tính PASS.

`m3_duplicate_regression_v2.log`:duplicate journal readonly/write rejected,
input exact. `m3_trash_regression_v2.log`:foreignbin/part/json giữ nguyên,
corrupt managedUUID vẫn hiện theo contract. Không đi vào trash thật.

19 job speech/model thật sau M2 giữ nguyên journal byte trước/sau native
tests, SHA256
`f4854c6b8d8e6f39a3affbdcb29e404c2b52862e1daf4f13b51a3908b17745c5`;
`m3_existing_speech_journal_integrity_v2.json`. Synthetic metadata không phải
transcript khôi phục. Incident/quyền URI bên dưới vẫn là FAIL/PARTIAL.

## Sự cố QA trong TASK08: FAIL

Ngày08/11/2026, Flutter SDK AndroidDevice.installApp đã tự uninstall app trên
AVD QA5560 khi `install -r` báo `INSTALL_FAILED_INSUFFICIENT_STORAGE`.
`--keep-app-running` không bảo vệ nhánh này. Log gốc:
`build/verification/task08/m0_profile_320_bounded.log`. UID đổi217→219,
private/no_backup/app-specific external mất. Đây là sai sót của harness/task;
không quy cho P1, không gọi no-data-loss PASS. Không thao tác emulator5554.

| Dữ liệu | Đã thực hiện và bằng chứng | Giới hạn |
|---|---|---|
| Private files/preferences |Tar805376B chụp trước install; khôi phục127 regular files, so byte từng file. `incident_private_recovery.json` |Backup không chứa Android framework permission state |
| Projects |116 project files trong127 file trên |Chưa chứng minh mọi source URI của draft mở lại được |
| History |77 job thật, journal nguyên byte từ backup |Không bịa phục hồi job đã bị cap20 làm mất trước TASK08 |
| Whisper models |Tiny77691713B,Base147951465B,Small-q5_1 190085487B; SHA256 host/device exact trong `incident_models_recovery.json` |Không biến việc copy weights thành inference PASS |
| External QA inputs |54 file/431070187B từ retained host inputs; SHA256 đọc lại device exact. `incident_external_recovery.json` |Không có full inventory/hash external trước incident; full recovery chưa được chứng minh |
| Public images |1013 seed IDs vẫn tồn tại, size/revision không đổi. `incident_public_catalog_comparison.json`;1192 public files được sao chép chỉ đọc về host |Không có pre-incident full-byte hash; ownership/URI grants sau uninstall chưa được khôi phục/xác nhận |
| P1/current source |18 protected hashes vẫn khớp snapshot TASK08 tại checkpoint |Kiểm tra lại khi delivery; không dùng hash commit thay working-tree snapshot |

Không root/chmod, không ép owner_package_name, không wipe/clear, không xóa media
để tạo chỗ trống. Đĩa AVD5560 được giữ sau phục hồi, viewport trả1080×2400/dpi420,
dừng bình thường. APK trên5560 vẫn là harness profile; chưa trả main-entry vì
install margin thấp. Không coi đây là QA delivery APK hoạt động bình thường.

## Ngăn tái diễn ở runner

`tool/run_qa_existing_app.py`: xác minh serial/tên AVD, từ chối5554, từ chối
CaptureService active, guard dung lượng (4×APK+512MiB), backup private toàn bộ
(bao gồm no_backup) và app-specific external trước update, chỉ `adb install -r`.
Install fail dừng ngay; không uninstall/retry. Kiểm UID không đổi. Launch rồi
attach host Dart driver; không gọi Flutter installer. Evidence directory tạo
mới, logs lọc VM address. `tool/verify_ui.ps1` dùng chung runner này.

Ba unit tests PASS thực thi: install fail chỉ gọi một update/không launch;
low-storage chặn trước update; personal5554 chặn trước ADB. Đây là negative
installer tests với mock, không thay native output/persistence tests.

AVD TASK08 riêng5566/API36x64/data16GiB tạo mới để các kiểm thử tiếp theo không
đụng QA cũ. Corpus giữ byte gốc nhưng có MediaStore identities/metadata mới:
chỉ so A/B trên manifest mới, không tự so trực tiếp với TASK07.

## P0 production fix đã kiểm thử

Restore duplicate job ID trước đây dùng putIfAbsent rồi bỏ qua duplicate, cho
phép lần persist sau làm mất record. Native ContextWrapper fixture tái hiện
input2/listed1 (`m0_duplicate_before.txt`). Targeted check chuyển cả journal sang
read-only; write bị reject, input byte exact (`m0_duplicate_after.txt`). Test
không thay journal thật. Số lượng1000+, fault/restart/pagination và các gates
còn lại chưa nghiệm thu tại checkpoint này.

**DATA gate: FAIL/PARTIAL** do incident và các trường hợp chưa kiểm. Khôi phục
payload từ backup không chứng minh toàn bộ metadata/quyền Android trở lại.

## Evidence handling checkpoint sau yêu cầu SAFE EVIDENCE

Automatic review đã chặn lệnh PowerShell `>` vì nguy cơ ghi đè
`incident_image_paths.txt`. Không retry redirect đó. Target được kiểm tra tồn
tại trước, thao tác MediaStore chỉ đọc; artifact đã được tạo bằng `open('xb')`
sau kiểm tra target chưa tồn tại. File hiện có103745B được giữ nguyên; đường
dẫn đúng là `build/verification/task08/incident_image_paths.txt`, không giả định
nó là log redirect của lệnh bị từ chối. Các kiểm tra tiếp theo dùng read-only.
SHA256 khi đọc kiểm tra: `657124c3fe65d108a84e54e7c0913c6d85bd9dae2e3ceaf25703d1c11bea9ece`.

Mọi artifact tiếp theo dùng tên phiên bản riêng, thư mục mới và exclusive
creation; trùng tên phải dừng, không overwrite. Runner chuyển cả metadata,
launch/install log sang `open('xb')`; Dart driver dùng `create(exclusive:true)`.
Native fixture dùng createNewFile cho journal; không dọn các lần lỗi trước.
Report cập nhật bằng patch bổ sung, giữ evidence/failure tại checkpoint cũ.

Baseline320 đã PASS lưu8.27MB raw report trong
`performance/owned_before_320_attach/emulator_verification.json`;411 đang chạy
trong `performance/owned_before_411/`. Không restart baseline đã hoàn tất.
