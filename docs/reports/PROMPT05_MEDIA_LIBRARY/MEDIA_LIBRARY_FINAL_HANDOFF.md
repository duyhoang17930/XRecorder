# Prompt05 Media Library final handoff

**PROMPT05 FINAL: PARTIAL**

The current-source Media Library was installed and exercised on the online API 37 x86_64 emulator. Twenty app-owned finalized videos and 21 original app-owned photos appeared in their respective Libraries; two additional task-created Trash/Restore outputs were retained in the Photo Library. The Trash retention data-loss defect has a pre-fix reproduction, a current-source retention test, and two real app-owned MediaStore Trash/Restore transactions with byte/hash verification. The owner's Sort media popup redesign was visually verified on-device with a custom selected tick and no trailing arrows.

The work remains partial because the AVD did not complete capture auto-refresh, SAF folder enumeration/persisted-grant recovery, permission transitions, delete-consent handling, bulk selection, editor/export handoff, or device performance/accessibility. The connected AVD is generic sdk_gphone16k_x86_64, not Pixel_7. SAF picker inspection was attempted, but DocumentsUI showed an empty Documents folder despite task fixtures being present on shared storage and indexed by MediaStore; the flow was canceled without selecting a folder.

## Acceptance status

ADB/AVD: **PASS** - emulator-5554, API 37, generic x86_64 AVD; not Pixel_7.

VIDEO LIBRARY: **PASS** - 20 app-owned finalized videos shown.  
PHOTO LIBRARY: **PASS** - 21 original app-owned photos plus two retained task-created Restore outputs are visible (23 app-owned rows after QA).  
AUTOMATIC REFRESH: **PARTIAL**  
SEARCH: **PARTIAL**  
ALL SORT MODES: **PARTIAL** - all five choices visible; all comparators covered by Flutter tests; not every Android mode applied.  
SOURCE FILTERING: **PARTIAL**  
EXTERNAL FOLDER / SAF: **PARTIAL**  
MEDIA PERMISSIONS: **PARTIAL**  
THUMBNAILS / CACHE: **PARTIAL**  
VIDEO PREVIEW: **PARTIAL**  
PHOTO PREVIEW: **PARTIAL**  
TRASH: **PASS** - two task-created app-owned MediaStore items were moved through the native app Trash action; original rows disappeared and exact bytes were retained.  
RESTORE: **PASS** - both items were restored to new app-owned MediaStore URIs, `is_pending=0`, correct MIME/size, and exact SHA-256; app-private Trash is empty afterward. UI confirmation was not exercised.  
DELETE CONSENT / CANCEL: **PARTIAL** - not exercised on Android.  
MULTI-SELECT: **PARTIAL** - not exercised on Android.  
EDITOR INTEGRATION: **PARTIAL**  
RECORDING INTEGRATION: **PARTIAL**  
SCREENSHOT INTEGRATION: **PARTIAL**  
NAVIGATION / SCROLL: **PARTIAL** - active-tab scroll-to-top was observed; footer overlap while recording not exercised.  
UI / ACCESSIBILITY: **PARTIAL** - redesigned popup visually checked; TalkBack not run.  
PERFORMANCE: **PARTIAL** - no device timing or memory benchmark.  
FLUTTER TESTS: **PASS - 563/563**  
NATIVE TESTS: **PASS - 162/162 JVM tests; current-source Trash instrumentation passed on AVD**  
DATA PRESERVATION: **PASS** - all 20 app-owned videos and 21 original app-owned photos remain; 2 synthetic restored PNGs are additional retained QA outputs. The 275 `com.android.shell` image rows include retained ADB screenshots and the two shell-owned SAF fixtures; one additional image row is owned by `com.android.externalstorage`. The app's private Trash is empty after Restore. No original media, projects, recovery inputs, or preferences were used for destructive QA. The Library remains on “App media”; no folder selection was retained. Full system persisted-URI-grant census was unavailable.  
PHYSICAL DEVICE: **NOT RUN**

ANDROID CASES: **3/20 PASS**

REAL VIDEO ITEMS VERIFIED: **20**  
REAL PHOTO ITEMS VERIFIED: **21 original items** (plus 2 retained task-created Restore outputs)  
TRASH/RESTORE TEST TRANSACTIONS: **2**  
EXTERNAL FOLDERS VERIFIED: **0**

## Changes

- Removed age-based deletion from native listTrash(). Listing Trash now retains expired legacy entries, orphan managed payloads, and damaged metadata for recovery; permanent deletion remains explicit.
- Updated Trash copy/domain fields and all 14 ARBs to describe manual retention and the moved-to-Trash date.
- Redesigned the Sort media bottom sheet with mode-specific Lucide icons, compact rows, a coral selected row and custom tick badge. Unselected rows have no trailing arrow. Each row retains a 48 dp minimum touch target. Sorting behavior and modes were not changed. Final AVD evidence: build/prompt05_android/prompt05_sort_sheet_tick_live.png.
- Added/updated Widget tests for legacy Trash metadata, sort selection/semantics/responsive layout, and existing refinement tests that had depended on the old ListTile structure.
- Updated the TASK10 feature-matrix Trash evidence without changing historical overall status.

FILES CHANGED: **30**

UNRESOLVED LIBRARY DEFECTS / VERIFICATION GAPS:

- Android auto-refresh after a new recording/editor copy/export was not exercised. A Photo Library screenshot quick-action tap produced no observed projection/countdown/output; no new app-owned row appeared, so capture auto-refresh could not be assessed. The ADB screenshot evidence is `build/prompt05_android/p05_screenshot_flow.png`; input-vs-action cause remains unknown.
- SAF picker launched, but the AVD DocumentsUI listed no entries in `SDCARD/Documents` while `adb shell ls` and MediaStore showed the generated fixtures. No folder was retained; persisted-grant restart and revoked-grant recovery remain unverified. See `build/prompt05_android/prompt05_saf_docs2.png`.
- Android permission partial-access/denial/revocation flows remain unverified.
- Trash/Restore passed through the current native app actions on task-created media. Flutter confirmation/cancel UI, system consent for non-owned media, multi-select, and editor/export handoffs remain unverified.
- Video playback was observed and Back released the prior player; pause/seek behavior remains unverified. Photo preview used one portrait screenshot only.
- Device-level jank, memory growth, observer callback counts, and TalkBack were not measured.
- The app-owned screenshot PNG shown in Photo Preview contains Launcher pixels. This reproduces the known Prompt04A capture-source mismatch; the Library displayed the stored image correctly, and the capture root cause remains unconfirmed.
- Two generated Restore outputs remain in the AVD Photo Library: valid 64x64 PNG `content://media/external/images/media/438` and malformed 68-byte PNG `content://media/external/images/media/435`. Both are task-owned and must be preserved with the other QA artifacts.

OUT-OF-SCOPE REGRESSION FINDINGS:

- Floating Ball pixels in saved MP4, landscape recording letterboxing, and recording cadence/A/V quality remain open from earlier prompts.
- No physical-device-only checks were possible; the existing docs/qa/PHYSICAL_DEVICE_QA_HANDOFF.md was not expanded with AVD cases.

Detailed evidence is in MEDIA_LIBRARY_TEST_MATRIX.md and MEDIA_LIBRARY_BUGS_AND_FIXES.md.

## PROMPT05A — FOCUSED QA CLOSURE

**PROMPT05A FINAL: PARTIAL**

### Final handoff

ADB/AVD: **PASS** - `emulator-5554`, generic `sdk_gphone16k_x86_64` / `emu64xa16k`, Android 17 / API 37; not Pixel_7. The installed package remains `com.xrecorder.xrecorder` 0.1.0, targetSdk 36. The final Prompt05A debug APK built, but `adb install -r` failed with `INSTALL_FAILED_INSUFFICIENT_STORAGE`; no app data was cleared and the updated SAF restore code was not runtime-installed.

AVD FREE SPACE: **568 MiB -> 557 MiB**. Host free space remained above safety reserves: C: **18.23 -> 18.27 GiB**, D: **20.08 -> 18.92 GiB**.

APP-CAPTURE AUTO-REFRESH: **PASS** - a real screenshot was captured through the Photo Library action after Android MediaProjection consent. One app-owned row appeared after returning to the app without manual Refresh.

EXTERNAL MEDIA AUTO-REFRESH: **PARTIAL** - not isolated from SAF enumeration. CONTENT OBSERVER LIFECYCLE: **PARTIAL** - one app capture survived background/foreground and reconciled without a duplicate; external callback delivery/count was not measured.

SAF FOLDER SELECTION: **PASS** - the real Android picker returned a user-approved tree URI. SAF MEDIA ENUMERATION: **PARTIAL** - DocumentsUI and the app showed no children for the selected task folder although the two task PNGs were present on shared storage. SAF PERSISTED GRANT: **PARTIAL** - the tree preference survived process restart, but the installed build returned to App media; the source fix to restore it has widget/build evidence only because installation was blocked. SAF REVOKE/RETRY: **PARTIAL** - app Disconnect removed the QA-created folder preference/grant; stale access after an OS-side revoke was not tested. The prior Alarms grant was preserved.

SEARCH: **PARTIAL** - exact, lowercase partial, no-match and clear-search passed; Unicode/Vietnamese was not exercised. ALL FIVE SORT MODES: **PASS, 5/5** - Newest, Oldest, Name, Largest and Longest all produced the expected leading item. SOURCE FILTERING: **PARTIAL** - App media and selected-folder scopes were distinct, but the provider returned no folder files.

VIDEO PREVIEW/EDITOR: **PARTIAL** - valid video URI `/404` opened in Preview and handed to the editor with matching title/source/duration; pause/seek were not verified. PHOTO PREVIEW/EDITOR: **PASS for read-only handoff** - app-owned image URI `/467` opened in Photo Preview and Photo Editor; Save copy was not invoked. SCREENSHOT INTEGRATION: **PARTIAL** - publication and Library discovery passed; screenshot pixels were not inspected, so the existing Launcher-source mismatch remains open.

LIBRARY UI: **PASS for exercised controls** - no sort arrow returned, the selected item exposed `selected=true`, and the active recording footer was not run. REGRESSION: **PASS for the short non-destructive set**. AUTOMATED TESTS: **PASS for focused checks** - 18/18 Library widget tests, analyzer clean, and final APK build successful. DATA PRESERVATION: **PASS** - 20 app-owned videos remained; 23 pre-existing app-owned images remained and one QA screenshot was added. Eight pre-existing project files remained present; one task-created editor project was added and retained. The QA SAF folder/grant was disconnected; the existing Alarms grant and all fixture bytes remain.

FLUTTER TESTS: **PASS - 18/18 focused**; the historical 563 full-suite result was not rerun. NATIVE TESTS: **PARTIAL - 162 JVM pass remains historical**; no Kotlin/native code changed in Prompt05A. PHYSICAL DEVICE: **NOT RUN**.

ANDROID CASES: **5/20 PASS cumulative** (M01, M02, M04, M07, M15). REAL VIDEO ITEMS VERIFIED: **20**. REAL PHOTO ITEMS VERIFIED: **24 app-owned rows** (21 original, 2 task-created Restore outputs, 1 task-created screenshot). TRASH/RESTORE TEST TRANSACTIONS: **2 historical; none added in Prompt05A**. EXTERNAL FOLDERS VERIFIED: **1 selected; 0 enumerated**. SORT MODES VERIFIED ON ANDROID: **5/5**.

FILES CHANGED IN PROMPT05A: **6** (three Dart source/test files and the three required reports). No commit or push was made.

### Remaining defects and limitations

- The selected DocumentsUI tree did not enumerate the valid task PNG files; source filtering and external-media observer updates therefore remain partial on this AVD.
- The saved SAF selection did not restore in the installed build. The fix is covered by widget tests and a successful build, but insufficient AVD `/data` prevented its installation and runtime confirmation.
- Search with Vietnamese/Unicode text, player pause/seek, full permission partial-access/revocation, multi-select, active-recording footer layout, and device performance/accessibility remain unverified.
- The new screenshot metadata is valid and the item opens in Preview, but its pixel content was not verified in Prompt05A. Prompt04A's Launcher-source mismatch remains unconfirmed at root cause and out of Library ownership.
- Out-of-scope recording findings remain open: landscape letterboxing, observed low FPS, and audio continuity/A-V synchronization. Floating controls in saved MP4 remain accepted current behavior.

See the Prompt05A evidence and per-case outcomes in MEDIA_LIBRARY_TEST_MATRIX.md and the source-fix notes in MEDIA_LIBRARY_BUGS_AND_FIXES.md. Prompt05/05A is not a release-readiness declaration.
