# Phase 1 — app foundation

Scope: `IMPLEMENTATION_PHASES.md` P1, not the differently numbered master-plan delivery table.

Implemented:

- Four persistent tab navigators with center recording sheet, retained sample filters/favorites/scroll, fullscreen detail/settings and missing-media/unknown-route fallback.
- Android preferences adapter, startup restore, versioned migration, value validation, ordered atomic writes, visible errors, retry, and durable reset.
- Typed media, recording, project, trash, background-job and repository contracts; immutable recording configuration mapping from current preferences.
- Explicit English/dark resource configuration, existing token/component reuse, speculative Pro card removed.

Automated coverage:

- New controller restart, consecutive writes, durable reset, immutable session snapshot, legacy migration, invalid values, corrupt/future document preservation, failed write/retry.
- Existing UI navigation and sample behavior; photo filter/favorite/scroll preserved through tab switching.
- 320dp baseline routes; 360dp routes at 1.3 text scale; missing media and unknown routes.

Native recording, real media catalog, production help/trash/editor/live routes, other locales/themes, and physical-device certification are outside P1.

## Results (2026-11-04)

- `dart format lib test`: clean.
- `flutter analyze`: no issues.
- `flutter test`: all 10 tests passed.
- `flutter build apk --debug`: passed; APK at `build/app/outputs/flutter-apk/app-debug.apk`. First build took about 15 minutes on this host.
- `git diff --check`: clean.
- Android restart acceptance: **not verified**. Pixel_8 remained offline in ADB after normal launch and a cold, headless software-graphics launch. No physical Android device was connected. The task-owned emulator processes were stopped afterward.

P1 code and host checks are implemented; final device acceptance remains open. Do not treat the controller/store unit test as proof of persistence across Android process death. P2 is not started in this commit.

## Android restart acceptance procedure

1. Build/install the debug APK on an online Android device.
2. Open Settings → Resolution & Video Quality; choose 720p/30 FPS and Internal Audio. Change countdown to 5 seconds.
3. Force-stop `com.xrecorder.xrecorder`, launch again, and check both Settings and the recording-options sheet retain the choices.
4. Reset defaults in the recording sheet, force-stop/relaunch, and verify defaults return.
5. Switch between Video/Photos/Settings after scrolling and filtering; verify the origin list is retained. Open an unknown media ID and verify the unavailable state.

No capture permission should be requested by any of these preferences operations. Changing these values does not yet configure a real encoder.
