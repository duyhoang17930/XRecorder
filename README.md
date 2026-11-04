# XRecorder 0.1.0

Android screen recorder and non-destructive media editor built with Flutter and native Android MediaProjection/Media3. Supports Android API 24+, with internal audio on API 29+ and device-dependent codecs/camera behavior.

```sh
flutter pub get
flutter run -d <android-device-id>
```

Implemented: real media catalog and SAF folder access; recording with audio, pause/resume, timers and interruption recovery; screenshot/crop/annotation and facecam; preview/share/rename/trash/restore; persisted editor drafts, trim/split/merge/crop/rotate/effects; MP4/GIF export queue; settings, searchable help and consent-based support handoff. Settings and drafts persist locally. Export should run with the app open.

AI subtitles and livestream are intentionally deferred under [issue #1](https://github.com/duyhoang17930/XRecorder/issues/1). Ads, premium entitlements, floating recording controls and shake-to-stop are not exposed. English/dark resources only. Physical-device and production release gates remain open; see [release validation](docs/xrecorder/phase_13_validation.md).

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
