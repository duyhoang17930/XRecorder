# Prompt02 Screenshot - test matrix

## Candidate and test baseline

- Branch `main`, HEAD `21d40df`; the checkout already had uncommitted Prompt01/recording work. It was preserved.
- Device: AVD `Pixel_7`, serial `emulator-5554`, model `sdk_gphone16k_x86_64`, API 37, fingerprint `google/sdk_gphone16k_x86_64/emu64xa16k:17/CP31.260623.012/16064790:user/dev-keys`, display 1080x2400 @ 420 dpi. Boot complete.
- Candidate: `flutter build apk --profile --no-pub`; package `com.xrecorder.xrecorder` versionCode 1 / versionName 0.1.0; 116,518,593 bytes; SHA-256 `C0BE5E78E1C3F7E17675C051BC2C7CA9EAE9BD6FC2C85059ACF651B418CD4307`. Installed with `adb install -r`.
- Host baseline from the earlier Prompt02 phase: full Flutter 554 PASS, full native 161 PASS / 28 suites, analyzer clean. Current final gate (no app source changed in this continuation): focused Flutter 49 PASS; `flutter analyze --no-pub` PASS; relevant native 28 PASS / 0 failures. Counts are not added together because focused tests overlap the full baseline.

## Host checks

| ID | Contract | Result |
|---|---|---|
| H01 | Screenshot action dispatches Screenshot once, not video start | PASS |
| H02 | Vietnamese Create/Screenshot dispatch keeps the selected delay after sheet dismissal | PASS, in focused Flutter suite |
| H03 | Supported delay validation and persisted 3s default; values 1/3/5/10 | PASS |
| H04 | Countdown presentation, cancel, denial/no-output, friendly failure and retry | PASS |
| H05 | Screenshot row packing for stride/padding and portrait/landscape buffers | PASS, 4 native cases |
| H06 | Capture timing, request guard and notification policy | PASS, 24 native cases across three classes |

No dedicated Screenshot Android instrumentation class exists in current `androidTest`; the native end-to-end path was exercised through ordinary Android UI and the real consent dialog on Pixel_7. Unrelated Recording-only instrumentation was not run.

## Live user entry points

| Visible action | Runtime proof | Result |
|---|---|---|
| Video Library Screenshot quick action | `content://media/external/images/media/62`, exact one new row | PASS |
| Create (`+`) sheet -> Screenshot | `.../media/70`, 3s, exact one new row, Saved/View on return | PASS |
| Record screen -> Recording settings -> `Screenshot -> 3s delay` | `.../media/71`, exact one new row, Saved/View on return | PASS |

The screenshot on the Video Library screen and its quick action share `requestLibraryScreenshot`; the Create (`+`) menu uses the same action. The Recording settings action calls the same Screenshot controller with the persisted delay. The separate `openStudioCreate` source helper has no production caller; it is covered by the historical widget regression, not counted as a live app route.

## Pixel_7 runtime matrix (S01-S16)

| ID | Scenario and observed behavior | Result / evidence |
|---|---|---|
| S01 | Default 3s request produced a 1080x2400 PNG at URI `/55`. | PASS - `s01_default_validation.json` |
| S02 | Minimum 1s delay reached capture; PNG `/56`, 1080x2400. | PASS - `s02_min_timeline.json`, `s02_min_validation.json` |
| S03 | 5s delay; Android Settings was foreground at capture. PNG `/57` matched a fresh Settings reference at 99.6789% exact pixels; mean channel difference 0.43215. | PASS - `s03_background_timeline.json`, `s03_pixel_comparison.json` |
| S04 | 10s delay; rotated to landscape during countdown. PNG `/58` is 2400x1080; AVD rotation restored to 0/automatic. | PASS - `s04_rotation_timeline.json`, `s04_rotation_validation.json` |
| S05 | Android's real MediaProjection consent was cancelled. State returned idle with null URI and no new MediaStore row; fresh consent retry succeeded at `/59`. | PASS - `s05_consent_cancel.json`, `s05_retry_validation.json` |
| S06 | In-app Cancel during 10s countdown returned idle/null URI and added no row. | PASS - `s06_in_app_cancel_timeline.json`, `s06_in_app_cancel_journal.xml` |
| S07 | Notification Cancel during countdown returned idle/null URI; no stale countdown notification remained. | PASS - `s07_notification_cancel_timeline.json`, `s07_notification_cancel_visible.png` |
| S08 | 3HRecorder was backgrounded and Android Settings opened before capture; the image contains Settings and system bars/cutout. | PASS - S03 output `/57`, pixel comparison above |
| S09 | Rotation during the 10s delay produced an undistorted 2400x1080 image. | PASS - S04 output `/58` |
| S10 | Three rapid taps initially created one session; extra taps outside Android consent cancelled it without output. A second accepted request was retapped three times during active countdown; the same session completed and created exactly one row `/72`. | PASS - `s10_rapid_no_output.json`, `s10_busy_retap_validation.json` |
| S11 | Photo Library refreshed, opened details and Preview displayed the real Settings screenshot `/57`. | PASS - `s11_photo_library.png`, `s11_image_view.png` |
| S12 | Photo Editor opened `/59` and saved copy `/60`, valid 922x2048 PNG, `image/png`, pending 0. Source `/59` remained byte-exact. | PASS - `s12_editor_validation.json`, `s12_editor_copy.png` |
| S13 | Background completion showed `Screenshot saved`/`View` after return. Tapping the accessible View action opened `Photo preview` for `/69`; the rendered preview visibly contains the captured Android launcher. | PASS - `s13_return.png`, `p02_view_action_verified.json`, `p02_view_action_verified.png`; PNG `/69` checksum in output table |
| S14 | Force-stopped the app during 10s countdown. Relaunch showed an explicit interrupted/failed state with null URI and no row/pending item; fresh consent retry succeeded at `/61`. | PASS - `s14_interrupt.json`, `s14_retry_validation.json` |
| S15 | Consent picker showed its full-screen sensitive-content warning and `Share entire screen`. Its `Share one app` option was explicitly marked `Not supported by the app`; no safe `FLAG_SECURE` fixture exists, so protected pixels were not tested or bypassed. | PARTIAL - `s05_consent_dialog.png`, `s15_scope_options.png` |
| S16 | Final audit verified every new Screenshot row is unique, owned by the app, `image/png`, `IS_PENDING=0`, and byte-equal to a fully decoded local PNG. No pending row/orphan remained. | PASS - `final_preservation_and_media.json` |

## Validated Screenshot outputs

All 15 entries below were checked for PNG signature, full FFmpeg decode, dimensions, checksum, MediaStore MIME/owner/pending state, and byte-exact readback from their URI.

| ID | Case/artifact | MediaStore URI | Dimensions | Bytes | SHA-256 |
|---:|---|---|---:|---:|---|
| 55 | s01_default | `content://media/external/images/media/55` | 1080x2400 | 1,391,097 | `35db2f8787ead88d7667c1bd1b345e364f8f7351b3db0a6923635b0ccb498618` |
| 56 | s02_min | `content://media/external/images/media/56` | 1080x2400 | 1,418,437 | `4630980f468ceb31fda591ffca2b203ec5d48c1d309da514c3b28130b9731c43` |
| 57 | s03_background | `content://media/external/images/media/57` | 1080x2400 | 212,706 | `59ec2bdaffeaadb2f6c3e74db1c1bb72db22fb15b64aef3be61d7defb61ffc6e` |
| 58 | s04_rotation | `content://media/external/images/media/58` | 2400x1080 | 98,066 | `1a13d38b222e6eb03fee433e0af77977778b5759fed85a0fd5526dfba4df26cf` |
| 59 | s05_retry | `content://media/external/images/media/59` | 1080x2400 | 212,676 | `435fff1a827b91e7ca02bc867aa21a4c25299d947f024087e09480784f6b885c` |
| 61 | s14_retry | `content://media/external/images/media/61` | 1080x2400 | 212,283 | `330ad6d62516036bbc2260100ed3cf9dcfc00112e5906c363a040f047c317022` |
| 62 | library_entry | `content://media/external/images/media/62` | 1080x2400 | 212,985 | `d1c2615a79e5fdc2a22e061555d984924686a8858efaa563eb41552e0d200920` |
| 63 | s13_view_action | `content://media/external/images/media/63` | 1080x2400 | 212,893 | `65dbc873dc579bac986ad21f1a969da4ceea9f810d116932b749a5b724c13fa6` |
| 64 | s13_view_confirmed | `content://media/external/images/media/64` | 1080x2400 | 212,333 | `d67f83f230490a9af5098e6ccb1ffb034d0483d295ef19022efd2fc78796f3a2` |
| 67 | s13_view_activation_trial_1 | `content://media/external/images/media/67` | 1080x2400 | 1,391,942 | `c6bcc2f65254e0e3e675252bd7e07b579f9c87a413fd66682c806e3eb3806788` |
| 68 | s13_view_activation_trial_2 | `content://media/external/images/media/68` | 1080x2400 | 1,391,447 | `717f3b2b0465a592e859220a55751460bba486279f7c24adfae042da72a021ac` |
| 69 | s13_view_activation_verified | `content://media/external/images/media/69` | 1080x2400 | 1,392,068 | `a4aeb42abd91f1bc43a2d540402ebae2460baf45222f11957f2c609fa5d6138b` |
| 70 | s17_create | `content://media/external/images/media/70` | 1080x2400 | 1,391,389 | `4c199b08c00efd13117f38c79b7de423608f458d645a010f8eb031bec8dc2291` |
| 71 | s17_record_setup | `content://media/external/images/media/71` | 1080x2400 | 1,391,844 | `9d4a42e221fb97d8df2a479942c989ed216fa208ff4aecb6ce7ac11aff51618a` |
| 72 | s10_busy_retap | `content://media/external/images/media/72` | 1080x2400 | 232,793 | `ba2b25e5de6fbb25d5ce22a316c9d51d39e5f7684671d8752467f244abb88436` |

Photo Editor copy (separate from the 15 Screenshot outputs): `content://media/external/images/media/60`, 922x2048, `image/png`, `IS_PENDING=0`, SHA-256 `9479e8c54474397611b9be7f49dbf8ce9abb6568006d6023f73a455e0275bcae`. The source URI `/59` stayed byte-exact; existing editor export cap is 2048 px on its long edge.

## Preservation, storage and physical-device scope

- Final audit: 8 project draft files byte-exact; 4 original MediaStore images retained metadata and SHA-256; 15 Screenshot rows + 1 Editor copy; all unique and no pending rows. No unexpected private changes. Effective screenshot delay restored to 3s. Android changed only `files/profileInstalled`, a runtime optimization marker. `speech_models` contained no files before or after.
- No uninstall, app-data clear, AVD wipe, or removal of user media/drafts/models was performed. APK install used `adb install -r`.
- Host free space at final check: C: 15.01 GiB, D: 19.96 GiB; emulator `/data`: about 1.2 GiB free.
- Physical device: NOT RUN. The concise physical handoff retains only hardware/OEM-specific cases (PDH-01 to PDH-13, PDH-15 and PDH-16); ordinary Screenshot cases remain in this emulator matrix.
