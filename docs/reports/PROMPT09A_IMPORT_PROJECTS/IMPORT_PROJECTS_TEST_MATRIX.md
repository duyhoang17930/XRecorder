# Prompt 09A — Import and project test matrix

**Device:** Pixel_7 AVD (`emulator-5554`), Android 17 / API 37 / x86_64

**Installed APK SHA-256:** `B822F2234D2C5D0FC3EF87B922CDC0EAE9A8D5895DAE2EA6C60F2E59354B7A6C`

**Installed APK matched the current local debug APK; no install/update was needed.**

## Android cases

| ID | Status | Input and evidence |
|---|---|---|
| I01 — Open video via Media Library | PASS | Opened existing app-owned `Recording_1794676788879.mp4`; details showed `video/mp4`, 735.5 KiB and 13s; native preview opened. |
| I02 — Select supported video via SAF | PASS | Selected `Prompt08_ASR_JFK_20261116.mp4` from its SAF tree. Library showed 137.2 KiB; details showed `video/mp4`, 11s and 320×180; preview rendered. Project source remained a `content://` tree/document URI. |
| I03 — Select supported photo via picker | PASS | Selected task-owned `saf_fixture.png` from `primary:Documents/Prompt05_SAF_QA_20261115`; details showed `image/png`, 64×64; Photo Editor opened. No edit or save-copy was invoked. |
| I04 — Select audio for editor | PASS | `ACTION_OPEN_DOCUMENT` audio picker selected task-owned `qa_audio_1s.wav` (32,044 bytes). Audio editor reported 1s; saved track references the original SAF document URI. |
| I05 — Reopen previously selected SAF folder | PASS | Selected the Prompt08 tree and force-stopped/reopened the app. The folder selection remained and the one video remained visible. |
| I06 — Verify folder enumeration and persistence | PASS | The Prompt08 tree enumerated its one direct video and its persisted read grant survived process restart. The known primary task fixture tree enumerated its direct PNG. The selected `Prompt05__SS` tree returned zero because it is empty. |
| I07 — Reopen existing project/draft | PASS | Reopened existing Prompt08 draft `project_1794804603075477`; preview/editor opened with the original video source. No original project was edited. |
| I08 — Save/reopen task-owned mixed edit | PASS | Task draft `project_1794820476111724` contains the Prompt08 clip, two subtitle cues and one 1s audio track. After process restart, both cues (0–5.4s and 5.4–10.8s) and one audio track were present. |
| I09 — Reopen AI subtitle project with cues | PASS | Existing cue-bearing draft showed the exact two Prompt08 cue texts and timings in the subtitle editor. No Whisper inference was run. |
| I10 — Detect missing source safely | PASS | On task draft `project_1794820069846523`, changed only its clip URI to a controlled nonexistent task-fixture document URI. Preview showed a clear inaccessible-source message; project, timeline, audio track and edits remained available. |
| I11 — Relink task-owned project source | PASS | Used **Replace source** to choose the valid 11s Prompt08 SAF video. Preview recovered; project kept its 0–11s trim and audio track. After process restart, preview and track still loaded. |
| I12 — Picker cancel/error recovery | PASS | Opened Add audio file, backed out of the Android picker, and returned to the existing one-track dialog. No blank screen/spinner; the track remained intact. Unsupported-codec and revoked-grant branches were not separately simulated. |

### Task-owned test inputs

- Photo fixture: `saf_fixture.png`, 237 bytes, `primary:Documents/Prompt05_SAF_QA_20261115`.
- Video fixture reused: Prompt08 `Prompt08_ASR_JFK_20261116.mp4`, 137.2 KiB, 11 seconds, 320×180.
- Audio fixture: `qa_audio_1s.wav`, 32,044 bytes, 1 second, 16 kHz mono PCM16. It was copied once to `primary:Documents/PROMPT09A_IMPORT_QA_20261116` after checking `/data` space.
- Existing app-owned MediaStore video reused for I01: `Recording_1794676788879.mp4`.
- Existing cue-bearing source project reused read-only: `project_1794804603075477.json`.

No original media was renamed, edited, copied, deleted or exported during these cases. Six emulator screenshots were retained as task-owned shell screenshots; MediaStore therefore has six more image rows than preflight.

## Focused host checks

| Check | Result |
|---|---|
| `flutter test test/project_repository_test.dart test/project_controller_test.dart test/p2_p3_library_test.dart test/timeline_recovery_test.dart test/drawing_project_snapshot_test.dart test/editor_preview_load_queue_test.dart` | 28/28 passed. Includes draft parsing/list state, coalesced saves/retry, reopen compatibility, SAF restoration/cancel, timeline and edit recovery. |
| `.\gradlew.bat :app:testDebugUnitTest --tests '*MediaCatalogTest' --tests '*TimelineAudioLimitTest' --tests '*SubtitleTextTest' --tests '*EditorStorageTest'` | 7/7 passed: MediaCatalogTest 1; TimelineAudioLimitTest 2; SubtitleTextTest 2; EditorStorageTest 2. |
| `flutter analyze` | No issues found. |
| `dart format --output=none --set-exit-if-changed` on 13 relevant Dart/test files | Passed; no formatting changes required. |
| `git diff --check` plus per-file no-index whitespace checks on the new reports | Passed; no whitespace errors. |

No complete suite was rerun. Prompt06/07 and Prompt08 baselines remain historical evidence and are not included in these focused counts.

## Pre/post preservation checks

| Item | Preflight | Final | Result |
|---|---|---|---|
| Existing project files | 12 JSONs; baseline SHA-256 manifest in `IMPORT_PROJECTS_AUDIT.md` | All 12 hashes match | PASS |
| Task-owned projects | None | `project_1794820069846523.json`, `project_1794820476111724.json` | Separate IDs; original projects unchanged |
| Selected existing video bytes | `Recording_1794674748965.mp4`: `d473568ff12fc98cd562fd5336393b5c2fbc073c3e31b3ef4bf384c0a4d6b935` | Same SHA-256 | PASS |
| Whisper Tiny model | `ggml-tiny.bin`: `be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21` | Same SHA-256, 77,691,713 bytes | PASS |
| `app_settings.xml` | `2e00cb86be2bb6d349aac88ba15d8cccd1f4c577da2a49f8ab50464b0ad9d395` | Same | PASS |
| `media_catalog.xml` | `4f4fdc75884999861ffa89babcc47dc89a76eb299d258ff2fd5ba5a613b43c6e` | Same; original `Prompt05__SS` URI restored | PASS |
| `editor_speech_models.xml` | `bc542d18fe70fcafb0d444fc4f5cda2f9e1e59272230362b56c2f82dcbcb13fd` | Same | PASS |
| MediaStore videos | 25 rows total / 22 app-owned | 25 / 22 | PASS; unchanged |
| MediaStore images | 335 rows total / 26 app-owned | 341 / 26 | Six additional task QA screenshots, owner `com.android.shell`; no existing item was deleted |
| SAF grants | Existing grants retained | Existing grants retained; task-folder/audio grants and the restored empty-folder grant are also present | PASS; no grant was revoked |
| `/data` available | 427,784 KiB | 426,948 KiB | 836 KiB lower; no large outputs/model downloads |

## Acceptance gates

| Gate | Status | Evidence |
|---|---|---|
| G01 Existing media opens | PASS | I01 MediaStore video preview and I02 SAF video preview |
| G02 Supported SAF file works | PASS | I02 and I03 |
| G03 URI and grants handled safely | PASS | Content URIs retained in projects; persisted grants and restart checks |
| G04 Metadata is correct | PASS | Video MIME/duration/dimensions, PNG dimensions, audio duration |
| G05 Existing project reopens | PASS | I07/I09 |
| G06 Task project saves/reopens | PASS | I08 and I11 |
| G07 Schema compatibility | PASS | Version-1 historical projects hash-preserved; focused model/reopen tests pass |
| G08 Missing source fails safely | PASS | I10 |
| G09 Relink succeeds | PASS | I11 |
| G10 Subtitle cues persist | PASS | I08/I09; exact cue text and timings compared after restart |
| G11 Picker cancel/errors recover | PASS | I10/I12; unsupported codec and revoked permission remain untested branches |
| G12 Original data preserved | PASS | Original project hashes, relevant source/model/preference hashes and media row counts checked; QA screenshots accounted separately |
