# Editor redesign — reference audit / Phase A
Ngày 11/11/2026. Đây là quyết định kiến trúc trước implementation, không phải Android acceptance.

| Reference | Điều học hỏi | Phù hợp / reuse | License, dependency risk | Quyết định |
|---|---|---|---|---|
| [CapCut video](https://www.capcut.com/resource/free-video-edit) | Chọn media trước tạo project; preview → selected clip/timeline → trim/split → export ở top | Cao về workflow; dùng controller/repository P3 sẵn có | Giao diện/asset proprietary; không copy artwork hoặc logo | Chỉ áp dụng hierarchy/workflow, nhận diện Coral riêng |
| [CapCut overlay](https://www.capcut.com/resource/free-video-overlay-effects) | Chọn layer rồi chỉnh properties/duration; phân biệt overlay với clip gốc | P3 có text/sticker/drawing, chưa có generic video-overlay track | Không giả thêm video PiP backend từ bài hướng dẫn | Mở sub-editor layers sẵn có; không quảng cáo unsupported track |
| [CapCut photo](https://www.capcut.com/resource/photo-editing-on-android) | Import trước; nhóm công cụ và context; preview là trọng tâm | Crop/Text/Draw/Shapes/Transform có sẵn; Adjust/filter photo chưa có | AI/cloud features trong bài không phải feature của app này | Không thêm Adjust giả hoặc cloud |
| [pro_image_editor](https://github.com/hm21/pro_image_editor) | GroundedMainBar nhóm sub-editors; callback close/done/history; toolbar có state riêng | Pattern tốt; direct widget gắn ProImageEditorState/configs/material_ui nên không drop-in | BSD-3-Clause, giữ copyright/conditions khi copy. Pubspec 14.21.1; material_ui, cupertino_ui, shared_preferences, http… tạo thêm hệ thống state/theme | Không thêm package/copy runtime code. Viết presentation mỏng trên state P3 hiện tại |
| [pro_video_editor](https://github.com/hm21/pro_video_editor) | Grounded example dùng sub-editors, trim tạm/commit, thumbnail cache, seek guard | Backend Media3 cùng hệ sinh thái nhưng model, controller, native plugin riêng | BSD-3-Clause. Pubspec 2.53.0; example còn pro_image_editor/video_player/google_fonts/flex_color_picker; Android Media3 1.11.1. Không có lợi ích đã chứng minh khi thay engine | Giữ Media3/composition/export hiện có; chỉ học interaction patterns |

Source đã đọc trực tiếp (snapshot ở references/, không vendor vào app):
- pro_image_editor README/LICENSE/pubspec; grounded_bottom_bar.dart, grounded_main_bar.dart, grounded_clips_bar.dart.
- pro_video_editor README/LICENSE/pubspec; video_editor_grounded_example_page.dart, video_editor_basic_example_page.dart, android/build.gradle.
- Tree identities: pro_image_editor 84ab828573f195da21c22039ea3545fad5128bc9; pro_video_editor 046d486e84b23c2603b0e94786de0e0e7e81d8b1. Đây là tree SHA, không gọi là commit SHA.
- Không tải/nhúng ảnh CapCut, không thêm package, không khẳng định license review là tư vấn pháp lý.

## Current feature → backend → presentation mới
| Tính năng thật | Chủ sở hữu / source | Presentation dự kiến |
|---|---|---|
| Trim/split/merge/order/duplicate/relink | P3 ProjectController, TimelineClip | Timeline horizontal giữ offset; chọn clip → panel Edit |
| Rotate/flip/crop, still duration | P3 controller/model | Context Transform, không show mọi slider mặc định |
| Speed, filters | P3 project_effects / composition | Nhóm Video/Effects; context Speed mở đúng category hiện có |
| Audio tracks/fades/voice/noise | P3 audio_tracks_editor / DSP | Audio → Effects category Audio; Apply/Cancel giữ local state |
| Text/sticker/drawing | P3 layers_editor | Overlays/Text entry → editor hiện có |
| Subtitle/SRT/offline ASR | P3 subtitle_editor/transcription | Subtitles entry, không tạo transcript giả |
| MP4/GIF/settings/queue | P3 existing export contract | Export top bar + quality submenu |
| Photo crop/marks/eraser/history/color | P3 PhotoToolsScreen | Toolbar icon+label, group Draw/Shapes, context panel; giữ algorithms |
| Draft create/resume/duplicate/delete | P3 repository, P2/P3 hub | Picker trước save; Cancel không tạo draft; draft cũ giữ nguyên |
| MediaStore/SAF thumbnails/find | P2 MediaScope | Một picker reuse repository, không scanner mới |
| Record/screenshot/countdown/facecam | P1 APIs | P2 presenter chỉ gọi API public; không đổi semantics |
| Region/livestream | Region card unavailable, livestream không backend/owner được xác nhận | Ẩn khỏi primary Create, giữ source/route cũ |
| Auto-stop dialog, screenshot delay/feedback | P1 recording form/native | Handoff; không sửa form hoặc delay/default |

## Safety
Baseline ghi cả dirty UI05/05B và 7 reference đã bị xóa trước task, 11 screenshot mới untracked. Không restore/xóa chúng. Không sửa MainActivity, native recording, SettingsController, recording form, original studio_create_sheet hoặc EditorPreview.kt rotation recovery.
New Create presentation phải giữ rapid-tap shield và chỉ gọi public P1 setup/screenshot APIs. Screenshot delay hiện cố định 3s; không tạo dropdown 0/5/10 giả.
