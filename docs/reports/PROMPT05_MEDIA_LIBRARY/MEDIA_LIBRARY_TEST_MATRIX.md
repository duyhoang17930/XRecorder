# Prompt05 Media Library test matrix

Date: 2026-11-15. Source checks, automated tests, and Android runtime evidence are reported separately.

## Environment and data-preservation snapshot

- ADB device: `emulator-5554`, online, Android 17 / API 37, product/model `sdk_gphone16k_x86_64` / `emu64xa16k`. ADB and the installed app worked; this is a generic emulator, not the requested Pixel_7 AVD.
- Installed app: `com.xrecorder.xrecorder`, version 0.1.0, versionCode 1, target SDK 36. The final x86_64 debug APK was 120,023,451 bytes, SHA-256 `200A9694C58FD106554E6FAB7851E49F83869BFC737DE78848B9F40357788009`; it was installed with `adb install -r`, preserving app data.
- Host free space at final check: C: 13.91 GiB; D: 19.22 GiB. AVD `/data` free space: 569 MiB, so no more storage-heavy fixture work was run. No cleanup, uninstall, data clear, emulator wipe, or user-media deletion was done.
- App-owned, finalized MediaStore inventory after QA: 20 videos and 23 images (`owner_package_name=com.xrecorder.xrecorder`, `is_pending=0`, `is_trashed=0`). The original inventory was 20 videos / 21 images; two task-created Restore outputs account for the additional app-owned images.
- Final owner-filtered image counts: 276 rows owned by `com.android.shell` (retained ADB screenshots and two SAF fixtures), 23 owned by the app, and 1 owned by `com.android.externalstorage`. The shell-created SAF fixtures are `saf_fixture.png` and `Nested/nested_fixture.png` under `/sdcard/Documents/Prompt05_SAF_QA_20261115/`; each is a 237-byte copy of a generated QA PNG. All QA evidence and fixtures remain on the AVD.
- Representative app-owned video: URI `content://media/external/video/media/220`, `Recording_1794720956234.mp4`, `video/mp4`, 6,001,835 bytes, `is_pending=0`. It appeared with a thumbnail and duration in Video Library and opened in playback Preview.
- Representative app-owned photo: URI `content://media/external/images/media/359`, `Screenshot_1794736842233.png`, `image/png`, 1,391,134 bytes, 1080 x 2400, `is_pending=0`. It appeared in Photo Library and opened in portrait Preview. The stored PNG decodes, but its pixels show the Android Launcher rather than the intended app page; this is the known Prompt04A capture-source issue, not a Library substitution or mutation.
- The app's real private `files/trash` was empty before and after the two completed transactions. Current-source instrumentation used a retained isolated fixture directory under `files/task08_trash_1794748122011/trash`; the earlier pre-fix reproduction fixture and all generated fixture bytes remain in place. No original media was used in Trash/Restore testing.
- The SAF system tree picker was opened. It showed `SDCARD/Documents` as empty even though the QA files existed by `adb shell ls` and had MediaStore rows. The root `SDCARD` was correctly restricted by DocumentsUI. The picker was exited without retaining a folder selection; the app remained on “App media”. No grant was deliberately revoked. A full system URI-grant census was unavailable.

## Android cases M01-M20

| ID | Status | Evidence / limitation |
|---|---|---|
| M01 - Video Library shows finalized MP4s | PASS | Current APK displayed 20 app-owned finalized videos, matching the owner-filtered MediaStore inventory. The representative MP4 row and thumbnail were checked. |
| M02 - Photo Library shows PNG/JPEG outputs | PASS | Prompt05 showed all 21 original app-owned finalized images plus two task-created Restore outputs. Prompt05A retained those rows and added app-owned screenshot `/467` (`image/png`, 1080x2400, `is_pending=0`), which appeared in Photo Library and opened in Preview. The new image's pixels were not inspected; the prior source mismatch remains open. |
| M03 - New recording auto-appears | NOT RUN | No new recording was created during this Prompt05 runtime pass. |
| M04 - New screenshot auto-appears | PASS | Prompt05A completed the real Photo Library Screenshot flow, accepted Android MediaProjection consent, and returned to the app after capture. App-owned images increased 23 -> 24; `Screenshot_1794758287113.png` appeared at the top without Refresh: `content://media/external/images/media/467`, `image/png`, 1,391,956 bytes, 1080x2400, `is_pending=0`. The earlier Prompt05 failed tap remains historical; screenshot pixel-source fidelity was not checked in this run. |
| M05 - Background/foreground and observer refresh | PARTIAL | Source uses coalesced MediaStore observation and lifecycle reconciliation; this AVD pass did not create media or systematically exercise process/background observer delivery. |
| M06 - Filename/partial/Unicode/no-match search | PARTIAL | Prompt05A exact filename search opened the matching recording, lowercase partial `recording_` returned 19 of 20 videos, `no_such_media_05a` showed 0/No matching media, and Clear search restored 20. Unicode/Vietnamese and rapid typing remain unverified. |
| M07 - All five sort modes | PASS | Prompt05A applied all five video modes on Android. Newest put the latest recording first; Oldest put `Recording_1794674748965.mp4` first; Name began with that lexically earliest name; Largest began with `Recording_1794709061299.mp4` (74.3 MiB); Longest began with `Recording_1794720956234.mp4` (10:07). The active option had `selected=true`; no trailing arrow appeared. |
| M08 - Search + sorting + source filtering | PARTIAL | Lowercase `recording_` retained 19 results after switching to Largest; the 74.3 MiB matching video became first. App media returned 20 videos/24 photos. The selected SAF tree appeared as its own source but could not enumerate provider files, so external-source combined behavior remains unverified. |
| M09 - Real SAF folder selection/cancel | PARTIAL | Prompt05A selected a task-only folder through the real `ACTION_OPEN_DOCUMENT_TREE` picker and accepted the system grant. Tree URI stored by the app: `content://com.android.externalstorage.documents/tree/0000-0000%3ADocuments%2FPrompt05__SS`. DocumentsUI and the app both reported no children, while `adb shell ls` showed `/sdcard/Documents/Prompt05_SAF_QA_20261115/saf_fixture.png` and `/sdcard/Documents/Prompt05_SAF_QA_20261115/Nested/nested_fixture.png` (237 bytes each). Back navigated to the restricted `SDCARD` root and then canceled; no selection or grant was created by that cancellation. Provider enumeration remains unverified. |
| M10 - Persisted SAF grant/revocation recovery | PARTIAL | The selected tree URI preference survived app force-stop/relaunch. The installed Prompt05 build returned to App media instead of restoring the saved tree. Prompt05A now restores `savedFolder()` on Library initialization with a race guard and widget coverage, but that final APK could not be installed because the AVD rejected it for insufficient storage. QA grant was later disconnected through the app; after force-stop the QA URI was absent and the pre-existing Alarms grant remained. Stale-grant recovery after an OS-side revoke was not tested. |
| M11 - Granted/denied/partial media permissions | PARTIAL | Manifest/source review confirms no broad media-read or all-files permission request. Permission transitions were not exercised. |
| M12 - Thumbnails and invalid-media fallback | PARTIAL | Real Library thumbnails loaded for 20 videos and 21 original photos. The valid restored 64x64 PNG showed its expected thumbnail; the separately restored malformed 68-byte PNG displayed the broken-image fallback without blocking the list. Removed, same-name/different-URI, and high-resolution fallback cases were not run. |
| M13 - Video playback, seek, Back/resource release | PARTIAL | Prompt05A opened `content://media/external/video/media/404` (`Recording_1794738804965.mp4`, 2.6 MiB, 224 s) in Video Preview, returned to the matching details screen, and opened the editor with that exact source URI/duration. Pause/seek controls were not exposed in the UI hierarchy and remain unverified. |
| M14 - Photo Preview/orientation | PARTIAL | Prompt05A opened new app-owned image URI `/467` in Photo Preview and then Photo Editor via “Crop & annotate a copy”; no save was performed. The source item remained present. Other aspect ratios, zoom/pan, and pixel-source fidelity remain unverified. |
| M15 - Task-created Trash/Restore | PASS | Current-source Android instrumentation called native `MediaActions.trash()`, verified the source MediaStore row disappeared and the app-managed Trash entry was readable, then called `restore()`. Two generated fixtures completed byte-exact round trips. Valid PNG: source `content://media/external/images/media/437`, 237 bytes, 64x64, SHA-256 `e03ce841624bb72b375226bbb9e6836701d56d9b774b68ff9fce713d0ac48922`; restored `content://media/external/images/media/438`, `image/png`, app-owned, `is_pending=0`, `is_trashed=0`. Malformed PNG: source URI `/434`, 68 bytes, SHA-256 `88f95253dcfe22330c2793b0419262a58420adfbfc791231a60d35da393219fc`; restored as app-owned URI `/435` with exact bytes and visible fallback. Both are retained QA outputs. This does not verify Flutter confirmation/cancel UI or system consent for non-owned media. Current-source list/retention instrumentation also retained expired/orphan bytes and exposed corrupt metadata. |
| M16 - Delete confirmation/cancel/permission denial | NOT RUN | No permanent-delete or system consent flow was opened. |
| M17 - Multi-select/bulk action | NOT RUN | No multi-select or bulk action was performed. |
| M18 - Editor/export/recording integration | PARTIAL | Prompt05A verified video handoff for URI `/404` and the exact 224.783 s clip in Video Editor, plus photo handoff for `/467` in Photo Editor. Entering Video Editor created QA project `project_1794759299435822.json`; the eight pre-existing project files remained present. No edits or exports were made. Recording/export flows remain unverified. |
| M19 - Layout, scroll-to-top, recording footer, accessibility | PARTIAL | Current video/photo counts, active-tab scroll-to-top, and the redesigned Sort media sheet were visually checked. The sort sheet fit the AVD with all labels on one line. TalkBack, active-recording footer, and physical-touch checks remain open. |
| M20 - Larger-library performance/lifecycle/leaks | PARTIAL | Flutter's lazy 1,000-item test passed; the AVD displayed 20/21 items without an observed crash. No device timing, memory, jank, or observer-count measurements were recorded. |

**Complete Android cases passed: 5/20 cumulative.** The total counts M01, M02, M04 (Prompt05A screenshot auto-publication/refresh), M07 (all five Android video sort modes), and M15 (task-created native Trash/Restore). It does not count partial SAF enumeration, the non-installed final SAF restore change, video pause/seek, Flutter-only tests, or unexercised system permission flows as Android passes.

## PROMPT05A — FOCUSED QA CLOSURE

### Environment and safety

- Current ADB target: `emulator-5554`, generic `sdk_gphone16k_x86_64` / `emu64xa16k`, Android 17 / API 37. It is not Pixel_7. Installed package remains `com.xrecorder.xrecorder` 0.1.0, versionCode 1, targetSdk 36.
- Git stayed on `main`, HEAD `2a009e679f1ad254bb5d67b5f07880afaa2d9096`. The Prompt05 working tree was already dirty; this continuation made no commit and preserved all other edits.
- Host free space: C: 18.23 -> 18.27 GiB; D: 20.08 -> 18.92 GiB. AVD `/data`: approximately 568 -> 557 MiB. Reserves remained above C: 5 GiB / D: 10 GiB.
- Final debug APK built successfully at `build/app/outputs/flutter-apk/app-debug.apk` (183.2 MiB). `adb install -r` failed with `INSTALL_FAILED_INSUFFICIENT_STORAGE`; the installed Prompt05 build was not replaced and app data was not cleared.
- App-owned MediaStore rows remained 20 finalized videos and 24 finalized photos. The photo change from 23 to 24 is the single task-created screenshot below. No original video/photo or Trash entry was deleted.

### Focused Android evidence

- **M04 / app capture refresh: PASS.** From Photo Library, the Screenshot quick action opened the real MediaProjection consent. After consent and capture, returning to the app brought the new row into Photo Library without manual Refresh. Exact row: `content://media/external/images/media/467`, `Screenshot_1794758287113.png`, `image/png`, 1,391,956 bytes, 1080x2400, owner `com.xrecorder.xrecorder`, `is_pending=0`. New real output verified: 1. The actual pixel contents were not decoded in Prompt05A; the known Prompt04A Launcher-source mismatch remains open.
- **M05 / observer-lifecycle: PARTIAL.** The app was backgrounded by Android capture consent/countdown and the Library showed the new app-owned item after foreground return without Refresh or a duplicate. An external MediaStore event and observer callback frequency were not isolated.
- **M09 / SAF: PARTIAL.** The genuine tree picker selected the QA folder and returned URI `content://com.android.externalstorage.documents/tree/0000-0000%3ADocuments%2FPrompt05__SS`; system access consent was accepted. Physical test inputs remained `/sdcard/Documents/Prompt05_SAF_QA_20261115/saf_fixture.png` and `/Nested/nested_fixture.png`, each 237 bytes. DocumentsUI displayed “No items” in the selected tree and the app showed “No photos/videos in this folder”, not a permission error. Android restricted selecting the `SDCARD` root. The mismatch is classified as an AVD DocumentsUI/provider enumeration limitation; no bypass was used. External folders verified: 1 selected; media enumerated: 0.
- **SAF restart/recovery: PARTIAL.** `media_catalog.xml` retained the chosen tree string after app force-stop/relaunch, but the installed source reset the Library to App media. A narrow source fix now initializes each Library from `savedFolder()` and uses a revision guard so an in-flight restore cannot overwrite a newer picker action. After the test, the QA folder was disconnected through the app. Force-stop removed its temporary grant; the pre-existing persisted Alarms tree grant remained untouched. System-side revoke/retry was not exercised.
- **M06/M07/M08 search and sort:** exact `Recording_1794738804965.mp4` search matched; lowercase `recording_` returned 19; no-match showed 0/No matching media; Clear restored 20. Switching from that search to Largest preserved 19 items and put `Recording_1794709061299.mp4` (74.3 MiB) first. All five actual video modes were applied: Newest, Oldest, Name, Largest, Longest. The Largest menu item carried `selected=true`; labels had no trailing arrow. Unicode/Vietnamese search remains untested. Source filter was App media (20 videos/24 photos) versus one SAF tree whose provider returned no children.
- **M13/M18 video handoff:** video URI `content://media/external/video/media/404`, name `Recording_1794738804965.mp4`, video/mp4, 2.6 MiB, duration 224 s, opened in Preview and returned to matching details. “Edit video” opened Video Editor with source URI `/404` and exact timeline duration 224.783 s. Player pause/seek were not verified. A new QA project `project_1794759299435822.json` was created on editor entry; its clip references `/404`. The eight pre-existing project JSON filenames remained present; no original project was edited. No export was run.
- **M14 photo handoff:** image URI `/467` opened in Photo Preview and Photo Editor (“Crop & annotate a copy”). No Save copy action was taken; the original `/467` row and bytes/metadata remained present.
- **SAF cancellation and cleanup:** backing out of the picker canceled without adding a URI preference/grant. App Disconnect removed the QA tree preference/grant; post-restart ActivityManager showed only the pre-existing Alarms persisted grant. The QA folder/files themselves remain on the AVD.

### Automated checks and preservation

- `test/p2_p3_library_test.dart`: **18/18 PASS**, including saved-folder restoration and cancellation-during-restore race coverage.
- `flutter analyze --no-pub`: **PASS**, no issues.
- Dart format on the three touched Dart files: **PASS**; `git diff --check`: **PASS** (only existing LF/CRLF notices).
- `flutter build apk --debug --no-pub`: **PASS**. In-place install: **BLOCKED** by the AVD storage error above. Full Flutter 563 and native JVM 162 results remain the Prompt05 historical baseline; they were not rerun here. No Kotlin/native source changed in Prompt05A.
- Media safety: 20 app-owned videos remained; 23 pre-existing app-owned images remained and one QA screenshot was added. The two Prompt05 Restore PNGs and all SAF QA files remain. Eight pre-existing project files remained; one QA editor project was added and retained. The QA SAF URI was disconnected; pre-existing Alarms permission remained. No destructive media actions were performed.

### Prompt05A outcomes

- APP-CAPTURE AUTO-REFRESH: **PASS**; EXTERNAL MEDIA AUTO-REFRESH: **PARTIAL / NOT ISOLATED**; CONTENT OBSERVER LIFECYCLE: **PARTIAL**.
- SAF FOLDER SELECTION: **PASS**; SAF MEDIA ENUMERATION: **PARTIAL**; SAF PERSISTED GRANT: **PARTIAL** (URI preference survives, but final restore code not installed); SAF REVOKE/RETRY: **PARTIAL**.
- SEARCH: **PARTIAL** (ASCII exact/partial/no-match/clear pass; Unicode not run); ALL FIVE SORT MODES: **PASS, 5/5**; SOURCE FILTERING: **PARTIAL**.
- VIDEO PREVIEW/EDITOR: **PARTIAL** (matching handoff pass; pause/seek not proven); PHOTO PREVIEW/EDITOR: **PASS for read-only handoff**; SCREENSHOT INTEGRATION: **PARTIAL** (publication and Library discovery pass; pixels not checked).
- REGRESSION: **PASS** for the short non-destructive set; AUTOMATED TESTS: **PASS** for focused checks; DATA PRESERVATION: **PASS** with one retained QA screenshot and one retained QA editor project.
- Physical device: **NOT RUN**. Prompt05A cumulative complete Android cases: **5/20 PASS**.

## Automated and build checks

| Check | Result |
|---|---|
| Focused Library/sort/widget tests | PASS - 17 tests |
| Refinement/navigation/layout tests | PASS - 28 tests |
| Full Flutter suite | PASS - 563 tests, 0 failures |
| `flutter analyze --no-pub` | PASS - no issues found |
| Localization generation/checker | PASS - generation and 12-locale key/placeholder checker; human copy review remains Prompt11 |
| Dart formatting | PASS - changed Dart files formatted |
| `git diff --check` | PASS |
| Gradle `:app:testDebugUnitTest` | PASS - 162 tests in 28 suites, 0 failures/errors |
| Gradle `:app:assembleDebugAndroidTest` | PASS - current instrumentation source compiled and packaged |
| Current-source Trash instrumentation on AVD | PASS - expired/orphan managed fixtures retained; corrupt entry visible; foreign bytes kept; `restoredRedFixtureInputs=0` |
| Final x86_64 app build/install | PASS - APK assembled and installed in place; no uninstall/data clear |

## Runtime Trash fixture evidence

The pre-fix implementation was separately reproduced on the old installed app: listing Trash removed a synthetic expired JSON/payload and orphan `.bin`/`.part` files, reporting `restoredRedFixtureInputs=4`. The four fixture hashes were checked and those bytes were recreated. The current-source test then passed against the updated x86_64 app with `restoredRedFixtureInputs=0`; fixture output is retained at `/data/user/0/com.xrecorder.xrecorder/files/task08_trash_1794744779584/trash`. At that first run this covered only list/retention; a subsequent current-source instrumented transaction exercised `MediaActions.trash()` and `MediaActions.restore()` on two generated app-owned PNG rows. Both source rows disappeared, restored rows had new URIs, and bytes matched original hashes. The valid fixture decoded; the 68-byte malformed fixture displayed the fallback. Both outputs remain as QA artifacts, and app-private `files/trash` is empty.

## Sort popup evidence

The current x86_64 app's actual video sort sheet was captured at `build/prompt05_android/prompt05_sort_sheet_tick_live.png` (device copy: `/sdcard/prompt05_sort_sheet_tick_live.png`). The five choices use distinct Lucide glyphs; the active choice has a coral background/border and a custom tick badge, while unselected rows have no trailing arrows. Widget tests verify selection semantics, choice application, 48 dp minimum touch area, and 320/411 dp layouts at 200% text in Light/Dark themes.

## SAF picker evidence and platform conditions

- The implementation launches Android's tree picker and uses the selected content URI/provider contract instead of treating it as a filesystem path. The AVD exposed the `SDCARD` root restriction and an empty `Documents` child. Because no folder could be selected reliably, no persistable grant, restart restoration, or revocation behavior is claimed.
- Android's official SAF guidance says that `ACTION_OPEN_DOCUMENT_TREE` grants access to the user-selected tree and that persistence requires taking the grant supplied by the system. Android 11+ blocks selection of shared-storage roots and selected restricted directories. See [Access documents and other files from shared storage](https://developer.android.com/training/data-storage/shared/documents-files). The observed root restriction is consistent with that behavior; the empty child listing remains an AVD/provider test limitation, not a demonstrated app defect.
