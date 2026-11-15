# Prompt05 Media Library: bugs and fixes

Date: 2026-11-15  
Repository: `D:\FAU_App\XRecorder`  
Branch/HEAD at preflight: `main` / `2a009e679f1ad254bb5d67b5f07880afaa2d9096`

## Existing architecture audited

- Flutter `media_library_screen.dart` / `photo_library_screen.dart` own the video/photo list UI, current search and sort state, and lazy list presentation. `media_sort.dart` defines the existing comparator modes. `thumbnail_cache.dart` provides the bounded compressed-thumbnail cache.
- Flutter `AndroidMediaRepository` in `media_repository.dart` calls the native `com.xrecorder/media` MethodChannel and receives changes from `com.xrecorder/media/events`. It debounces list refresh by 250 ms, coalesces while backgrounded, and requests a reconciliation check on resume.
- Native `MediaCatalog.kt` queries MediaStore and selected SAF trees on a serial worker; a `ContentObserver` fingerprints the current query results, coalesces callbacks for 150 ms, and emits change events. Observer cancellation unregisters its MediaStore observer and stops the legacy file observer. SAF uses the selected content URI and persistable grant path; it is not converted to a filesystem path. A selected tree currently indexes its direct children.
- Native `MediaActions.kt` owns item operations and the app-managed private Trash; Video Preview and Photo Preview stay in their existing Flutter/native screens. The Task08 instrumentation calls the actual `MediaActions` Trash/Restore methods on generated MediaStore rows.

## Confirmed defect: opening Trash could permanently remove entries

**Severity:** P0 data-loss risk.  
**Owner:** native app-managed Trash in `MediaActions.kt`.

Before this change, `listTrash()` ran a 24-hour cleanup before returning the list. It deleted expired rows through `permanentlyDelete()` and also deleted aged `.part` files and `.bin` files whose metadata was absent. Opening the Trash screen therefore performed irreversible cleanup without a separate user action or confirmation. New entries also stored `expiresAt`, and the screen/settings/help text described the automatic cleanup as expected behavior.

### Repair

- `listTrash()` now enumerates only UUID-shaped app-managed Trash filenames, reads and validates metadata identity, and returns entries without deleting anything.
- Missing, corrupt, or orphaned managed records are represented as unreadable entries and their bytes are retained for recovery.
- New entries no longer write an expiry timestamp. Legacy JSON containing `expiresAt` remains readable; it has no effect on retention.
- Permanent deletion remains an explicit Trash action. Restore still verifies the retained backup hash and publishes a new MediaStore item before removing the backup as part of that user-requested restore.
- Dart no longer requires an `expiresAt` field. Trash cards show when an item was moved, and the settings/help text now describes manual restore/permanent-delete actions.
- All 14 ARBs were updated for the renamed copy and date label. The l10n checker passed; the broader human language-quality review remains with Prompt11.
- The Sort media sheet was redesigned after the owner's request: each existing sort mode is a compact, 48 dp minimum touch row with a mode-specific Lucide icon, readable one-line labels, and a coral selected state with an explicit check. Semantics expose button and selected state. The five existing video modes and four photo modes are unchanged.

### Baseline reproduction and post-fix runtime evidence

The isolated Android regression fixture uses a dedicated app-private directory and contains synthetic expired metadata, an expired payload, orphan `.bin`/`.part` files, a corrupt row, and foreign files. It is not pointed at the real `files/trash` directory or MediaStore.

The updated Android test APK was first executed against the still-installed **pre-fix** app binary. It reproduced the defect: `listTrash()` removed the expired JSON/payload and both orphan payloads. The harness reported `restoredRedFixtureInputs=4`; `run-as` hash checks confirmed the four synthetic bytes were recreated exactly. That fixture directory remains in place.

After rebuilding the app specifically for x86_64 (`120,023,451` bytes, final SHA-256 `200A9694C58FD106554E6FAB7851E49F83869BFC737DE78848B9F40357788009`), `adb install -r` succeeded on `emulator-5554` without uninstalling or clearing app data. The current-source instrumentation then reported:

```text
TASK08_TRASH_FOREIGN_PASS: foreign bytes kept; expired and orphan Trash bytes retained; corrupt entry visible; restoredRedFixtureInputs=0; fixture=/data/user/0/com.xrecorder.xrecorder/files/task08_trash_1794744779584/trash
```

The runtime fixture used synthetic app-private files only. The app's real `files/trash` remained empty. The QA fixture and its test files were retained. This proves the fixed `listTrash()` behavior on the current native source; it does not count as a user Trash/Restore transaction.

The first post-edit instrumentation attempt used a stale, pre-existing test APK and is excluded from the results. The later test APK was rebuilt from the changed Java source, first exposed the pre-fix behavior, then passed against the installed current-source app.

### Focused regression coverage

- `test/p2_p3_library_test.dart` displays a legacy row with an expired timestamp and checks that Trash copy describes manual retention and does not show an expiry date.
- `Task08TrashInstrumentation.java` checks that expired/orphan task fixtures remain byte-exact and that damaged data stays visible. The current-source instrumentation APK compiles and its AVD runtime case passes.

## Android MediaStore Trash/Restore transaction

The current native app actions were exercised on two task-created, app-owned MediaStore images. This used a real `ContentResolver` MediaStore row and `MediaActions.trash()`, `listTrash()`, and `restore()`; it did not use original user media or rely on MediaStore `IS_TRASHED` for the app-managed Trash contract.

- Valid fixture: source `content://media/external/images/media/437`, 237 bytes, `image/png`, fully decodable 64x64; Trash removed the source row, and Restore created `content://media/external/images/media/438`. The restored row was app-owned, `is_pending=0`, `is_trashed=0`, and 237 bytes. Source/restored SHA-256: `e03ce841624bb72b375226bbb9e6836701d56d9b774b68ff9fce713d0ac48922`.
- Malformed-image fixture: source URI `content://media/external/images/media/434`, 68 bytes, `image/png` metadata but not a complete decodable image; Restore created app-owned URI `content://media/external/images/media/435` with exact SHA-256 `88f95253dcfe22330c2793b0419262a58420adfbfc791231a60d35da393219fc`. Photo Library showed the graceful broken-image fallback for this item.
- Both original source URIs were absent after Trash. Both restored items remained visible and launchable as library items; the app-private `files/trash` directory was empty after successful restore. All source backups, restored test rows, and evidence JSON remain as QA artifacts.
- This passes task-created native Trash/Restore behavior, but not UI confirmation/cancel, permanent delete consent, or access to non-owned MediaStore items. Those remain open under M16.

## Sort popup QA

- Automated: the sheet exposes the five video/four photo modes, applies a chosen mode, marks the active option as selected, keeps each row at least 48 dp tall, and fits 320/411 dp layouts at 200% text scale in Light and Dark themes.
- Real AVD: current APK displayed the redesigned five-mode video sheet with all labels on one line, no trailing arrows, and a custom coral tick badge on the selected row. Evidence: `build/prompt05_android/prompt05_sort_sheet_tick_live.png` (also captured at `/sdcard/prompt05_sort_sheet_tick_live.png`).
- The screenshot is QA evidence generated by Android shell. It remains on the AVD and is not app-owned Library media.

## Audited but not changed

- No recording, screenshot, editor, preview, MediaStore publication, or SAF implementation was rewritten.
- The source has no `READ_MEDIA_*`, `READ_EXTERNAL_STORAGE`, or `MANAGE_EXTERNAL_STORAGE` declaration. Android 10+ app-owned media is queried by package owner; external folder access uses the selected SAF tree and persisted read grant.
- A selected SAF tree currently indexes its direct children. The real `ACTION_OPEN_DOCUMENT_TREE` picker was launched, but DocumentsUI displayed no entries under `SDCARD/Documents` despite task-created files being present at that shared-storage path and indexed by MediaStore. The flow was canceled without retaining a folder, and the app remained on “App media”. Nested-folder behavior, persisted-grant restart, revoked-grant recovery, and slow providers remain unverified; this is an emulator/provider test gap, not a reproduced app defect.
- Search in the current screen matches `displayName`; no separate title or folder-name search index exists. The full intended search contract was not changed or fully verified on Android.
- The current list uses the five existing modes: Newest, Oldest, Name, Largest, and Longest. The photo screen omits Longest. Runtime sort rendering was not verified on this AVD.
- The repository's existing cache is bounded to 64 compressed thumbnails / 8 MiB and coalesces in-flight loads. No runtime memory/jank measurement was made.

No external Android workaround was borrowed: the confirmed defect was an app-owned private-file retention policy that contradicted the explicit product safety requirement.

## PROMPT05A — FOCUSED QA CLOSURE

### Confirmed fix: restore the saved SAF tree when Library opens

**Owner:** Flutter `MediaLibraryScreen` state initialization.  
**Impact:** after process restart the native `media_catalog` preference and Android grant could remain, but the Library screen initialized `_folder` to null and queried App media. The repository already exposed `savedFolder()`, but the Library never called it. This made the chosen source look forgotten after restart.

**Repair:** on repository attachment, the Library asynchronously loads `savedFolder()` before its first query. A folder revision guard prevents a slow restore from overwriting a newer picker choice or cancellation. If the user acts before the restore finishes, the Library reloads the current source state. A revoked saved grant flows through the ordinary list error state, where the user can choose a folder again.

**Regression tests:** `test/p2_p3_library_test.dart` now verifies a saved tree is used for the first list query and that canceling the picker while restoration is pending does not strand the Library in loading. Both cases pass in the focused suite.

**Runtime limit:** the final debug APK built successfully, but the AVD rejected its in-place update with `INSTALL_FAILED_INSUFFICIENT_STORAGE` at 557 MiB free. The installed Prompt05 build therefore did not contain this fix during the final runtime pass. This change is automated-test/build verified, not runtime verified.

### SAF provider observation (not classified as an app defect)

The genuine DocumentsUI picker returned a user-approved task tree URI:

```text
content://com.android.externalstorage.documents/tree/0000-0000%3ADocuments%2FPrompt05__SS
```

The QA folder physically contained `/sdcard/Documents/Prompt05_SAF_QA_20261115/saf_fixture.png` and `/sdcard/Documents/Prompt05_SAF_QA_20261115/Nested/nested_fixture.png`, 237 bytes each. DocumentsUI showed “No items” inside the selected tree, and the app's direct-child DocumentContract query returned zero rows without a permission error. The `SDCARD` root displayed Android's expected “Can't use this folder” restriction. Since the system picker itself showed the tree as empty, this is recorded as an AVD DocumentsUI/provider enumeration limitation, not a reproduced app permission bypass or app query defect. Nested enumeration was not verified.

The QA-only tree was disconnected through the app after testing. The task-created preference was cleared and, after force-stop, ActivityManager no longer listed that tree. The pre-existing persisted `primary:Alarms` grant remained. The two QA PNG files were retained. A separate OS-side revoke of a stale saved URI and its recovery path remain unverified.

### Prompt05A Android outcomes

- Screenshot capture from Photo Library opened Android MediaProjection consent. After acceptance, app-owned row `content://media/external/images/media/467` (`Screenshot_1794758287113.png`, `image/png`, 1,391,956 bytes, 1080x2400, `is_pending=0`) appeared after returning to the app without Refresh. The app-owned photo count increased 23 -> 24. Pixel-source fidelity was not checked; the known Prompt04A Launcher-source issue stays open.
- Search exact filename matched the intended MP4. Lowercase `recording_` returned 19 of 20 items, a no-match query returned 0 with “No matching media”, and Clear search restored 20. Changing to Largest during the search retained all 19 and put the 74.3 MiB recording first. Unicode/Vietnamese search was not run.
- All five existing video modes were applied on Android: Newest, Oldest, Name, Largest and Longest. The leading item matched the date/name/size/duration contract. The Largest option was selected in the popup (`selected=true`) and no trailing arrow appeared.
- Video `content://media/external/video/media/404` (`Recording_1794738804965.mp4`, 2.6 MiB, 224 s) opened in Preview and then Video Editor with the exact source URI and 224.783 s duration. Editor entry created QA project `files/projects/project_1794759299435822.json`; its clip references `/404`. Eight prior project JSON files remained present. No edits/export were made. Pause/seek were not verified.
- Image `/467` opened in Photo Preview and the existing Photo Editor (“Crop & annotate a copy”). No Save copy was selected; the original row remained present. Source pixel hashes were not captured.
- App-owned MediaStore inventory after QA: 20 videos and 24 images (21 original images, 2 retained Prompt05 Restore fixtures, and the one QA screenshot). No original media was used for destructive actions. The two prior Restore fixtures and SAF QA files remain in place.

### Prompt05A checks and ownership

- `flutter test --no-pub test/p2_p3_library_test.dart`: **18/18 PASS**.
- `flutter analyze --no-pub`: **PASS**, no issues.
- Dart format: **PASS**; `git diff --check`: **PASS** with existing line-ending notices.
- `flutter build apk --debug --no-pub`: **PASS**. `adb install -r`: **BLOCKED** by AVD free space; installed app data and package were preserved.
- No Kotlin/native changes were made; the 162 native JVM tests remain the prior Prompt05 result and were not rerun. The full Flutter 563-test suite was not rerun.
- AVD: generic `sdk_gphone16k_x86_64`, Android 17/API37, not Pixel_7. `/data` changed approximately 568 -> 557 MiB; host reserves remained above limits.

Remaining Library QA gaps: external-media ContentObserver delivery, SAF child enumeration and stale-grant recovery, runtime confirmation of the newly built saved-tree restoration, Unicode search, player pause/seek, permission partial-access/revocation, active recording footer, bulk selection, and large-library on-device performance. Recording cadence/A-V, landscape letterboxing, accepted floating controls, and screenshot source fidelity remain owned by their existing prompts.

