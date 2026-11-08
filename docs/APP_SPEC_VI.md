# 3HRecorder — Đặc tả app quay màn hình Android

Ngày phân tích và cập nhật: 04/11/2026. Tên sản phẩm: **3HRecorder**.

## 1. Các quyết định đã chốt với chủ sản phẩm

- Phát triển **Android trước**.
- Dùng **Flutter/Dart** cho ứng dụng; được khảo sát và tái sử dụng thư viện, website và repo ở mọi ngôn ngữ phù hợp, gồm C/C++, Java/Kotlin, C#/.NET và backend. Giữ thư viện native và kết nối khi có lợi, không bắt buộc chuyển mọi thuật toán sang Dart.
- Giữ luồng chức năng của app tham chiếu, xây dựng **nhận diện và giao diện riêng**.
- Phạm vi cần đầy đủ: quay màn hình, thư viện, chỉnh sửa, livestream, phụ đề AI và công cụ Pro. Các giai đoạn ở cuối tài liệu chỉ là thứ tự triển khai, không giảm phạm vi đã chọn.
- **Phụ đề AI offline bằng whisper.cpp** (quyết định cập nhật07/11/2026 của chủ sản phẩm, thay phương án server ban đầu). Download/import model multilingual có xác minh; không upload audio hoặc dùng paid API. Kết quả cần review. Xem [đánh giá thực thi](implementation/P2_P3_AI_SUBTITLE_EVALUATION.md).
- Chưa chọn quảng cáo, hình thức bán Pro, giá, thời gian dùng thử hoặc hạn mức AI.

Đây là đặc tả yêu cầu, không phải kết quả chạy app trên thiết bị. Mô tả scaffold “Hello World” của bản04/11 đã lỗi thời; implementation hiện tại có native recording/media/editor và offline ASR. Xem [quality report](implementation/P2_P3_FINAL_QUALITY_REPORT_VI.md) để phân biệt chức năng đã kiểm thử và gate còn mở; [khảo sát thư viện](TECH_STACK_RESEARCH_VI.md) giữ các phương án nghiên cứu lịch sử.

## 2. Nguồn và cách đọc bằng chứng

- Có **89 ảnh JPG**, gồm **88 ảnh có nội dung tệp khác nhau**. R48 và R49 trùng SHA-256.
- Đã xem toàn bộ ảnh theo bảng tổng hợp và mở riêng một số màn hình cần đọc kỹ.
- Có một video MP4 dài khoảng **9,30 giây**, kích thước mã hóa **1040 × 480**. Đã kiểm tra metadata và khung đầu; chưa đánh giá đầy đủ chuyển động và âm thanh của video. Không dùng video để khẳng định các luồng Pro.
- Số R01–R89 là thứ tự tên tệp tăng dần, **không phải thứ tự thao tác**. Giờ trên ảnh cho thấy nhiều ảnh được gửi theo chiều ngược của phiên sử dụng.
- Xem [danh mục ảnh](REFERENCE_INDEX.md) để mở ảnh gốc từ từng mã R.
- Link [Sensor Tower do người dùng cung cấp](https://app.sensortower.com/overview/videoeditor.videorecorder.screenrecorder?country=US) xác định đúng package tham chiếu, nhưng trang không trả nội dung chi tiết có thể đọc trong phiên này.
- Đã đối chiếu [trang Google Play chính thức của XRecorder](https://play.google.com/store/apps/details?id=videoeditor.videorecorder.screenrecorder&hl=en&gl=US). Ảnh phản hồi R12 cho thấy bản được chụp là **2.5.5.1**; không mặc định mô tả cửa hàng và ảnh cùng phiên bản.

Nhãn trong tài liệu:

- **Quan sát:** thấy điều khiển, nhãn hoặc trạng thái trong ảnh. Không đồng nghĩa đã chạy và kiểm thử tính năng đó.
- **Suy luận:** thiết kế chức năng hợp lý cho phần bị khóa hoặc chưa được chụp; không khẳng định XRecorder thực hiện đúng như vậy.
- **Đề xuất:** lựa chọn triển khai cho sản phẩm mới, còn có thể thay đổi.

## 3. Cấu trúc điều hướng

Thanh điều hướng tham chiếu có năm vị trí: **Video · Ảnh · nút tạo (+) · Chỉnh sửa · Cài đặt**. Đây là bốn màn hình chính và một nút mở menu tác vụ, không phải năm trang ngang hàng. Bằng chứng: R09, R42, R60, R61.

Các lớp giao diện bên ngoài màn hình chính:

- Bóng nổi có thể mở khi đang ở ứng dụng khác; menu trước khi quay và trong lúc quay khác nhau.
- Bảng công cụ nhanh, Facecam và bảng vẽ trên màn hình.
- Thông báo điều khiển phiên quay.
- Hộp thoại quyền chia sẻ màn hình do Android cung cấp.
- Cửa sổ xem nhanh sau khi quay hoặc chụp.

**Đề xuất nhận diện:** giữ khả năng truy cập nhanh các thao tác này, dùng logo, icon, kiểu chữ và hệ màu mới. Một hướng phù hợp là nền sáng/tối trung tính, màu nhấn xanh ngọc hoặc tím; nút đang quay vẫn dùng đỏ để dễ nhận biết. Chưa chốt bộ màu.

## 4. Danh mục chức năng đã nhìn thấy

| Nhóm | Quan sát được | Bằng chứng |
| --- | --- | --- |
| Thư viện video | Danh sách theo ngày, thumbnail, thời lượng, tên, độ phân giải, dung lượng, nút thao tác và cắt nhanh | R09, R63, R84 |
| Menu video | Chỉnh sửa, giảm ồn, nén, video sang GIF, chia sẻ, đổi tên, xóa | R84 |
| Phát video | Phát và tua, chỉnh sửa, chống nhiễu, phụ đề, menu thêm | R10 |
| Thư viện ảnh | Tab ảnh và trạng thái trống; chưa thấy danh sách ảnh có dữ liệu | R61 |
| Khởi động quay | Chọn âm thanh; xin quyền bóng nổi; xin chia sẻ toàn màn hình hoặc một ứng dụng | R64–R65, R88–R89 |
| Điều khiển quay | Bắt đầu trong app/bóng nổi; tạm dừng và dừng từ thông báo; bộ đếm thời gian | R06, R11, R63, R73–R75 |
| Công cụ nhanh | Chụp màn hình, bút vẽ, Facecam, quay khu vực, hẹn thời lượng, livestream | R04–R05, R42 |
| Vẽ trên màn hình | Bút, tẩy, hình chữ nhật, hình tròn, mũi tên, màu và hoàn tác | R07–R08 |
| Facecam | Lớp camera nổi trên ứng dụng khác; hướng dẫn đề cập hiệu ứng khuôn mặt | R01, R69 |
| Âm thanh | Micro, âm thanh nội bộ, cả hai, tắt tiếng; âm lượng riêng, giảm ồn, mono/stereo, giảm tiếng ứng dụng khi nói | R32–R35 |
| Đổi giọng | Bản gốc; trẻ em, phụ nữ, chú/bác, robot, ông già, quái vật có nhãn Pro; ghi mẫu và nghe trước | R20 |
| Chất lượng quay | 360p, 480p, 720p, 1080p; 2K/4K có nhãn Pro; mục cấu hình tùy chỉnh | R31 |
| Điều khiển bổ sung | Hướng tự động/ngang/dọc, chế độ thường/hiệu suất, đếm ngược, lắc để dừng và độ nhạy | R26–R30 |
| Bóng nổi tùy chỉnh | Ẩn khi quay, kiểu mặc định/tùy chỉnh Pro, kích thước, độ mờ, hiển thị thời gian, thay chức năng nút | R21–R23 |
| Ẩn thành phần phụ | Ẩn kết quả chụp, ẩn kết quả quay Pro, ẩn bóng nổi, ẩn thông báo toast | R28 |
| Chọn vùng và thời lượng | Quay phần màn hình được chọn; đặt thời lượng để tự dừng | R70–R71, R77 |
| Chỉnh video | Xén đầu/cuối, cắt đoạn giữa, tách clip; crop, âm lượng, chữ, nhạc, phụ đề, tốc độ, sticker, lọc, tỷ lệ, nền, nhân bản, xoay | R43, R46–R49, R82 |
| Ghép nội dung | Chọn video/ảnh, thêm nhiều clip vào timeline; có nút giữa hai clip nhưng chưa thấy danh sách hiệu ứng chuyển cảnh | R43–R44, R60 |
| Xuất video | 480p–4K; 2K/4K gắn biểu tượng kim cương; các mức 24/25/30/50/60 có ý nghĩa FPS dù nhãn dịch chưa đúng | R45 |
| Watermark khi xuất | Có công tắc xóa watermark gắn kim cương ở màn xuất video | R45 |
| Chỉnh ảnh | Crop, bút, chữ Pro, xoay và menu thêm; nội dung menu thêm chưa được chụp | R37 |
| Công cụ bổ sung | Phụ đề tự động Pro, nén Pro, GIF Pro; chuyển tập tin và giới thiệu ứng dụng khác có nhãn AD | R59–R60 |
| YouTube Live | Tài khoản, tiêu đề, mô tả, công khai/không công khai/riêng tư; nút bắt đầu và trợ giúp | R38–R41 |
| Cài đặt live | Đăng xuất, quản lý quyền truy cập, âm thanh, độ phân giải, chất lượng, FPS, độ trễ và chia sẻ live | R40 |
| RTMP | Có mục RTMP trong menu; chưa có màn cấu hình hoặc phiên live đang chạy | R42 |
| Lưu trữ | Đường dẫn lưu, thống kê dung lượng, thùng rác, bật/tắt thùng rác | R03, R18, R78–R79, R83 |
| Cá nhân hóa/hỗ trợ | Ngôn ngữ, theme hệ thống/sáng/tối, tạo shortcut sửa video/ảnh, FAQ, hướng dẫn, phản hồi và ghi log lỗi | R12–R19, R24, R50–R58, R66–R76, R87 |
| Ổn định | Chế độ hiệu suất, tự động sửa bản ghi hỏng, hướng dẫn xử lý System UI và bỏ tối ưu pin | R19, R27, R81 |

Google Play còn mô tả ghi tối đa 120 FPS và lưu bản nháp chỉnh sửa. Đây là thông tin từ cửa hàng, **chưa thấy màn cấu hình 120 FPS hoặc danh sách bản nháp trong bộ ảnh**. Tách riêng FPS quay và FPS xuất video; không gán 120 FPS cho trình xuất chỉ vì có quảng bá quay 120 FPS. [Nguồn](https://play.google.com/store/apps/details?id=videoeditor.videorecorder.screenrecorder&hl=en&gl=US).

## 5. Luồng quay cần triển khai

**Đề xuất**, dựa trên các điểm vào đã quan sát:

1. Người dùng chọn quay thường, quay khu vực hoặc quay có thời lượng.
2. Chọn nguồn âm thanh, hướng, chất lượng; xin quyền micro/camera khi chức năng tương ứng cần dùng.
3. Nếu cần bóng nổi, giải thích và mở cài đặt quyền hiển thị trên ứng dụng khác. Vẫn có cách điều khiển trong app/thông báo khi người dùng không bật bóng nổi.
4. Mở hộp thoại chia sẻ màn hình của Android. Chỉ tiếp tục sau khi người dùng đồng ý.
5. Nếu là quay vùng, chọn và xác nhận vùng; nếu là hẹn thời lượng, yêu cầu giá trị lớn hơn 0. Đây là **thời lượng tự dừng**, không phải lập lịch quay vào một giờ trong tương lai.
6. Chạy đếm ngược nếu bật, rồi bắt đầu phiên quay và cập nhật các điều khiển cùng một trạng thái.
7. Cho phép tạm dừng/tiếp tục, chụp và bật/tắt các công cụ được hỗ trợ. Đề xuất giữ cố định cấu hình codec trong một phiên.
8. Khi dừng: hoàn tất tệp → cập nhật thư viện → xem nhanh với phát/chỉnh sửa/cắt/chia sẻ/xóa. Nếu bật ẩn cửa sổ kết quả, bỏ bước hiển thị cửa sổ này.

Trạng thái dùng chung: `Rảnh → Chuẩn bị → Đếm ngược → Đang quay ↔ Tạm dừng → Đang lưu → Hoàn tất/Lỗi`.

Cần xử lý: hủy cấp quyền, mất quyền giữa phiên, thiết bị khóa màn hình, ứng dụng bị dừng, hết dung lượng, codec không đáp ứng, micro bị ứng dụng khác sử dụng, camera không khả dụng và xoay màn hình. Thao tác dừng lặp lại phải an toàn, không tạo hai bản ghi.

## 6. Suy luận cho các màn Pro và phần chưa được chụp

Các mô tả dưới đây là đặc tả đề xuất cho app mới, không phải kết quả đã sử dụng bản Pro của app tham chiếu.

| Tính năng | Bằng chứng hiện có | Hành vi đề xuất cho phần bị khóa/thiếu |
| --- | --- | --- |
| Quay/xuất 2K–4K | Nhãn Pro/kim cương ở R31, R45 | Kiểm tra encoder và nguồn hình; cho chọn cấu hình hỗ trợ, có thông báo khi phải hạ chất lượng; không mặc định mọi máy quay được 4K |
| Đổi giọng | Sáu preset khóa ở R20 | Ghi/nghe mẫu, chọn preset, lưu; đề xuất áp dụng cho kênh micro, giữ âm thanh ứng dụng độc lập; tắt nếu không có kênh âm thanh phù hợp |
| Bóng nổi cá nhân hóa | Kiểu tùy chỉnh Pro ở R23 | Chọn màu/biểu tượng, chỉnh kích thước/độ mờ và xem trước; chưa có bằng chứng cho phép tải ảnh cá nhân, nên chưa đưa khả năng đó thành yêu cầu bắt buộc |
| Ẩn cửa sổ kết quả | R28, R62 | Sau khi hoàn tất, lưu và cập nhật thư viện mà không mở cửa sổ xem nhanh |
| Nén video | Nút Pro ở R59–R60 | Chọn video, độ phân giải/bitrate, ước tính dung lượng, xử lý có tiến độ; xuất bản sao, giữ bản gốc |
| Video sang GIF | Nút Pro ở R59–R60 | Chọn đoạn, kích thước, FPS và lặp; xem trước rồi xuất GIF, giới hạn cấu hình theo bộ nhớ |
| Chữ trên ảnh | Nhãn Pro ở R37 | Nhập chữ, font, màu, cỡ, căn lề, nền/viền, kéo và xoay trước khi lưu bản sao |
| Xóa watermark khi xuất | Công tắc kim cương ở R45 | Bỏ lớp watermark do trình chỉnh sửa của app mới thêm vào; không hiểu đây là công cụ xóa watermark có sẵn của bên thứ ba |
| Phụ đề tự động | Nút Pro ở R60 và nút phụ đề trong editor | Luồng AI offline whisper.cpp, mô tả tại mục 7; quyền Pro chưa chốt |
| Màn mua Pro | Có banner dùng thử nhưng chưa có màn mua trong bộ ảnh | Trình bày quyền lợi, thông tin gói khi đã chốt, trạng thái mua/khôi phục/lỗi; không tự đặt giá, kỳ hạn hay thời gian dùng thử |
| Bỏ quảng cáo | Quan sát có quảng cáo, chưa có bảng quyền lợi Pro | Chỉ đưa vào quyền lợi nếu chủ sản phẩm chọn mô hình tương ứng |

**Tách trạng thái phát triển và kinh doanh:** xây dựng đủ công cụ nâng cao, tập trung quyết định quyền truy cập tại một lớp cấu hình. Khi chưa chốt kinh doanh, bản nội bộ có thể mở các công cụ để nghiệm thu; đây không phải quyết định miễn phí toàn bộ khi phát hành.

## 7. Phụ đề AI offline

**Đã chốt07/11/2026:** whisper.cpp trên thiết bị, multilingual tiny/base/small-q5_1; không upload audio hoặc gọi paid API. Mỗi job tối đa10 phút, model được tải/import theo lựa chọn người dùng và xác minh trước khi cài.

Luồng đề xuất:

1. Chọn video hoặc đoạn trong dự án; kiểm tra có âm thanh.
2. Chọn ngôn ngữ/tự nhận diện; đề xuất hỗ trợ tiếng Việt và tiếng Anh trước, chưa chốt danh sách cuối.
3. Giải thích audio ở lại thiết bị; chọn model phù hợp dung lượng, RAM và thời gian. Trích xuất edited audio theo trim/speed/mix/DSP của dự án, mono16k để nhận dạng.
4. Theo dõi tải/import model, chuẩn bị audio, load model, nhận dạng, hoàn tất/lỗi/hủy. Checkpoint job và khôi phục trạng thái sau khi mở lại app; không áp dụng kết quả đã hủy.
5. Nhận các đoạn phụ đề gồm chữ, thời điểm bắt đầu/kết thúc; sửa nội dung, ghép/tách câu và chỉnh mốc thời gian.
6. Chọn font, màu, nền, vị trí; xem trước đồng bộ với video.
7. Ghép chữ trực tiếp vào video khi xuất. Đề xuất thêm xuất SRT để dùng ngoài app; **chưa có bằng chứng app tham chiếu hỗ trợ SRT**.

Model nằm trong app private/no-backup, có SHA256/size check và atomic install. Không cần khóa dịch vụ AI. Tách riêng tác vụ Delete model do người dùng chọn; không xóa draft/media khi cleanup. Không mặc định phụ đề tự động bao gồm dịch, lồng tiếng hoặc phụ đề trực tiếp lúc livestream.

Tiêu chí nghiệm thu: sửa được câu và thời gian, không có đoạn có thời gian âm/đảo thứ tự, xuất đúng nội dung xem trước, báo rõ trường hợp video không có giọng nói hoặc tác vụ thất bại, hủy thật và không tạo job/output trùng. Cần review kết quả và benchmark corpus/device; không suy độ chính xác chung từ một mẫu.

## 8. Livestream YouTube và RTMP

**Quan sát:** màn tạo YouTube Live và cài đặt có trong R38–R41; RTMP chỉ có điểm vào R42. Chưa thấy phiên live đang chạy.

Đề xuất YouTube: kết nối tài khoản, chọn tiêu đề/mô tả/quyền riêng tư, cấu hình âm thanh/video, kiểm tra khả năng phát trực tiếp của tài khoản, bắt đầu và kết thúc phiên. Không áp dụng thời gian chờ kích hoạt cố định chỉ vì hướng dẫn cũ trong ảnh đề cập 24 giờ; xác minh điều kiện thực tế khi tích hợp.

Đề xuất RTMP/RTMPS: nhập tên đích, URL máy chủ và stream key; kiểm tra thiếu/sai dữ liệu, cho lưu cấu hình và thử kết nối. Che stream key khi hiển thị, không ghi key vào log phản hồi.

Màn đang live cần đồng hồ, trạng thái kết nối, âm lượng và nút kết thúc. Xử lý mất mạng, thử kết nối lại có giới hạn và báo thất bại. Chat, số người xem, đọc bình luận, lưu bản quay song song và phát nhiều nền tảng đồng thời **chưa được chứng minh trong ảnh và chưa đưa thành yêu cầu mặc định**.

## 9. Thư viện, chỉnh sửa và các công cụ

**Thư viện đề xuất:** nhóm theo ngày, phát, đổi tên, chia sẻ, xóa và phục hồi. Với ảnh, bổ sung danh sách và xem ảnh tương ứng vì bộ ảnh chỉ có màn trống. Bộ chọn nội dung cho editor hỗ trợ ảnh/video; không mặc định đã có tìm kiếm/sắp xếp ở thư viện chính chỉ vì bộ chọn tệp có icon tìm kiếm.

**Video editor đề xuất:** timeline nhiều clip theo thứ tự, xén/cắt/tách, crop/xoay, tốc độ, tỷ lệ/nền, âm lượng, nhạc, chữ/sticker/filter và phụ đề. Các chi tiết chưa thấy như thư viện nhạc, danh sách font, mức tốc độ, transition và hiệu ứng cụ thể được thiết kế riêng. Dự án lưu không phá hủy nguồn, hỗ trợ bản nháp và xuất bản sao. Có tiến độ, hủy và thông báo lỗi; khả năng tiếp tục một tác vụ xuất bị ngắt phải xác minh theo pipeline, không mặc định có.

**Chỉnh ảnh đề xuất:** crop, xoay, vẽ và chữ; thao tác lưu tạo bản sao. Nội dung menu thêm chưa rõ, không tự thêm AI xóa vật thể hoặc làm đẹp.

**Giảm ồn:** phân biệt tùy chọn giảm ồn trong lúc quay với tác vụ giảm ồn của tệp đã quay; cần nghe so sánh và cho xem/nghe trước nếu hỗ trợ.

**Thùng rác:** ảnh R18/R79 ghi giữ tối đa **24 giờ**, còn Google Play mô tả **3 ngày**. Tạm lấy 24 giờ theo phiên bản trong ảnh và đặt thành cấu hình có thể thay đổi. Có hạn xóa, phục hồi, xóa vĩnh viễn; khi tắt thùng rác phải giải thích việc xóa các tệp đang nằm trong đó như R78.

**Chuyển tập tin:** mới thấy tên và nhãn AD, chưa biết dùng mạng nội bộ, trình duyệt hay cơ chế khác. Đề xuất trước mắt dùng chia sẻ tệp của Android cho chức năng cơ bản; nếu cần chuyển qua Wi-Fi phải đặc tả riêng. Mục giới thiệu ứng dụng khác là vị trí quảng bá, không phải chức năng xử lý media.

**Hỗ trợ:** FAQ theo nhóm, hướng dẫn các thao tác, biểu mẫu phản hồi có phân loại/đính kèm; log chẩn đoán chỉ thu khi người dùng bật và chủ động gửi. Thông tin tài khoản trong ảnh không được dùng làm dữ liệu mẫu cho sản phẩm.

## 10. Các ràng buộc kỹ thuật ảnh hưởng trực tiếp đến sản phẩm

Đây là cơ sở để triển khai đúng chức năng Android đã chọn:

- Mỗi phiên MediaProjection cần sự đồng ý của người dùng. Với Android 14+, phải khai báo foreground service phù hợp và không tái sử dụng token cho nhiều phiên; xử lý callback khi hệ thống dừng chia sẻ. [Android Developers — Media projection](https://developer.android.com/media/grow/media-projection).
- Thu âm thanh nội bộ có API từ Android 10, nhưng phụ thuộc chính sách thu âm của ứng dụng nguồn; không hứa ghi được âm thanh mọi ứng dụng, cuộc gọi hoặc cuộc họp. [Android Developers — Capture video and audio playback](https://developer.android.com/media/platform/av-capture).
- Các nút “ẩn toast” hoặc “ẩn bóng nổi” chỉ điều khiển thành phần của app; không được diễn giải thành ẩn chỉ báo ghi màn hình bắt buộc của Android.
- “Hiển thị cảm ứng” trong R24 dẫn người dùng tới tùy chọn nhà phát triển; không mặc định app thường có thể bật trực tiếp cài đặt hệ thống đó.
- Không cam kết quay được nội dung đã được ứng dụng/hệ thống bảo vệ. Các mục sửa System UI hoặc sửa tệp hỏng chỉ thực hiện trong khả năng Android và cấu trúc tệp còn khôi phục được.
- 2K/4K/FPS cao tùy thuộc độ phân giải nguồn và năng lực encoder; nâng kích thước tệp không tạo thêm chi tiết cho nguồn thấp hơn. Kiểm tra cấu hình thay vì chỉ hiển thị nhãn Pro.
- Facecam/bút vẽ phải xuất hiện đúng trong kết quả thực tế; đặc biệt kiểm tra khi chỉ chia sẻ một ứng dụng, không mặc định lớp phủ sẽ được ghi giống chia sẻ toàn màn hình.

**Đã chốt Flutter. Đề xuất kiến trúc:** Flutter/Dart cho giao diện và luồng ứng dụng; plugin Android bằng Kotlin/Java cho MediaProjection, mã hóa, trộn âm thanh và livestream; C/C++ qua JNI/FFI khi cần DSP; cơ sở dữ liệu cho thư viện/dự án, cấu hình cục bộ cho cài đặt; backend riêng cho tác vụ AI. Ưu tiên tái sử dụng RootEncoder và các editor đã có trước khi tự viết lõi media. Các ứng viên cụ thể và giới hạn được ghi ở [khảo sát công nghệ](TECH_STACK_RESEARCH_VI.md). Đề xuất mốc Android tối thiểu 10 để đồng nhất khả năng thu âm nội bộ, còn cần cân đối tập thiết bị.

Với trình chỉnh sửa, đánh giá Media3 Transformer cho cắt, crop, chuyển mã và hiệu ứng. Cần thử nghiệm riêng chữ/phụ đề, ghép âm thanh, đổi giọng, GIF và livestream trước khi chốt toàn bộ thư viện; không coi một thư viện sẽ tự bao phủ tất cả chức năng. [Android Developers — Media3 Transformer](https://developer.android.com/media/media3/transformer).

## 11. Thứ tự triển khai cho phạm vi đầy đủ

1. **Nền tảng:** nhận diện, điều hướng, cài đặt, mô hình phiên quay/dữ liệu, cấp quyền và backend AI cơ bản.
2. **Quay và lớp phủ:** âm thanh, pause/resume, thông báo, bóng nổi, vùng quay, thời lượng, Facecam, bút và thư viện.
3. **Editor và xuất:** timeline, ảnh/video, các công cụ chỉnh sửa, xuất chất lượng cao, bản nháp, nén, GIF, giảm ồn và đổi giọng.
4. **Phụ đề AI:** xử lý qua backend, sửa phụ đề, xem trước và xuất.
5. **Livestream:** YouTube và RTMP, trạng thái phiên, xử lý lỗi kết nối.
6. **Hoàn thiện phát hành:** cấu hình quyền Pro theo mô hình đã chốt, thùng rác, hỗ trợ, kiểm tra thiết bị và độ ổn định.

Tất cả sáu phần nằm trong mục tiêu đầy đủ. Nghiệm thu theo từng phần giúp phát hiện sớm rủi ro codec, âm thanh và kết nối trước khi ghép toàn bộ app.

Các kiểm tra quan trọng: đối chiếu video/âm thanh sau pause và đổi hướng; dừng từ bóng nổi/thông báo/hệ thống; hủy quyền; thiếu dung lượng; bản xuất giữ đúng timeline/phụ đề; mất mạng lúc live/AI; phục hồi và hết hạn thùng rác; quyền Pro thay đổi và khôi phục mua nếu triển khai thanh toán. Kiểm tra trên máy thật thuộc nhiều hãng, không chỉ emulator.

## 12. Tên sản phẩm đã chốt

Tên hiển thị: **3HRecorder**. Tên dự án Dart đề xuất: `three_h_recorder`, vì tên package Dart phải là định danh hợp lệ và không bắt đầu bằng chữ số. Nhận diện riêng, giữ phạm vi chức năng đã chọn. Application ID phát hành sẽ chốt khi tạo cấu hình phân phối.

## 13. Điểm cần chủ sản phẩm chốt tiếp

- Mô hình kinh doanh: quảng cáo, Pro một lần/thuê bao, quyền lợi và hạn mức AI. Có thể quyết định sau khi có bản nội bộ để đánh giá chi phí và trải nghiệm.
- Trước khi tích hợp dịch vụ thật: tài khoản/hạ tầng backend, nhà cung cấp AI, cấu hình YouTube và chính sách lưu dữ liệu; không cần mật khẩu hoặc khóa bí mật trong chat.

Không cần mua Pro của app tham chiếu để hoàn thiện các luồng đề xuất trong tài liệu. Những phần chưa thấy đã được ghi rõ để có thể thiết kế và nghiệm thu theo mục tiêu của sản phẩm mới.
