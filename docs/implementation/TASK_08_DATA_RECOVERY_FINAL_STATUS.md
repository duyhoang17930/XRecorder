# TASK08 — Kết luận xác minh phục hồi dữ liệu QA5560

Ngày 09/11/2026. **TASK08: PARTIAL.** Đóng phần xác minh bản sao và metadata có thể kiểm tra trong phiên chỉ đọc; chưa thể chứng minh full recovery của trạng thái Android trước sự cố.

Bằng chứng mới: [thư mục follow-up](../../build/verification/task08/followup_20261109T063823024767Z/). Không thay thế các báo cáo/bằng chứng TASK08 cũ.

## Trạng thái và giới hạn thao tác

- QA5560 là AVD `ThreeHRecorder_Task021`, thư mục `build/task021_avd/ThreeHRecorder_Task021.avd`. ADB không liệt kê 5560, không có process mang tên AVD này. Chỉ emulator cá nhân 5554 xuất hiện; không gửi lệnh đến nó.
- Không boot, mở app, install/reinstall/uninstall, clear/wipe, mount filesystem, root/chmod, sửa guest data hoặc grant trên QA5560. Vì boot có thể ghi journal/dữ liệu, phiên audit giữ nguyên AVD đang tắt.
- Đã hash chỉ đọc các file đĩa/config hiện có, kích thước và mtime không đổi qua lượt đọc: [offline disk identity](../../build/verification/task08/followup_20261109T063823024767Z/qa5560_offline_disk_identity.json). Đĩa qcow2 có 6.442.909.696 byte, mtime 08/11/2026 07:19:59 UTC. Đây là mốc nhận diện hiện tại, không phải bằng chứng nội dung guest khớp trước sự cố; không có hash toàn đĩa trước sự cố để so.
- Những kết quả đọc lại thiết bị trong báo cáo incident là **bằng chứng lịch sử tại lúc khôi phục**. Kết quả mới dưới đây kiểm tra lại **host/backups đang còn**, không nâng thành kiểm chứng live QA5560.

## Dữ liệu đã xác minh

| Nhóm | Xác minh mới, chỉ đọc | Kết luận / giới hạn |
|---|---|---|
|127 private files|Tar gốc `m0_private_before.tar` còn đủ 805.376 byte; 127 regular files, tổng payload 705.622 byte. Đã lập SHA256, size, mode/UID/mtime của từng entry; JSON đều parse được.|Bản backup VERIFIED. `incident_private_recovery.json` ghi nhận 127 file đã restore byte-exact trước đây; chưa đọc lại guest hiện tại.|
|116 project files|Đủ 116 JSON version1; 29 content URI riêng trong draft: 12 image MediaStore, 9 video MediaStore, 8 FileProvider.|VERIFIED cấu trúc/references của bản backup. Có fixture rỗng và nguồn lịch sử, không đồng nghĩa 116 draft đều mở/render được.|
|77 ASR jobs|77 ID duy nhất; 74 completed, 3 cancelled; model Tiny38/Base27/Small12; tổng 42 cue được giữ nguyên trong journal.|VERIFIED journal backup. Giữ nguyên empty/silence/cancelled results; không bịa cue, chạy lại ASR hoặc sửa timestamps. Không chứng nhận accuracy hay số job có trước các lần cap20 lịch sử.|
|3 model|Host SHA/size khớp `incident_models_recovery.json`; tổng 415.728.665 byte.|VERIFIED retained weights; manifest cũ ghi host/device exact khi restore. Không biến checksum thành inference/runtime PASS.|
|54 known external inputs|Cả 54 retained host sources còn đủ, SHA/size khớp manifest restore; tổng 431.070.187 byte.|VERIFIED payload đã biết. Có cả bản model dùng làm import input; không cộng với model store thành số byte dữ liệu duy nhất. Không có full external inventory trước sự cố.|
|1.013 seed MediaStore rows|Đọc seed từ private tar `files/task07_profile_1794104432943.json`, đối chiếu lại với query lưu `after_uninstall_images.txt`: ID/size/generation đều khớp, trong 1.022 image rows.|VERIFIED phép so trước–sau đã lưu, không phải query live. Có 1 seed row zero-byte đã tồn tại trong seed; không chứng nhận mọi media healthy.|
|Public retained copies|1.192 files /157.358.651 byte đã hash. Cả 1.022 đường dẫn image trong `incident_image_paths.txt` có bản sao đúng size, giữ cả thư mục con.|VERIFIED host copies/path-size mapping. Không có hash byte toàn bộ public media trước sự cố; chưa chứng minh ownership/quyền đọc hiện tại.|

Chi tiết: [private inventory](../../build/verification/task08/followup_20261109T063823024767Z/private_backup_inventory.json), [model/external recheck](../../build/verification/task08/followup_20261109T063823024767Z/models_and_external_host_recheck.json), [seed metadata comparison](../../build/verification/task08/followup_20261109T063823024767Z/seed_metadata_recomparison.json), [public path comparison v2](../../build/verification/task08/followup_20261109T063823024767Z/public_paths_comparison_v2.json), [summary v2](../../build/verification/task08/followup_20261109T063823024767Z/data_recovery_summary_v2.json).

Lượt mapping public đầu làm phẳng tên nên báo thiếu 6 đường dẫn nằm trong subdirectory. Đối chiếu v2 giữ nguyên hierarchy xác nhận cả 6 có sẵn; không có file nào được thêm/xóa để làm kết quả đạt. Giữ nguyên kết quả v1 để truy vết.

| Model | Bytes | SHA256 |
|---|---:|---|
|tiny|77691713|`be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21`|
|base|147951465|`60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe`|
|small-q5_1|190085487|`ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb`|

## Draft, URI và dữ liệu chưa được chứng minh

[Draft URI audit](../../build/verification/task08/followup_20261109T063823024767Z/draft_uri_audit.json) cho thấy 12/12 image URI của draft có ID trong manifest public đã lưu. Chưa có đối chiếu đầy đủ row/bytes/quyền live cho 9 video URI; basename của host MP4 không đủ chứng minh MediaStore identity.

7/8 FileProvider sources của draft nằm trong 54 input đã restore. Source còn lại là `content://com.xrecorder.xrecorder.files/media/task07_subtitle_input.mp4`. Tìm thấy thêm bản host tại `build/verification/task07/g3_outputs/task07_subtitle_input.mp4`, 86.241 byte, SHA256 `2af44ce3d540d975299af549f7fb9099f223d7c80530438ae556f844420840e4`. Đây là **recovery candidate**, chưa có bằng chứng nó đã nằm lại trên QA5560; không copy trong audit này. Xem [candidate evidence](../../build/verification/task08/followup_20261109T063823024767Z/additional_recovery_candidate.json).

Toàn bộ JSON được kiểm chứa 1.083 content-URI strings riêng, phần lớn từ inventory/history; con số này không phải 1.083 source file đã mở thành công. Journal và sourceSignature giữ nguyên; payload JSON còn không bảo đảm ContentResolver hiện đọc được URI.

| Vấn đề còn mở | Điều đã biết | Cần gì để đóng |
|---|---|---|
|Guest private/model/external hiện tại|Restore trước đây có bằng chứng; AVD hiện tắt, chỉ hash được đĩa từ host.|Phiên được phép khởi động/đọc QA5560 hoặc clone bảo toàn; đối chiếu `run-as`/ContentResolver qua quyền hợp lệ, không install/clear.|
|SAF grants|Backup giữ preference tree `primary:Movies/XRecorder`; history còn URI tree con `primary:Movies/XRecorder/P2P3_QA_TASK07_1794105051948`.|Người dùng cấp lại qua DocumentsUI và kiểm tra mở URI; chưa biết grant nào hiện còn vì không đọc guest OS.|
|MediaStore ownership/read access|IDs/size/generation seed không đổi trong query đã lưu; incident đổi UID217→219.|Đọc metadata/quyền live theo API hợp lệ; file cũ cần consent/relink khi OS yêu cầu. Không ép owner_package_name.|
|Draft usability|JSON/reference preserved; chưa xác minh mọi source hoặc preview/export.|Kiểm source trước, rồi mở từng draft trong phiên QA được phép. Báo cáo manual sau pull đã có stale-source/ANR, không mở hàng loạt draft để thử mù.|
|`task07_subtitle_input.mp4`|Có retained host candidate ngoài 54 restored inputs.|Xác nhận nguồn cần khôi phục và guest presence; nếu thiếu, một task phục hồi riêng được phép mới copy không ghi đè.|

## SAF — hướng dẫn cấp lại thủ công, chưa thực hiện

Chỉ thực hiện trong phiên riêng được phép khởi động QA5560. Máy này vẫn giữ test-entry APK và thiếu install margin theo checkpoint cũ; nếu không có Library/Choose folder, cần giải quyết main-entry/backup/dung lượng trong task được cấp quyền riêng, không gỡ app.

1. Trong Library, chọn **Choose folder**; qua picker hệ thống chọn **Internal storage → Movies → XRecorder → Use this folder → Allow**.
2. Với URI history thuộc tree con, chọn thêm `Movies/XRecorder/P2P3_QA_TASK07_1794105051948` qua cùng picker khi cần; sau đó chọn lại tree gốc để trả bộ lọc thư viện. Không Disconnect trước.
3. Kiểm tra list/preview bằng quyền mới. Draft còn URI không đọc được: giữ backup, dùng **Replace source** để người dùng chọn đúng file; xác minh duration/nội dung trước lưu. Không sửa URI/metadata bằng script.
4. SAF không thay thế file đã mất hay tự khôi phục mọi MediaStore grant. Không chọn `Android/data` bằng đường vòng. Xem [Android SAF](https://developer.android.com/training/data-storage/shared/documents-files).

Source hiện có: `MediaCatalog` dùng OPEN_DOCUMENT_TREE và `takePersistableUriPermission`; `EditorScreen.relink` phục vụ Replace source. Không chạy các thao tác này trong audit.

## Những gì không thể khôi phục chính xác từ tư liệu hiện có

- Không có full pre-incident snapshot của app-specific external/no_backup và OS grants/ownership. Không thể suy ra danh sách mọi file đã mất, metadata filesystem gốc hoặc khôi phục chính xác trạng thái quyền chỉ từ 54 known inputs và private tar.
- Nội dung transcript đã bị cap20 loại bỏ **trước** backup 77 jobs không thể tái tạo từ journal hiện có; cần backup cũ chứa chính các record đó. Chạy lại ASR cũng không phải khôi phục bản gốc.
- Không có checksum trước sự cố cho toàn bộ public media, nên bản sao hiện còn và size/revision không đủ chứng minh byte-identical với toàn bộ trạng thái gốc.
- Cấp lại SAF có thể phục hồi quyền truy cập cần dùng; không chứng minh trạng thái OS trước sự cố đã được tái lập nguyên vẹn.

**Kết luận:** phần kiểm được trên host đã đóng, không chờ vô hạn. TASK08 giữ **PARTIAL**, sự cố uninstall trước đây vẫn là data-safety failure lịch sử. Cần quyền thao tác runtime riêng và tương tác SAF để kiểm phần còn lại; full historical equivalence cần snapshot gốc chưa có. [Post-pull integration audit](POST_PULL_TEAM_INTEGRATION_AUDIT.md) quyết định bước QA tiếp theo.
