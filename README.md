# 3HRecorder 0.1.0

Android screen recorder and non-destructive media editor built with Flutter and native Android MediaProjection/Media3. Supports Android API 24+, with internal audio on API 29+ and device-dependent codecs/camera behavior.

```sh
flutter pub get
flutter run -d <android-device-id>
```

Implemented: real media catalog and SAF folder access; recording with audio, pause/resume, timers and interruption recovery; screenshot/crop/annotation and facecam; preview/share/rename/trash/restore; persisted editor drafts, trim/split/merge/crop/rotate/effects; MP4/GIF export queue; settings, searchable help and consent-based support handoff. Settings and drafts persist locally. Export should run with the app open.

The UI uses Dark Bento Studio, with persisted Dark/Light/System appearance across the app and video editor. The video preview keeps a black media surface. UI language is English. The five-position navigation keeps Create (+) as an action menu; reselecting a tab scrolls its content to the top. See the [design system and validation report](docs/ui/task01/DESIGN_SYSTEM.md) and [emulator screenshots](docs/ui/task01/SCREENSHOTS.md).

AI subtitles and livestream are intentionally deferred under [issue #1](https://github.com/duyhoang17930/XRecorder/issues/1). Ads, premium entitlements, floating recording controls and shake-to-stop are not exposed. Physical-device and production release gates remain open; see [release validation](docs/xrecorder/phase_13_validation.md).

```sh
flutter analyze
flutter test
flutter test integration_test/editor_engine_test.dart -d <android-device-id>
flutter build apk --release
```

Integration recording tests require accepting Android permission and screen-sharing prompts. Test media is saved to the device. Release builds are unsigned unless all four environment variables are configured: `XRECORDER_STORE_FILE`, `XRECORDER_STORE_PASSWORD`, `XRECORDER_KEY_ALIAS`, `XRECORDER_KEY_PASSWORD`. Never commit signing material. A release artifact is not permission to publish; identity, signing, privacy/store declarations and device validation must be completed first.

Project references:

- [Product specification](docs/APP_SPEC_VI.md)
- [Technology research](docs/TECH_STACK_RESEARCH_VI.md)
- [Reference index](docs/REFERENCE_INDEX.md)
- [Global UI design system — TASK 01](docs/ui/task01/DESIGN_SYSTEM.md)
- [Typography, Lucide and minimal UX — TASK 02](docs/ui/task02/REPORT_VI.md)
- [UI refinement and bug fixes — TASK 02.1](docs/ui/task021/REPORT_VI.md)

The current UI keeps offline Manrope, uses Lucide through `AppIcons`, and shows capture states with both an icon and a label. See [16 updated screenshots](docs/ui/task02/SCREENSHOTS.md).

Run visual/profile checks only on a test emulator with data you can replace. On this Flutter SDK, `flutter drive` uninstalls its app when it finishes unless `--keep-app-running` is supplied; this resets private app data. Use the following command and reinstall the production entry point afterward without uninstalling:

```sh
flutter drive --no-dds --profile --keep-app-running --driver=test_driver/design_system_driver.dart --target=integration_test/design_system_test.dart -d <test-device-id>
flutter build apk --debug
```

Task 02.1 has a guarded runner which verifies the dedicated AVD name before touching the test app:

```powershell
.\tool\verify_ui.ps1 -Mode visual
# Native mode also needs accepting capture prompts and choosing Movies/XRecorder.
.\tool\verify_ui.ps1 -Mode native
```

It requires `ThreeHRecorder_Task021` on `emulator-5560`, uses debug assertions and `--keep-app-running`, and saves evidence under `docs/ui/task021/`. Media updates use Android content events plus a change check on resume; there is no periodic library polling. Build `lib/main.dart` afterward and reinstall that APK with `adb -s <verified-test-device> install -r`, without uninstalling.
