# UI06 — Phase A layout / inventory
[Wireframe SVG](editor_wireframe.svg) là bản phác thảo, không phải screenshot runtime.

## Video
Top: Back — project name/options — Export.
Preview: native EditorPreview giữ cùng GlobalKey, aspect ratio, lifecycle và replay frame. Play/Pause và time/scrub.
Timeline: lazy horizontal thumbnails, selected border, playhead/scrub; không list lại tất cả clip cards.
Bottom: history + Edit / Audio / Text / Subtitles / Effects / Transform / quality.
Context Edit: selected filename, trim range, Split, duplicate/order/remove/relink. Transform: crop/rotate/flip/still duration.
Back từ context đóng panel trước; tiếp theo giữ autosave/leave guard.
Landscape: preview bên trái, timeline/context bên phải. Low-height/IME: cuộn panel, không ép fixed controls overflow.
Không thay serialization, native channels, model/controller algorithms, export semantics.

## Photo
Top: Back / title / Undo / Redo.
Canvas: ảnh giữ aspect và normalized drawing coordinates; RepaintBoundary, không animate trong pointer stream.
Context phía trên toolbar, chỉ control tool đang chọn; màu mở sheet; group Draw có Pen/Eraser.
Toolbar dưới: Crop / Draw / Shapes / Text / Transform; selected state rõ; All tools giữ khả năng truy cập.
Save copy/quality footer giữ nguyên. Landscape canvas trái/panel phải; IME thấp ưu tiên TextField.
Không thêm Adjust vì backend chưa có; không giảm text scale để làm vừa.

## Settings overlap
Source P1 _duration: supporting Text ngay sát TextFormField có floating label, không vertical gap. Screenshot phù hợp giả thuyết overlap này. Chưa gọi FIXED; cần owner cho thêm spacing/label layout/localization, không thay validation 0..86400 hay settings.
## Stretch
Ảnh 170439 cho thấy vertical stretching trong overscroll Video Project. Editor đang ListView mặc định Android stretch. Sẽ thử Android gesture và khoanh đúng scroll viewport; không tắt scroll/stretch toàn app hoặc gọi giả thuyết là confirmed root cause trước test.
## Input/icon/root audit
Search và language picker đã có Clear. Project/media rename và photo text cần Clear với controller lifecycle của dialog.
Production app dùng AppIcons/Lucide; Ready đã là Lucide circleCheck, không phải Material. Chỉ đổi alias sang style badge phù hợp nếu glyph có sẵn và kiểm consumers.
StudioRootHeader đã shared; cần xác minh parent/SafeArea/actual 4 screenshots, không redesign vì report cũ gọi PASS.
