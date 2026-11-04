# Danh mục ảnh tham chiếu

## Phase 1 implementation trace (2026-11-04)

| References | Routes / foundation | Status and evidence |
| --- | --- | --- |
| R09, R60–R61 | `/videos`, `/photos`, `/editor` | Four-tab stateful shell; sample media remains until P2. Widget tests cover tab filter/favorite/scroll retention. |
| R03, R28, R36 | `/settings`, `/settings/audio-video` | Preferences persist through the Android settings adapter; migration/restart/reset/error unit tests. Native capture application remains P4. |
| R04–R05, R42 | Center record action | Existing recording sheet retained; settings shared with persisted controller; no false recording success. |
| R15–R16 | App resource configuration | English/dark only; other locales/themes intentionally not selectable. Retaining the existing palette is a provisional implementation decision. |
| R02, R62 | `/media/:id` | Fullscreen sample detail and missing-ID fallback tested; real playback/actions remain P7. |
| R17–R19, R25, R50 | Shortcuts, trash, repair, capture, help | Later phases; P1 introduces contracts, not functioning native features or new placeholder routes. |

See [repository audit](xrecorder/repository_audit.md) and [Phase 1 validation](xrecorder/phase_1_validation.md) for implementation limits and check results.

Mã R dùng trong [bản đặc tả](APP_SPEC_VI.md). Tệp được đánh số theo tên tăng dần, không theo thứ tự thao tác. Nhấn tên màn hình để mở ảnh gốc. Ảnh gốc được giữ nguyên.

| Mã | Màn hình / trạng thái | Kích thước |
| --- | --- | --- |
| R01 | [Màn hình Android với Facecam và thanh công cụ nổi](../images/1793760712522_1972596113707275102_g3052623449332817763_52c78cb98c2f339f434ad32974397230.jpg) | 868 × 1887 |
| R02 | [Cửa sổ kết quả chụp ảnh: xóa, chỉnh sửa, chia sẻ](../images/1793760712606_1972596113707275102_g3052623449332817763_33b287f62f4d8134d852c044f108bada.jpg) | 868 × 1887 |
| R03 | [Cài đặt: lưu trữ, thùng rác, ngôn ngữ và trợ giúp](../images/1793760712733_1972596113707275102_g3052623449332817763_8aedf36072207de3a92569c28f4aadb3.jpg) | 588 × 1280 |
| R04 | [Bảng công cụ nhanh, gồm lối vào bóng nổi tùy chỉnh](../images/1793760712848_1972596113707275102_g3052623449332817763_5255f05cf7b013732e9a21a5419c8e1b.jpg) | 868 × 1887 |
| R05 | [Bảng công cụ nhanh và cấu hình quay](../images/1793760712955_1972596113707275102_g3052623449332817763_1efe264a620fcd965244a636b54d21e8.jpg) | 868 × 1887 |
| R06 | [Menu bóng nổi mở rộng khi chưa quay](../images/1793760713041_1972596113707275102_g3052623449332817763_875a84f5a8dcefcce8f23357952db3af.jpg) | 868 × 1887 |
| R07 | [Vẽ trên màn hình và nhắc xác nhận bắt đầu ghi](../images/1793760713156_1972596113707275102_g3052623449332817763_d9543253840fd519d0f2d210f6863fb3.jpg) | 868 × 1887 |
| R08 | [Thanh công cụ bút vẽ trên thư viện video](../images/1793760713255_1972596113707275102_g3052623449332817763_f23031a33c57ba510e042403b4e295cc.jpg) | 868 × 1887 |
| R09 | [Thư viện video với Facecam và các công cụ nhanh](../images/1793760713355_1972596113707275102_g3052623449332817763_37e929fe89ff629be71e8fd8fba78334.jpg) | 868 × 1887 |
| R10 | [Trình phát video: chỉnh sửa, chống nhiễu, phụ đề](../images/1793760713455_1972596113707275102_g3052623449332817763_3dc795c1f9b61bf32309e99876e3576d.jpg) | 868 × 1887 |
| R11 | [Thông báo phiên quay: tạm dừng, dừng, công cụ](../images/1793760713666_1972596113707275102_g3052623449332817763_638f8cafbde91ef55f47857bff3bf879.jpg) | 868 × 1887 |
| R12 | [Email phản hồi và thông tin bản 2.5.5.1](../images/1793760713866_1972596113707275102_g3052623449332817763_3d220e0a55c62114f73a26146732a60c.jpg) | 868 × 1887 |
| R13 | [Ghi log lỗi đang chạy: dừng và tải lên](../images/1793760713938_1972596113707275102_g3052623449332817763_a3c3de99beeb653772c06d8d87449594.jpg) | 868 × 1887 |
| R14 | [Ghi log lỗi chưa bắt đầu](../images/1793760714038_1972596113707275102_g3052623449332817763_124f7c26337a728bbe352449a88c4d12.jpg) | 868 × 1887 |
| R15 | [Chọn chủ đề: hệ thống, sáng, tối](../images/1793760714131_1972596113707275102_g3052623449332817763_6ca937d58cc2bf0b2895dd0f6c739dd7.jpg) | 868 × 1887 |
| R16 | [Hộp thoại chọn ngôn ngữ](../images/1793760714212_1972596113707275102_g3052623449332817763_70db61f030ab423e52da551398b3f7da.jpg) | 868 × 1887 |
| R17 | [Tạo lối tắt chỉnh sửa video hoặc ảnh](../images/1793760714292_1972596113707275102_g3052623449332817763_4afdddd1ec9cf4ed0b7b2bf4c980134c.jpg) | 868 × 1887 |
| R18 | [Cài đặt khác: thùng rác giữ tối đa 24 giờ](../images/1793760714384_1972596113707275102_g3052623449332817763_4eb3f4e0b44cb1db36d5532abd3df7d3.jpg) | 868 × 1887 |
| R19 | [Cài đặt sửa lỗi, tự sửa và tối ưu pin](../images/1793760714465_1972596113707275102_g3052623449332817763_5e344d9c2d6f4387156357ecccc19ca5.jpg) | 868 × 1887 |
| R20 | [Bộ thay đổi giọng nói: các preset Pro](../images/1793760714551_1972596113707275102_g3052623449332817763_7cfe3c80e85406d8ba40dba57e63bf18.jpg) | 868 × 1887 |
| R21 | [Chức năng các nút bóng nổi trước và trong khi quay](../images/1793760714643_1972596113707275102_g3052623449332817763_de11e1669a876c18f9b21bb86656c4a2.jpg) | 868 × 1887 |
| R22 | [Bóng nổi tùy chỉnh: hiển thị thời gian và gán nút](../images/1793760714725_1972596113707275102_g3052623449332817763_583d97fa643c6c2613d0372fa739d87a.jpg) | 868 × 1887 |
| R23 | [Bóng nổi tùy chỉnh: kiểu Pro, kích thước, độ mờ](../images/1793760714822_1972596113707275102_g3052623449332817763_6cc4ce0082e689b0dd952731fd1bdc31.jpg) | 868 × 1887 |
| R24 | [Hướng dẫn bật hiển thị cảm ứng từ hệ thống](../images/1793760714909_1972596113707275102_g3052623449332817763_cfe86e95e961ed720cd13570fa2c13e2.jpg) | 868 × 1887 |
| R25 | [Cài đặt công cụ, vùng quay và thời lượng](../images/1793760715014_1972596113707275102_g3052623449332817763_24f4512acf0078acf6546396c4f22f50.jpg) | 868 × 1887 |
| R26 | [Lắc để dừng quay và chỉnh độ nhạy](../images/1793760715109_1972596113707275102_g3052623449332817763_ee5d3184b424ffb9f1ef016620b6bc4d.jpg) | 868 × 1887 |
| R27 | [Hộp thoại chế độ thường và hiệu suất](../images/1793760715231_1972596113707275102_g3052623449332817763_2aff8e646b5d5a92d0425d021c5d440a.jpg) | 868 × 1887 |
| R28 | [Điều khiển quay và ẩn cửa sổ kết quả Pro](../images/1793760715314_1972596113707275102_g3052623449332817763_f128d693a146d10c6d0ff5c097c3e400.jpg) | 868 × 1887 |
| R29 | [Chọn chế độ quay từ màn cài đặt chính](../images/1793760715412_1972596113707275102_g3052623449332817763_4df6d44801f2698a2a0ae11ad8e67896.jpg) | 868 × 1887 |
| R30 | [Chọn hướng tự động, ngang hoặc dọc](../images/1793760715501_1972596113707275102_g3052623449332817763_3da39c8255a5f458c377c5e5ebbc451f.jpg) | 868 × 1887 |
| R31 | [Chọn chất lượng quay: 2K và 4K Pro](../images/1793760715595_1972596113707275102_g3052623449332817763_ec02399d750a576b4935518622dccb76.jpg) | 868 × 1887 |
| R32 | [Cài đặt âm thanh: tắt tiếng](../images/1793760715702_1972596113707275102_g3052623449332817763_e40b9d2cba58a642a678b16d7c180dea.jpg) | 868 × 1887 |
| R33 | [Cài đặt âm thanh: âm thanh nội bộ và micro](../images/1793760715806_1972596113707275102_g3052623449332817763_8c3fd0b6d920aed61964f0ec361f683f.jpg) | 868 × 1887 |
| R34 | [Cài đặt âm thanh: chỉ âm thanh nội bộ](../images/1793760715900_1972596113707275102_g3052623449332817763_01375ad55beecdcce067b0a08c80d712.jpg) | 868 × 1887 |
| R35 | [Cài đặt âm thanh: chỉ micro](../images/1793760716003_1972596113707275102_g3052623449332817763_149813f9597081bfdbda0a24f228bbb6.jpg) | 868 × 1887 |
| R36 | [Cài đặt chính và banner Pro dùng thử](../images/1793760716090_1972596113707275102_g3052623449332817763_80565e7086d6a41799b05499c4f1ae4e.jpg) | 868 × 1887 |
| R37 | [Chỉnh ảnh: crop, vẽ, chữ Pro, xoay](../images/1793760716192_1972596113707275102_g3052623449332817763_1ef9cd299296986a4c536c60e46c4b72.jpg) | 868 × 1887 |
| R38 | [YouTube Live với danh sách quyền riêng tư](../images/1793760716278_1972596113707275102_g3052623449332817763_e305f9a8f61ed85587fe4d3c28fcf5ea.jpg) | 868 × 1887 |
| R39 | [Trợ giúp phát trực tiếp YouTube](../images/1793760716361_1972596113707275102_g3052623449332817763_d4b6912ff9af2b0b211d224fcc7e6d32.jpg) | 868 × 1887 |
| R40 | [Cài đặt livestream: tài khoản, âm thanh, video, độ trễ](../images/1793760716449_1972596113707275102_g3052623449332817763_8a9e33694298f603aef5b48cf2e25139.jpg) | 868 × 1887 |
| R41 | [Tạo YouTube Live: tiêu đề, mô tả, quyền riêng tư](../images/1793760716533_1972596113707275102_g3052623449332817763_1511dd848d97e54cb2e565f1c48822d5.jpg) | 868 × 1887 |
| R42 | [Menu tạo: quay thường, vùng, thời lượng, YouTube, RTMP](../images/1793760716611_1972596113707275102_g3052623449332817763_8fd41a2f727d2a4d3cf9caa15e4e7838.jpg) | 868 × 1887 |
| R43 | [Timeline video nhiều clip và nút giữa hai clip](../images/1793760716697_1972596113707275102_g3052623449332817763_7623f34af5b69c8edd4720ee335fb5a3.jpg) | 868 × 1887 |
| R44 | [Bộ chọn video và ảnh cho trình chỉnh sửa](../images/1793760716790_1972596113707275102_g3052623449332817763_3c680795c52e8225f98a340bbbc3ae46.jpg) | 868 × 1887 |
| R45 | [Xuất video: độ phân giải, FPS và bỏ watermark](../images/1793760716888_1972596113707275102_g3052623449332817763_706651aa251f3d715925f1df9a297beb.jpg) | 868 × 1887 |
| R46 | [Thanh công cụ editor: sticker, lọc, tỷ lệ, nền, nhân bản, xoay](../images/1793760716970_1972596113707275102_g3052623449332817763_2694384d6b9ae73b2cf91798f11c95d1.jpg) | 868 × 1887 |
| R47 | [Thanh công cụ editor có tốc độ](../images/1793760717055_1972596113707275102_g3052623449332817763_5d5af03f66a0318584d01ff52f6a7884.jpg) | 868 × 1887 |
| R48 | [Thanh công cụ editor: xén, crop, âm lượng, chữ, nhạc, phụ đề](../images/1793760717141_1972596113707275102_g3052623449332817763_5a6b1e5c05d0b9459073427beb809949.jpg) | 868 × 1887 |
| R49 | [Ảnh trùng nội dung tệp với R48](../images/1793760789371_1972596113707275102_g3052623449332817763_5a6b1e5c05d0b9459073427beb809949.jpg) | 868 × 1887 |
| R50 | [FAQ lọc theo sự cố và độ chậm](../images/1793760789468_1972596113707275102_g3052623449332817763_9a1802fad6b512da2de5b2a0aba17051.jpg) | 868 × 1887 |
| R51 | [FAQ các vấn đề lưu và chia sẻ, phần danh sách tiếp](../images/1793760789577_1972596113707275102_g3052623449332817763_5364d2adc116ea7cb5e63e76ef40a5fa.jpg) | 868 × 1887 |
| R52 | [FAQ lưu và chia sẻ](../images/1793760789680_1972596113707275102_g3052623449332817763_10976b587ae6531fb328ca39f50e98be.jpg) | 868 × 1887 |
| R53 | [FAQ quyền riêng tư và đăng ký Pro](../images/1793760789793_1972596113707275102_g3052623449332817763_98c141f2463aa5a925e4170169616aab.jpg) | 868 × 1887 |
| R54 | [FAQ ghi hình và các vấn đề hiển thị video](../images/1793760789877_1972596113707275102_g3052623449332817763_a9223060179e9af2686d8a0136bdaf9e.jpg) | 868 × 1887 |
| R55 | [FAQ lỗi video và đồng bộ âm thanh](../images/1793760789966_1972596113707275102_g3052623449332817763_70c97aae5d444f82bbd81d5266eace82.jpg) | 868 × 1887 |
| R56 | [FAQ âm thanh](../images/1793760790052_1972596113707275102_g3052623449332817763_e33ee2d4f21609576e69b84080f45799.jpg) | 868 × 1887 |
| R57 | [FAQ mở câu trả lời về lỗi khi quay](../images/1793760790139_1972596113707275102_g3052623449332817763_1843ddf1d84b9ed60518f69aa7050e1c.jpg) | 868 × 1887 |
| R58 | [FAQ nhóm âm thanh, có câu hỏi Zoom và Google Meet](../images/1793760790226_1972596113707275102_g3052623449332817763_62d7ef61778fe568a65fab91256e0876.jpg) | 868 × 1887 |
| R59 | [Danh sách công cụ chỉnh sửa, phần dưới](../images/1793760790313_1972596113707275102_g3052623449332817763_dd3047665061f21e2f19a8a7a0f1e211.jpg) | 868 × 1887 |
| R60 | [Danh sách công cụ chỉnh sửa, phần trên và các nhãn Pro](../images/1793760790409_1972596113707275102_g3052623449332817763_c65c2186a93d09fbc07f8f353a52c5d3.jpg) | 868 × 1887 |
| R61 | [Tab ảnh ở trạng thái trống](../images/1793760790497_1972596113707275102_g3052623449332817763_549501f1e0af1285e233d72f75a1d0dc.jpg) | 868 × 1887 |
| R62 | [Cửa sổ kết quả quay, có mục ẩn kết quả Pro](../images/1793760790591_1972596113707275102_g3052623449332817763_a49ee522f5dc7fa366f7e6d5b6d1b8b6.jpg) | 868 × 1887 |
| R63 | [Thư viện trong lúc quay với bộ đếm thời gian](../images/1793760790686_1972596113707275102_g3052623449332817763_64f8f2563a41d9fabdd4d3d6bf3993dd.jpg) | 868 × 1887 |
| R64 | [Hộp thoại Android: chọn toàn màn hình hoặc một ứng dụng](../images/1793760790896_1972596113707275102_g3052623449332817763_22a08dd582ccb9650a389db9a58352d2.jpg) | 868 × 1887 |
| R65 | [Hộp thoại Android xác nhận chia sẻ màn hình](../images/1793760790979_1972596113707275102_g3052623449332817763_73cc2c24d914d72d55c1b67b1a16a47a.jpg) | 868 × 1887 |
| R66 | [Hướng dẫn ghi Zoom hoặc Google Meet](../images/1793760791065_1972596113707275102_g3052623449332817763_f0e4ebd6cd5ba5b40a4c8cafea45bb34.jpg) | 868 × 1887 |
| R67 | [Hướng dẫn đặt hướng quay, các bước tiếp theo](../images/1793760791146_1972596113707275102_g3052623449332817763_989846e00c30ea4e809156fa2e60c04c.jpg) | 868 × 1887 |
| R68 | [Hướng dẫn đặt hướng quay từ cài đặt](../images/1793760791225_1972596113707275102_g3052623449332817763_6f0ae610a6caa6772e2307b3b6b384f0.jpg) | 868 × 1887 |
| R69 | [Hướng dẫn hiệu ứng Facecam](../images/1793760791334_1972596113707275102_g3052623449332817763_643074e14fb1ba654ddb4b65259b3e3c.jpg) | 868 × 1887 |
| R70 | [Hướng dẫn quay có thời lượng và tự dừng](../images/1793760791419_1972596113707275102_g3052623449332817763_c04f2cef99ba0fc8966c7ee83e6edd42.jpg) | 868 × 1887 |
| R71 | [Hướng dẫn quay khu vực](../images/1793760791518_1972596113707275102_g3052623449332817763_3022f5a40332ced186b1f46fa71eb8dd.jpg) | 868 × 1887 |
| R72 | [Hướng dẫn chọn nguồn âm thanh](../images/1793760791596_1972596113707275102_g3052623449332817763_e770585696b3978f80a8c035384ad36a.jpg) | 868 × 1887 |
| R73 | [Hướng dẫn điều khiển từ thanh thông báo](../images/1793760791684_1972596113707275102_g3052623449332817763_90ad7a9d78ee22241464d19007e598f6.jpg) | 868 × 1887 |
| R74 | [Hướng dẫn điều khiển từ bóng nổi](../images/1793760791766_1972596113707275102_g3052623449332817763_14f1137841b7f2a55b565e686a34f483.jpg) | 868 × 1887 |
| R75 | [Hướng dẫn điều khiển trong app](../images/1793760791861_1972596113707275102_g3052623449332817763_361d58eec5d38aaace247618667ee17e.jpg) | 868 × 1887 |
| R76 | [Danh mục hướng dẫn và nét vẽ phủ màn hình](../images/1793760791948_1972596113707275102_g3052623449332817763_d7f254209b69f7f992a9803e458f5b1a.jpg) | 868 × 1887 |
| R77 | [Bộ chọn thời lượng theo giờ, phút, giây](../images/1793760792032_1972596113707275102_g3052623449332817763_4b299b759de9baa1d380c2c99252ce44.jpg) | 868 × 1887 |
| R78 | [Xác nhận tắt thùng rác và xóa vĩnh viễn](../images/1793760792120_1972596113707275102_g3052623449332817763_3acded6aecb4f2a4a4172068edc20673.jpg) | 868 × 1887 |
| R79 | [Thùng rác trống và thông tin giữ tối đa 24 giờ](../images/1793760792213_1972596113707275102_g3052623449332817763_4c4af1300e1f62c7bd8e5fb85947df97.jpg) | 868 × 1887 |
| R80 | [Menu nhanh: thùng rác, thời lượng, hướng dẫn, FAQ](../images/1793760792292_1972596113707275102_g3052623449332817763_db444924fa6d3a103536e20494a72c60.jpg) | 868 × 1887 |
| R81 | [Hướng dẫn tránh bị dừng bằng cài đặt tối ưu pin](../images/1793760792376_1972596113707275102_g3052623449332817763_136bfc784c4498f5e8f43a58ba97b0df.jpg) | 868 × 1887 |
| R82 | [Công cụ xén, cắt, tách và timeline](../images/1793760792470_1972596113707275102_g3052623449332817763_a3aca8e4191da6c940591a557cb8f2e4.jpg) | 868 × 1887 |
| R83 | [Thống kê dung lượng lưu trữ](../images/1793760792549_1972596113707275102_g3052623449332817763_a52c03c3737a365d86ea79dd28dfda80.jpg) | 868 × 1887 |
| R84 | [Menu video: sửa, giảm ồn, nén, GIF, chia sẻ, đổi tên, xóa](../images/1793760792656_1972596113707275102_g3052623449332817763_6aaa2f754623bf9f6284453a78e28678.jpg) | 868 × 1887 |
| R85 | [Thư viện video ở trạng thái thông thường](../images/1793760792745_1972596113707275102_g3052623449332817763_4090a1937647e3788d54652a352e67b4.jpg) | 868 × 1887 |
| R86 | [Thư viện video ở trạng thái thông thường, biến thể quảng cáo](../images/1793760792836_1972596113707275102_g3052623449332817763_df10210ffa61d3463047180681a3a30a.jpg) | 868 × 1887 |
| R87 | [Biểu mẫu phản hồi, phân loại vấn đề và đính kèm](../images/1793760792917_1972596113707275102_g3052623449332817763_4a9a431856f7c914911464697f5f06ad.jpg) | 868 × 1887 |
| R88 | [Chọn âm thanh trước khi bắt đầu quay](../images/1793760793094_1972596113707275102_g3052623449332817763_8c064d5b37bf93dddf53f85c62bc2a7c.jpg) | 868 × 1887 |
| R89 | [Giải thích và mở cấp quyền bóng nổi](../images/1793760793185_1972596113707275102_g3052623449332817763_a6d7443a0dd91c25431974425c510cf8.jpg) | 868 × 1887 |

Video mẫu: [1793760793016_1972596113707275102_g3052623449332817763.mp4](../images/1793760793016_1972596113707275102_g3052623449332817763.mp4). Metadata: khoảng 9,30 giây; kích thước mã hóa 1040 × 480. Phạm vi kiểm tra video: metadata và khung đầu; chưa đánh giá đầy đủ chuyển động/âm thanh.

R48 và R49 trùng SHA-256. Tập ảnh có 89 tệp và 88 nội dung tệp khác nhau.

## P2 catalog implementation (2026-11-04)

R09/R44/R60–R62/R83/R85–R86 now resolve to the real `/videos`, `/photos`, `/media/:id` catalog and system folder picker. Empty/error/revoked-access and search/tab-state cases are tested. External folder contents are not counted as app-owned storage. See [P2 evidence](xrecorder/phase_2_validation.md).

P10/P12 are deferred by the product owner and tracked in [GitHub issue #1](https://github.com/duyhoang17930/XRecorder/issues/1).

## P3 recording implementation (2026-11-04)

R11/R63–R65/R88 now map to native MediaProjection consent, foreground capture, in-app/notification Stop, finalization, and real media detail. The 125-second API 36 integration capture passed and independently decoded as a 125.916-second H.264 MP4. See [P3 evidence](xrecorder/phase_3_validation.md). No sample-success route remains.

## P4 configuration implementation (2026-11-04)

R27–R36/R42/R70/R77/R88 map to the shared recording form and native configuration snapshot. All four audio modes and timed stop passed the API 36 integration test. See [P4 evidence and remaining device checks](xrecorder/phase_4_validation.md).

## P5 session controls (2026-11-04)

R11/R63/R73/R75 map to native pause/resume/stop and persisted interruption state. Pause timeline and repeated stop passed API 36 capture and independent decode. Optional overlay/gesture controls remain unavailable. See [P5 evidence](xrecorder/phase_5_validation.md).

## P6 capture tools (2026-11-04)

R04–R08/R21/R24/R25/R69/R72/R75 map to screenshot capture, `/photo-tools/:id`, facecam permission/overlay and touch guidance. Image cropping/annotation is explicitly post-capture. Real saved screenshot, cropped annotated copy and encoded facecam pixels were checked on API 36. See [P6 evidence and limits](xrecorder/phase_6_validation.md).
