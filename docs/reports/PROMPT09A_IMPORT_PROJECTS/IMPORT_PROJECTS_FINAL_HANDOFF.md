# Prompt 09A — Import and project persistence final handoff

## ENVIRONMENT

**GIT STATE:** `main`; product source unchanged. Documentation changes are uncommitted. No reset, clean, stash, commit or push.

**ANDROID DEVICE:** Pixel_7 AVD, `emulator-5554`, `sdk_gphone16k_x86_64`, Android 17 / API 37 / x86_64.

**FINAL APK SHA-256:** `B822F2234D2C5D0FC3EF87B922CDC0EAE9A8D5895DAE2EA6C60F2E59354B7A6C` (same as Prompt08 and current local debug APK).

**APK INSTALL:** No update needed; installed APK matched the current local APK. No uninstall or app-data clear.

**FREE STORAGE BEFORE:** 427,784 KiB (`/data`).

**FREE STORAGE AFTER:** 426,948 KiB (`/data`).

## IMPORT

**VIDEO IMPORT:** PASS — app-owned MediaStore video opened; Prompt08 SAF video selected and previewed from its content URI.

**PHOTO IMPORT:** PASS — task-owned PNG selected from SAF and opened in Photo Editor; original fixture left untouched.

**AUDIO IMPORT:** PASS — 1-second PCM WAV selected through Android’s `audio/*` document picker, metadata read and URI persisted in an editor track.

**SAF FILE PICKER:** PASS — video/audio document access used `content://` references; no bulk source copy.

**SAF FOLDER PICKER:** PASS — persisted tree selection and restart worked.

**FOLDER ENUMERATION:** PASS — Prompt08 tree exposed its one direct video; the known fixture tree exposed its direct PNG. The separately selected `Prompt05__SS` folder is genuinely empty and correctly shows zero videos.

**PERSISTENT URI GRANTS:** PASS — pre-existing grants remained; task fixture/audio grants and the restored `Prompt05__SS` selection grant were retained. No permission was revoked.

**METADATA VALIDATION:** PASS — video: `video/mp4`, 11s, 320×180; photo: `image/png`, 64×64; audio: 1s.

**PICKER CANCEL/ERROR:** PASS — Back from the audio picker returned to the existing track dialog with the track intact. Invalid project source showed a clear playback/access error and remained relinkable.

## PROJECTS

**EXISTING PROJECT REOPEN:** PASS — Prompt08 project reopened with source and editable subtitle cues.

**SAVE NEW PROJECT:** PASS — created two independent task-owned copies; one was saved with a 1s audio track and the other with both original subtitle cues plus that audio track.

**REOPEN NEW PROJECT:** PASS — after process restart, project `project_1794820476111724` retained both cue texts/timings and the audio track. Relinked project `project_1794820069846523` reopened with working preview and its track.

**SCHEMA COMPATIBILITY:** PASS — existing version-1 files remain byte-identical; focused legacy/reopen tests passed. No migration or rewrite of historical projects.

**MISSING SOURCE:** PASS — controlled nonexistent document URI on task-owned project displayed “Couldn’t play this video. Check access or choose another file.” Project and timeline stayed available.

**SOURCE RELINK:** PASS — replacement video passed type/duration validation; reference changed while trim/effects/audio state remained. Preview recovered after relink and restart.

**AI SUBTITLE CUE PERSISTENCE:** PASS — both cues remained exact: 0–5.4s “And so my fellow Americans, ask not what your country can do for”; 5.4–10.8s “you, ask what you can do for your country. Xin chào Việt Nam!” No inference was rerun.

**INTERRUPTED SAVE RECOVERY:** PARTIAL — Flutter save-failure/retry tests passed. The two native `EditorStorageTest` cases validate storage estimates, not interrupted `AtomicFile` writes. No device power-loss or forced storage-write interruption was induced.

## DATA SAFETY

**ORIGINAL VIDEO COUNT:** 20 historical originals; current MediaStore has 25 rows (22 app-owned), unchanged from preflight.

**ORIGINAL PHOTO COUNT:** 24 historical originals; current MediaStore has 26 app-owned rows, unchanged from preflight. Total image rows rose from 335 to 341 because six task-owned emulator screenshots were indexed as `com.android.shell`; they were retained.

**BASELINE PROJECT HASH MATCHES:** 12/12. The full manifest is in `IMPORT_PROJECTS_AUDIT.md`.

**TASK-OWNED PROJECTS:** `project_1794820069846523.json`, `project_1794820476111724.json`.

**WHISPER MODEL PRESERVED:** Yes — 77,691,713-byte Tiny model still hashes to `be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21`.

**PREFERENCES PRESERVED:** Yes — settings, media catalog and speech-model preference hashes exactly match preflight; original `Prompt05__SS` folder selection was restored.

**SAF GRANTS PRESERVED:** Yes — no grant was removed. Existing Alarms, Prompt08, SRT and model grants remain; QA selections added grants for the task fixture/audio and restored empty folder.

**ORIGINAL MEDIA BYTE CHECK:** The previously selected existing video `Recording_1794674748965.mp4` kept SHA-256 `d473568ff12fc98cd562fd5336393b5c2fbc073c3e31b3ef4bf384c0a4d6b935`. No original was edited, renamed, deleted, or used as an output target.

## TESTING

**ANDROID CASES PASS:** 12/12 — detailed statuses/evidence in `IMPORT_PROJECTS_TEST_MATRIX.md`.

**FOCUSED FLUTTER TESTS:** 28/28 passed.

**FOCUSED NATIVE TESTS:** 7/7 passed (MediaCatalog 1, TimelineAudioLimit 2, SubtitleText 2, EditorStorage 2).

**ANALYZER:** `flutter analyze` — no issues.

**FORMAT:** 13 relevant Dart/test files already formatted.

**DATA PRESERVATION:** 12/12 project hashes, relevant settings/model preferences, model hash, selected existing-video hash and app-owned MediaStore row counts match preflight.

**FILES CHANGED:** Three Prompt09A reports and the requested physical-device QA handoff only. No product source, localization, package ID or APK changed. `git diff --check` passed after these documents were written.

## UNRESOLVED ISSUES

- Provider permission revocation, SD-card removal/reinsertion, unsupported codec replacement, and a device-level interrupted write were not induced in this emulator run.
- SAF folder enumeration lists direct children only; nested-folder traversal is not implemented.
- Six task QA screenshots were added to MediaStore by emulator capture. They remain present; no existing MediaStore item was deleted.
- Physical-device/OEM coverage remains pending as recorded in `docs/qa/PHYSICAL_DEVICE_QA_HANDOFF.md`.
- The prior Video Library search-input ANR was not reproduced or re-evaluated here.

## NEXT TASKS FOR PROMPT09B

Keep Prompt09B to export-queue reliability, cancel/retry behavior, complex multi-clip and long-video exports, GIF validation, multi-track export regression, comprehensive SRT/MP4 export integration, and low-storage export scenarios. Prompt09A made no export-queue changes.

## FINAL VERDICT

**PROMPT09A — DONE**

The existing Android import, URI, save/reopen, missing-source and relink workflows passed the focused emulator cases. Original project hashes, selected source/model bytes, preferences and app-owned media counts were preserved. The unsimulated failure/provider and physical-device cases are documented above and in the hardware handoff.
