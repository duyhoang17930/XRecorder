# 3HRecorder — QA chỉ dành cho điện thoại Android thật

**Trạng thái:** Chuẩn bị cho chiến dịch QA sau khi hoàn tất các prompt chức năng và UI/UX. **19 ca tổng cộng**, bao gồm 4 ca bổ sung sau Prompt 03B.  
**Kết quả:** Tất cả **NOT RUN**. Không suy diễn PASS từ emulator hoặc unit test.  
**Mục đích:** Chỉ giữ những phép thử cần phần cứng, Android/OEM, mạng di động hoặc đánh giá cảm nhận trực tiếp của con người. Mọi test chức năng thông thường phải nằm trong test matrix của prompt tương ứng, **không thêm vào đây**.

## Cách thực hiện

Trên máy QA được thành viên tự nguyện cung cấp, ghi: hãng/model, Android/API, chip/ABI, RAM, cấu hình codec, phiên bản app và SHA APK. Cài hoặc cập nhật bản candidate theo cách giữ nguyên dữ liệu; không reset máy hay xóa media cá nhân. Chỉ dùng file/session QA. Dùng quyền Android bình thường. Với mỗi ca chỉ ghi **PASS / FAIL / BLOCKED / NOT RUN**, nêu thiết bị, lỗi tái hiện, và đường dẫn bằng chứng (logcat, MP4, ảnh/video, thông số). Không đăng tải âm thanh/ảnh cá nhân hoặc token livestream lên báo cáo.

## A. Recording và âm thanh phần cứng

| ID | Ca cần máy thật | Thao tác kiểm tra nhanh | Tiêu chí chính | Trạng thái |
|---|---|---|---|---|
| PDH-01 | **Microphone thật** | Quay 60 giây với giọng nói/tiếng vỗ có mốc thời gian; thử gain hợp lệ | Không mất đoạn, vỡ tiếng bất thường; AAC giải mã và khớp mốc | NOT RUN |
| PDH-02 | **Internal + Mixed Audio trên máy thật** | Dùng nguồn cho phép audio capture, thu Internal và Mixed với cue mic phân biệt | Đúng nguồn, không mất mẫu, không lệch nguồn và tôn trọng capture policy | NOT RUN |
| PDH-03 | **Lỗi audio 128 ms, A/V sync và video ~9 FPS trên emulator** | Quay 5 phút với nguồn chuyển động/âm thanh đã định danh; đối chiếu frame ID, cue, waveform và counters | Xác định lỗi có tái hiện trên chip/driver thật không; không có freeze/drift bất thường | NOT RUN |
| PDH-04 | **Encoder phần cứng và chất lượng codec** | Thử H.264/H.265, độ phân giải và FPS được *thiết bị thực* báo hỗ trợ | File đúng metadata, khung hình thực, decode đầy đủ, không nóng/nghẽn sớm | NOT RUN |
| PDH-05 | **Android/OEM khi chạy nền** | Quay → Home → app khác → khóa/mở khóa → xoay màn hình → Stop/notification | Service và MediaProjection xử lý theo quy định OS, không crash hoặc báo Saved giả | NOT RUN |
| PDH-06 | **Đổi audio route, quyền mic, tranh mic** | Cắm/rút tai nghe hoặc Bluetooth nếu có, bật/tắt mic privacy, thử app QA khác dùng mic | Không crash/treo, báo mất nguồn rõ ràng, không làm hỏng file | NOT RUN |

## B. Camera và bóng nổi ngoài app

| ID | Ca cần máy thật | Thao tác kiểm tra nhanh | Tiêu chí chính | Trạng thái |
|---|---|---|---|---|
| PDH-07 | **Facecam bằng camera trước/sau thật** | Record với Facecam, đổi camera, resize, thử góc máy/ánh sáng | Đúng hướng hình, vị trí, độ rõ, đồng bộ với mic và video | NOT RUN |
| PDH-08 | **Camera/OEM permissions và tranh camera** | Thu hồi quyền camera giữa phiên, thử privacy toggle và app QA khác dùng camera | Xử lý lỗi an toàn, giải phóng camera/overlay, không giữ frame cũ sai | NOT RUN |
| PDH-09 | **Floating Ball ngoài 3HRecorder** | Cấp quyền overlay → Home → mở app khác → kéo/bám cạnh/mở menu/Stop | Ball hiện đúng trên launcher/app khác, không bị OEM chặn bất ngờ; chạm được | NOT RUN |
| PDH-10 | **Drawing/overlay và cảm ứng thật** | Vẽ, Undo/Clear, thoát Draw, chạm app bên dưới, xoay màn hình | Không ăn nhầm touch, không che controls; nét vẽ đúng trong video | NOT RUN |

## C. Mạng, AI và trải nghiệm thiết bị

| ID | Ca cần máy thật | Thao tác kiểm tra nhanh | Tiêu chí chính | Trạng thái |
|---|---|---|---|---|
| PDH-11 | **Livestream qua mạng thiết bị** | RTMP/RTMPS với endpoint QA; thử Wi-Fi ⇄ mạng di động, chập chờn, reconnect | Không lộ stream key, thông báo đúng và phục hồi hợp lệ; audio/video không drift | NOT RUN |
| PDH-12 | **Whisper offline trên CPU/RAM ARM thật** | Chạy Tiny và model phù hợp với thiết bị trên clip tiếng Việt/Anh; chuyển app, Cancel | Không OOM/ANR, inference offline, xử lý memory pressure đúng | NOT RUN |
| PDH-13 | **Pin, nhiệt, throttling, tài nguyên** | Một phiên Recording 5–10 phút kết hợp đo CPU/RAM/pin/nhiệt; quan sát FPS theo thời gian | Không sụt chất lượng nghiêm trọng, memory leak hoặc nóng bất thường không giải thích được | NOT RUN |
| PDH-14 | **TalkBack/cử chỉ cảm ứng thực tế** | Bật TalkBack, kiểm các màn hình trọng yếu; vuốt Back ở player khi controls đang hiện | Focus/nhãn/target đúng, có thể hoàn thành luồng mà không bị kẹt | NOT RUN |

## D. Ca tùy thiết bị có sẵn

| ID | Ca cần máy thật | Khi nào thực hiện | Tiêu chí chính | Trạng thái |
|---|---|---|---|---|
| PDH-15 | **Thẻ SD/SAF và bộ nhớ OEM** | Chỉ nếu điện thoại thật có thẻ SD hoặc provider OEM không tái hiện được trên emulator | Cấp/thu hồi quyền và import/copy an toàn, không mất file gốc | NOT RUN |

## E. Bổ sung sau Prompt 03B — kiểm thử máy thật cuối dự án

**Tất cả NOT RUN.** Chỉ thực hiện trong chiến dịch QA sau khi các prompt chức năng/UI đã xong. Các ca này bổ sung kiểm chứng trên máy thật; không thay thế việc Codex sửa và kiểm thử bằng emulator trước đó.

| ID | Ca cần máy thật | Thao tác kiểm tra nhanh | Tiêu chí chính | Trạng thái |
|---|---|---|---|---|
| PDH-16 | **Bóng nổi hiện với người dùng nhưng không nằm trong MP4 — yêu cầu bắt buộc** | Quay màn hình động có mẫu màu/frame ID; bật Floating Ball từ thông báo và từ nút trong app *nếu đã triển khai*; kéo, mở rộng, Pause/Resume rồi Stop; xem trực tiếp màn hình và giải mã MP4 các đoạn tương ứng | Người dùng nhìn thấy/bấm được bóng nổi; video **không có bóng/menu**, **không có ô đen hoặc vùng pixel mất**; nội dung nền vẫn đúng. Nếu chưa có giải pháp hợp lệ: FAIL/BLOCKED theo nguyên nhân, **không đánh PASS** | NOT RUN |
| PDH-17 | **Menu bóng nổi mới, icon Lucide và cảm ứng** | Bật bóng trên Home và app khác; mở menu, kiểm icon, thời gian, Collapse/Stop/Undo/Clear, kéo sang hai cạnh, xoay dọc/ngang | Bố cục gọn, không bị cắt, icon đúng chức năng, vùng chạm không chồng, không bấm nhầm Stop; hoạt động theo chính sách OEM | NOT RUN |
| PDH-18 | **Thanh Recording và Settings trên màn hình thật** | Khi quay, vào Video Library xem thanh Recording trên bottom nav; kiểm icon khác biệt của Recording settings/Floating controls; so khoảng cách tiêu đề Settings và Editing studio; thử 150%/200% text, tiếng Việt và RTL nếu hỗ trợ | Không che tab/nội dung, khoảng cách thống nhất, chữ không tràn, các nút vẫn chạm được, câu dịch không gây hiểu nhầm | NOT RUN |
| PDH-19 | **Screenshot regression trên máy OEM** | Chụp một ảnh ở ngoài app bằng consent bình thường; chụp với delay, quay màn hình hoặc mở bóng nổi trước đó; mở Photo Library/Photo Editor | Có đúng một PNG cho mỗi lần được chấp nhận, pixel và orientation đúng, không ảnh hưởng bởi overlay/quyền của OEM, không có file trùng | NOT RUN |

**Quyết định sản phẩm chưa đạt:** Yêu cầu PDH-16 *không phải* tính năng đã hoàn thiện. Báo cáo Prompt 03B chỉ xác nhận lựa chọn “Show controls in video” qua notification và MP4 có thể ghi cả bóng. Codex phải làm rõ khả năng loại trừ overlay bằng API được Android hỗ trợ, kiểm chứng cả pixel nền, và không dùng API ẩn hoặc che đen để báo PASS. Nếu không thực hiện được an toàn, giữ trạng thái chưa đạt và báo rõ lựa chọn sản phẩm; không ngầm thay yêu cầu người dùng.

## Các vấn đề **không** đưa vào file này

- Screenshot delay, tìm kiếm/sắp xếp media, rename, Trash/Restore, Trim/Split, Photo Editor, SRT/export, settings persistence: **test bằng emulator/host trước và trong từng prompt**.
- Điều tra vì sao AVD cũ không còn Tiny model, source115 hoặc recovery state: **để trong TASK10 bug register / preservation investigation**, không phải ca QA máy thật.
- YouTube OAuth, trusted RTMPS certificate/hostname, kiểm thử server ngoài: **cần dịch vụ/credential**, không nhất thiết cần điện thoại thật; để Prompt10/release matrix.
- Những chức năng chưa hoàn thiện: **không gán BLOCKED cho tất cả ở đây**; developer chịu trách nhiệm hoàn thiện và kiểm chứng bằng công cụ có thể dùng trước khi chuyển QA vật lý.

## Sau mỗi prompt

Chỉ thêm một ca mới nếu có **lý do rõ ràng bắt buộc dùng thiết bị thật**; nếu trùng ca hiện có thì bổ sung ghi chú, không tạo test case mới. Giữ file ngắn gọn. Sau khi hoàn tất các prompt và UI/UX, team chạy một chiến dịch QA thống nhất, sửa lỗi được phát hiện và kiểm thử lại ca bị ảnh hưởng. Máy thứ hai/OEM khác được khuyến khích nhưng chỉ ghi PASS đúng cho thiết bị đã thử.

**Nguồn trạng thái:** TASK10_FINAL_HANDOFF.md, TASK10_FEATURE_MATRIX.md, TASK10_BUG_REGISTER.md và Prompt01 handoff/quality reports. Các kết quả lịch sử dùng để định nghĩa thử nghiệm, **không phải kết quả QA máy thật**.
