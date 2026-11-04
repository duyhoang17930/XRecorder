# 3HRecorder

Ứng dụng quay màn hình và chỉnh sửa media bằng **Flutter**, ưu tiên **Android**. Phạm vi yêu cầu gồm công cụ nổi, Facecam, editor ảnh/video, livestream và phụ đề AI qua máy chủ.

## Trạng thái thực tế

Repo hiện có Flutter scaffold: `lib/main.dart` hiển thị “Hello World”, chưa triển khai các chức năng sản phẩm. Tên package còn là `xrecorder`, Android application ID còn là `com.example.xrecorder`; việc bootstrap hướng dẫn không tự đổi các cấu hình này.

## Tài liệu

- [Đặc tả sản phẩm](docs/APP_SPEC_VI.md).
- [Khảo sát thư viện và repo cho 56 nhóm chức năng](docs/TECH_STACK_RESEARCH_VI.md).
- [Danh mục ảnh tham chiếu](docs/REFERENCE_INDEX.md); ảnh gốc nằm trong `images/`, đang Git-ignored.

## Hướng dẫn làm việc

[AGENTS.md](AGENTS.md) là entry point cho agent. Harness đã được cấu hình ở `.claude-local/` và được giữ riêng trên máy. Nếu clone repo mà không có thư mục này, đọc manifest, source và tài liệu sản phẩm để khám phá lại; không coi local context là dependency build của ứng dụng.

Kiểm harness trên máy có bản cài:

```text
python -B .claude-local/scripts/setup_local.py --check
python -B .claude-local/scripts/check_local.py
```

## Các lệnh Flutter

Khi đã có Flutter SDK, Java/Android SDK và cấu hình local phù hợp:

```text
flutter pub get
flutter analyze
flutter build apk --debug
```

Chưa có thư mục test Dart; thêm kiểm thử theo chức năng trước khi dùng `flutter test` làm tiêu chí nghiệm thu. Kiểm tra harness không thay cho build APK hoặc kiểm thử quay màn hình trên thiết bị.
