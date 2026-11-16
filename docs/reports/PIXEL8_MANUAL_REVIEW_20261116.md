# 3HRecorder — Pixel 8 direct interaction review

**Result: issues found; not ready for an unconditional feature sign-off.** Main production screen families were opened and exercised directly. Recording, region capture, screenshot, photo/video editing, MP4/GIF export, Trash, and local RTMP streaming produced real output. Offline transcription failed in the tested edited project. Recording duration/audio timing also needs investigation.

This is broad emulator coverage, not a claim that every setting combination, failure injection, language, or physical-device behavior passed. Partial and unverified branches are listed explicitly below.

## Test environment

| Item | Value |
|---|---|
| Session | 2026-11-16 23:33 through 2026-11-17, Asia/Saigon |
| Device | Existing `Pixel_8` AVD, `emulator-5554`, x86_64 |
| Android | Android 17 / API 37 |
| Display | 1080×2400 portrait; 2400×1080 landscape smoke check |
| App | 3HRecorder 0.1.0 (1), `com.xrecorder.xrecorder` |
| Revision | `43bdb627aff82a25c563676a2bde1358dbc0e320` |
| Build | Fresh `flutter build apk --debug`; non-destructive `adb install -r` |
| Interaction | Actual emulator touch presses, swipes, text input, Android permission dialogs, notification actions and app navigation through ADB |
| Verification | Screenshots, UI Automator XML, Android logs, SHA-256 comparisons, ffprobe and full FFmpeg decoding |

No application source was changed. No uninstall, clear-data, or AVD wipe was performed. Existing media/drafts were preserved; deletion tests used only a newly created QA photo. No feedback message was sent. Livestream traffic went to a temporary local FFmpeg receiver on this PC.

The emulator experienced app/system ANRs and host graphics failures. Testing continued after cold boots of the same AVD. A temporary app software-rendering launch was used early; later testing used the normal APK with the emulator running headless, host GPU, and Vulkan disabled. Results do not establish behavior on physical Pixel 8 hardware.

## Findings requiring attention

### F1 — High: offline transcription cannot prepare edited audio

Reproduction:

1. Record a muted screen clip and create a video project.
2. Split/reorder clips and apply 2× speed.
3. Import the provided 9.093-second spoken WAV as an audio track and commit it.
4. Open Subtitles → Generate offline subtitles.
5. Select Tiny and English; download until the model is installed and verified.
6. Choose Recognize edited audio.

**Observed:** immediate failure at 0%: “Edited audio could not be prepared. Check the source clips and retry.” Retrying after adding speech produced the same failure. The project subsequently exported successfully with a non-silent AAC track (mean -29.5 dBFS, maximum -8.6 dBFS). This establishes a failure in this project, not its root cause or recognition accuracy.

**Expected:** prepare the mixed edited audio and proceed to recognition, or explain a specific unsupported input condition.

Evidence: [failure with spoken audio](PIXEL8_MANUAL_20261116/evidence/asr_running.png), [verified model](PIXEL8_MANUAL_20261116/evidence/model_keep.png), [audio import](PIXEL8_MANUAL_20261116/evidence/audio_added.png), [audio analysis](PIXEL8_MANUAL_20261116/evidence/export_audio_analysis.txt), [speech fixture](PIXEL8_MANUAL_20261116/evidence/QA_speech.wav).

### F2 — High: microphone/facecam output has unequal track lengths

**Observed:** the saved microphone/facecam recording contains **307.296589s of video** and **125.397333s of AAC audio**. A camera overlay is visible in the saved frames. No pause/resume was intentionally performed in this session; notification/floating/drawing interactions were exercised. Microphone content intelligibility was not evaluated.

**Expected:** audio and video should cover the active recording duration with a small, explained end difference. Investigate timestamp generation, audio continuity and emulator capture behavior; repeat on a physical device before assigning root cause.

Evidence: [normalized probe](PIXEL8_MANUAL_20261116/evidence/facecam_probe_utf8.json), [saved clip](PIXEL8_MANUAL_20261116/evidence/facecam.mp4), [camera frame](PIXEL8_MANUAL_20261116/evidence/facecam_frame.png).

### F3 — Medium: five-second auto-stop produces an 11.05-second file

**Observed:** selected five seconds, saved the setting, selected Android single-app capture for 3HRecorder, and allowed the session to end automatically. The app entered Processing and returned to Ready without a manual Stop. The resulting MP4 duration is **11.054200s**.

**Expected:** output duration close to the five-second active-recording limit. The UI behavior passed; output timing did not match the selection in this run. Single-app capture, encoder startup and emulator timing need isolation.

Evidence: [five-second selection](PIXEL8_MANUAL_20261116/evidence/auto_duration5.png), [single-app chooser](PIXEL8_MANUAL_20261116/evidence/single_app_chooser.png), [processing](PIXEL8_MANUAL_20261116/evidence/auto_stop_result.png), [probe](PIXEL8_MANUAL_20261116/evidence/autostop_probe_utf8.json), [file](PIXEL8_MANUAL_20261116/evidence/autostop.mp4).

### F4 — High impact, attribution unresolved: ANRs and emulator instability

The initial app session produced `Input dispatching timed out ... Waited 5060ms for FocusEvent(hasFocus=false)`. A fresh default launch showed a prolonged black surface. Android also displayed “Process system isn't responding”; DocumentsUI was involved in a no-focused-window ANR. Cold startup later produced another app ANR. The emulator process exited during the first GIF attempt.

Host/emulator factors were substantial: approximately 16 GB host RAM, a four-CPU Android 17 guest, background Play Store updates/compilation and guest CPU saturation. GUI restarts encountered Qt/OpenGL errors. Stopping background Play Store activity and the idle Gradle daemon, then using a headless boot, allowed further testing. These observations do **not** prove that every stall was caused by the app.

Evidence: [initial app ANR](PIXEL8_MANUAL_20261116/evidence/lastanr.txt), [system ANR](PIXEL8_MANUAL_20261116/evidence/system_anr.txt), [cold-start ANR](PIXEL8_MANUAL_20261116/evidence/cold_anr.txt), [system dialog](PIXEL8_MANUAL_20261116/evidence/about.png), [graphics log](PIXEL8_MANUAL_20261116/evidence/emulator_host_stdout.txt).

### F5 — Performance and accessibility observations

- The first 720p/30-FPS recording contains 290 frames over 20.320478s, approximately **14.27 average FPS**. This is a loaded-emulator observation, not a physical-device benchmark.
- Several overlay controls and initially empty text fields did not expose useful labels in the collected accessibility tree. The floating panel was visible in screenshots while its controls were absent from app-only XML. A TalkBack review remains necessary before calling these controls accessible.
- Drawing mode intercepts touches intended for the underlying app. Stop via the recording notification worked. Floating drawing, palette, undo/clear and stop interactions were attempted, but not all outcomes could be reliably confirmed.
- README descriptions of deferred/unexposed features differ from the current UI, which exposes livestream, region capture and floating controls.

Evidence: [recording probe](PIXEL8_MANUAL_20261116/evidence/recording_probe_utf8.json), [floating panel](PIXEL8_MANUAL_20261116/evidence/floating_ball.png), [drawing mode](PIXEL8_MANUAL_20261116/evidence/ball_expanded_again.png), [notification stop](PIXEL8_MANUAL_20261116/evidence/facecam_notification_stopped.png).

## Screen and feature coverage

**Pass** means the stated interaction/output was observed. **Partial** means the screen opened and some controls were exercised, but the stated remaining behavior is unverified. Screen access alone is not a functional pass.

### Navigation, capture and libraries

| Screen / feature | Result | What was tested / evidence |
|---|---|---|
| Existing-data launch and four main tabs | Partial | Video, Photo, Edit and Settings navigate; saved data survives restarts. Startup stability has F4. [Initial home](PIXEL8_MANUAL_20261116/evidence/baseline.png), [recovered hub](PIXEL8_MANUAL_20261116/evidence/editing_hub.png). |
| Create menu / All tools | Pass for navigation | Recording, screenshot, region, recording settings, livestream and editing entries visible; major destination screens exercised. [Create](PIXEL8_MANUAL_20261116/evidence/create_menu.png). |
| Recording setup: Basic / Advanced | Pass for sampled controls | Both views opened; quality, audio, countdown, facecam, advanced options and close/reset exercised. [Basic](PIXEL8_MANUAL_20261116/evidence/setup_basic.png), [Advanced](PIXEL8_MANUAL_20261116/evidence/setup_advanced.png). |
| Recording settings / capability limits | Pass for UI | Normal/Performance modes, resolution, FPS, bitrate and orientation selections exercised. Unsupported 2K/4K, HEVC, 90/120 FPS disabled; 1080p constrained FPS on this AVD. [Normal](PIXEL8_MANUAL_20261116/evidence/normal_mode.png). Actual encoding combinations were sampled, not exhaustive. |
| Android consent: deny, full screen, single app | Pass | Cancel returns Ready without a new file; entire-screen consent records; single-app chooser selects 3HRecorder. [Consent](PIXEL8_MANUAL_20261116/evidence/consent.png), [single-app](PIXEL8_MANUAL_20261116/evidence/single_app_chooser.png). |
| Record / pause / resume / stop / saved banner | Pass | Real capture; pause and stable paused timer; resume; stop; new library item and saved banner. Screenshot unavailable during recording. [Paused](PIXEL8_MANUAL_20261116/evidence/recording_paused.png), [saved](PIXEL8_MANUAL_20261116/evidence/recording_saved.png). |
| Background notification controls | Pass | Pause, Resume and Stop exercised during region recording. Facecam recording also stopped via notification. [Notification](PIXEL8_MANUAL_20261116/evidence/recording_notifications.png). |
| Countdown / auto-stop | Partial / F3 | Three-second countdown selected and recording starts; five-second auto-stop ends automatically but output duration is 11.05s. Countdown cancellation and paused-time auto-stop accounting unverified. |
| Camera permission / facecam | Partial / F2 | Camera prompt approved; overlay visible in-app, on Home and in recorded output. Audio duration mismatch; camera movement/resize and all rejection paths unverified. [Facecam](PIXEL8_MANUAL_20261116/evidence/facecam_recording.png). |
| Floating permission / panel / drawing | Partial | Open Android overlay list, allow app, show controls via notification, expand/collapse panel, enable pen, attempt drawing. Permission restored off afterward. Reliable per-control accessibility and every action outcome unverified. [Panel](PIXEL8_MANUAL_20261116/evidence/floating_ball.png). |
| Screenshot | Pass | Fresh consent; minimizes app; delayed PNG capture; saved banner on return; Photo catalog refresh; opens captured image. [Saved](PIXEL8_MANUAL_20261116/evidence/screenshot_saved.png). Banner timeout/View action not independently timed. |
| Region selection and recording | Pass | Width slider changes selection; consent minimizes app; notification controls save real cropped video. Selected/output dimensions 598×1200. Rotation-stop branch unverified. [Region](PIXEL8_MANUAL_20261116/evidence/region_adjusted.png), [probe](PIXEL8_MANUAL_20261116/evidence/region_probe_utf8.json). |
| Video library / sort / search | Partial | App catalog, Oldest sorting and search text/clear exercised. Empty search capture had keyboard open; every sort key and positive search result not separately validated. [Sort](PIXEL8_MANUAL_20261116/evidence/sort_options.png), [search](PIXEL8_MANUAL_20261116/evidence/media_search_empty.png). |
| Storage usage | Pass | Video/photo/cache/Trash usage sheet displays values and excludes external folders. [Usage](PIXEL8_MANUAL_20261116/evidence/storage_usage.png). |
| SAF folder browsing / disconnect | Pass | Root is restricted by Android; Alarms/QA_Pixel8 grant loads one copied video; disconnect confirmation returns to app catalog. [Folder catalog](PIXEL8_MANUAL_20261116/evidence/external_library.png), [disconnect](PIXEL8_MANUAL_20261116/evidence/disconnect_dialog.png). |
| Media details and external-file details | Pass for sampled details | Video/photo metadata/actions open; external-file management explanation visible. [Video](PIXEL8_MANUAL_20261116/evidence/video_preview.png), [photo](PIXEL8_MANUAL_20261116/evidence/photo_details.png), [external](PIXEL8_MANUAL_20261116/evidence/external_details.png). |
| Video / photo preview | Pass for opening/playback | Native video displays captured content and Back returns; exported MP4 opens; photo preview opens. Seeking/fullscreen/controller timing not exhaustively tested. [Video](PIXEL8_MANUAL_20261116/evidence/native_playback.png), [photo](PIXEL8_MANUAL_20261116/evidence/photo_preview.png). |
| Rename / filename validation | Pass | New recording renamed; empty filename produces validation notice; reopen and valid name succeeds. [Invalid](PIXEL8_MANUAL_20261116/evidence/rename_filled.png), [valid](PIXEL8_MANUAL_20261116/evidence/renamed.png). |
| Share media | Pass for chooser handoff | Android chooser identifies renamed MP4; dismissed without sending. [Share](PIXEL8_MANUAL_20261116/evidence/video_share.png). |
| Copy to folder | Pass | Created QA folder, granted SAF access, pending file finalizes; source/copy SHA-256 match. [Hashes](PIXEL8_MANUAL_20261116/evidence/copy_hashes.txt). Move-to-folder completion was not tested. |
| Trash / restore / delete permanently | Pass | Only session-created JPEG trashed, restored under new name, byte hash verified, re-trashed and permanently deleted after confirmation. Empty state returns. [Trash](PIXEL8_MANUAL_20261116/evidence/trash_items.png), [restore](PIXEL8_MANUAL_20261116/evidence/restored_library.png), [delete](PIXEL8_MANUAL_20261116/evidence/delete_confirm.png). |

### Editing and output

| Screen / feature | Result | What was tested / evidence |
|---|---|---|
| Editing hub / persisted drafts | Pass | QA draft creation from media details; reopen after emulator restart; duplicate and delete QA copy. Original draft preserved. [Duplicate](PIXEL8_MANUAL_20261116/evidence/duplicate_final.png), [delete](PIXEL8_MANUAL_20261116/evidence/draft_deleted.png). |
| New project / mixed-media picker | Pass | Videos/Photos tabs, multi-select and Add create a video+photo project. Empty selection disables Add. [Picker](PIXEL8_MANUAL_20261116/evidence/new_project_picker.png), [mixed](PIXEL8_MANUAL_20261116/evidence/mixed_ready.png). |
| Shortcut request | Partial | Requests launcher pin confirmation; cancelled to preserve Home layout. Actual pinned-shortcut launch unverified. [Request](PIXEL8_MANUAL_20261116/evidence/shortcut_request.png). |
| Project rename / saved status | Pass | QA_Project name saved; Saved / Originals unchanged status; survives restart. [Rename](PIXEL8_MANUAL_20261116/evidence/project_name.png). |
| Editor preview / timeline | Pass for sampled sequence | Play/pause advances native preview, select clips, reach end; mixed still duration changes 5s → 2s. [Edit panel](PIXEL8_MANUAL_20261116/evidence/edit_panel.png), [still](PIXEL8_MANUAL_20261116/evidence/still_two_seconds.png). |
| Split / duplicate / reorder / remove / undo / redo | Pass | Split at 14.2s creates two clips; duplicate, undo, redo, remove and Move later exercised. [Split](PIXEL8_MANUAL_20261116/evidence/split.png), [redo](PIXEL8_MANUAL_20261116/evidence/redo_duplicate.png), [reorder](PIXEL8_MANUAL_20261116/evidence/moved_later.png). Direct trim handles and replace-source completion unverified. |
| Transform / crop | Pass for sampled state/output | 90° rotation, horizontal flip and left crop 19%; output inspected. Crop geometry not independently pixel-measured. [State](PIXEL8_MANUAL_20261116/evidence/export_queue_back.png). |
| Effects screen: all five sections | Pass for navigation; partial values | Video, Audio, Subtitles, Overlays and Export quality opened. Grayscale and 2× speed applied; audio advanced panel opened. Every voice/noise/aspect/fade setting not independently rendered. [Effects](PIXEL8_MANUAL_20261116/evidence/effects.png), [audio](PIXEL8_MANUAL_20261116/evidence/advanced_audio.png), [quality](PIXEL8_MANUAL_20261116/evidence/quality.png). |
| Text / sticker / drawing layers | Pass for sampled output | QA_text, yellow star, straight line added; move-layer-forward action; committed layers visible in export. Freehand gesture was attempted, not independently confirmed. [Layers](PIXEL8_MANUAL_20261116/evidence/drawing_used.png), [rendered frame](PIXEL8_MANUAL_20261116/evidence/export_frame.png). |
| Added audio / trim-mix dialog | Pass for one track/output | 9.093s WAV imported through DocumentsUI, volume adjusted, committed; stereo AAC export non-silent. Multi-track limits, voice/noise treatment and all alignment fields unverified. [Dialog](PIXEL8_MANUAL_20261116/evidence/audio_added.png). |
| Manual subtitles / SRT | Pass for add/copy/save/burn-in | QA_subtitle at 0–1s; copy; SAF save; file content checked; subtitle visible in MP4. Cue update/split/merge/delete and SRT import not exercised. [Subtitle](PIXEL8_MANUAL_20261116/evidence/subtitle_added.png), [SRT](PIXEL8_MANUAL_20261116/evidence/srt_picker.png). |
| Offline model / speech language | Pass for download/selection | Tiny download verified 100%; English selected; remove confirmation cancelled. Local model import and actual removal not completed. [Model](PIXEL8_MANUAL_20261116/evidence/model_keep.png), [languages](PIXEL8_MANUAL_20261116/evidence/speech_language.png). |
| Automatic transcription | Fail | F1; no successful transcription or accuracy claim. |
| MP4 export / queue / playback | Pass | Progress → Saved; Open saved media → Preview; real transformed video, audio, layers and subtitles. [Queue](PIXEL8_MANUAL_20261116/evidence/export_done.png), [frame](PIXEL8_MANUAL_20261116/evidence/export_frame.png). |
| GIF settings / export | Pass after retry | GIF format, 10 FPS / 320px / repeat 0 controls; final GIF 180×320, 102 frames, 10.17s, no audio. [Settings](PIXEL8_MANUAL_20261116/evidence/gif_quality.png), [file](PIXEL8_MANUAL_20261116/evidence/export.gif). |
| Export interruption / retry / cancel | Pass for observed recovery | First GIF interrupted by AVD exit; restart shows failed job with Retry. Retry starts; Cancel yields Cancelled 12%; subsequent Retry ultimately saves GIF. [Recovery](PIXEL8_MANUAL_20261116/evidence/recovery_queue.png), [cancel](PIXEL8_MANUAL_20261116/evidence/recovery_cancel.png). |
| Photo editor / tool menu | Pass for navigation and sampled output | Crop, pen, eraser, shape, text, sticker, transform, color, all-tools and quality panels exercised. [All tools](PIXEL8_MANUAL_20261116/evidence/photo_all_tools.png). |
| Photo editing / undo-redo / save-copy | Pass for verified edits; partial eraser/sticker | Freehand line, rectangle, text, crop, rotate/flip and undo/redo exercised. JPEG save creates separate copy with visible edits. Heart selected but placement not confirmed; eraser removal not independently confirmed. [JPEG](PIXEL8_MANUAL_20261116/evidence/photo_output.jpg). |
| Photo format/size options | Pass for JPEG sample | PNG/JPEG selector and longest-edge option; JPEG output 2048×779, 205298 bytes. PNG save and every quality/size choice not sampled. [Quality](PIXEL8_MANUAL_20261116/evidence/photo_quality.png). |

### Livestream, settings, help and support

| Screen / feature | Result | What was tested / evidence |
|---|---|---|
| Livestream form / validation / save / forget | Pass | Empty URL/key errors; local destination saved encrypted per UI, masked key, no automatic start; forget confirmation clears temporary destination. [Validation](PIXEL8_MANUAL_20261116/evidence/live_validation.png), [saved](PIXEL8_MANUAL_20261116/evidence/live_saved.png), [forget](PIXEL8_MANUAL_20261116/evidence/forget_state.png). Encryption implementation not independently audited. |
| RTMP streaming / local recording / reconnect | Pass for local RTMP; partial stop/reconnect | FFmpeg on PC receives H.264 720×1280 for 14.989s; local MP4 also saved. Receiver closure leads to Reconnecting. End action raced with state change and opened fresh consent; cancelled. Graceful stop while receiver remains connected and RTMPS unverified. [Receiver log](PIXEL8_MANUAL_20261116/evidence/local_livestream_receiver.txt), [probe](PIXEL8_MANUAL_20261116/evidence/local_livestream_probe_utf8.json), [status](PIXEL8_MANUAL_20261116/evidence/live_status.png). |
| Settings hub / media storage | Pass | Scroll sections; storage information opens/closes. [Settings](PIXEL8_MANUAL_20261116/evidence/settings_top.png), [storage](PIXEL8_MANUAL_20261116/evidence/storage.png). |
| Theme / language / persistence | Pass for sampled choices | Dark/Light/System selected; Vietnamese ↔ English; baseline Follow system restored. Preferences/drafts survive restart. Not a 12-language translation audit. [Dark](PIXEL8_MANUAL_20261116/evidence/dark_theme.png), [Vietnamese](PIXEL8_MANUAL_20261116/evidence/vietnamese.png), [System](PIXEL8_MANUAL_20261116/evidence/system_theme.png). |
| Reset confirmation / defaults | Pass | Reset preferences confirmation cancelled; setup Reset defaults executed and changes settings. Baseline visible quality/audio/theme restored afterward. [Confirmation](PIXEL8_MANUAL_20261116/evidence/reset_confirm.png), [defaults](PIXEL8_MANUAL_20261116/evidence/reset_defaults.png). |
| Touch guidance | Pass | Explains manual Android Show taps setting and closes. [Guidance](PIXEL8_MANUAL_20261116/evidence/touch_guidance.png). |
| Help / search / expand | Pass for sample | Expand first guide; unmatched search shows No matching guides; clear. [Expanded](PIXEL8_MANUAL_20261116/evidence/help_expanded.png), [empty](PIXEL8_MANUAL_20261116/evidence/help_no_results.png). |
| Introduction replay / Skip | Pass | Next through all three pages, Get Started; reopen and Skip. Fresh-install resumability not tested to preserve data. [Page 3](PIXEL8_MANUAL_20261116/evidence/intro3.png), [Skip](PIXEL8_MANUAL_20261116/evidence/intro_skipped.png). |
| Feedback / diagnostics / copy / share | Pass for sampled handoffs | Opt-in diagnostics visible; copy email confirms; empty report blocked; filled test report opens text chooser, dismissed. Attachment picker opens. No email/issue/share sent. Attachment size/type rejection and email/GitHub handoffs unverified. [Diagnostics](PIXEL8_MANUAL_20261116/evidence/feedback_state.png), [validation](PIXEL8_MANUAL_20261116/evidence/feedback_empty_validation.png), [share](PIXEL8_MANUAL_20261116/evidence/feedback_share.png). |
| Privacy / Terms browser handoff | Pass | Chrome opened publisher Privacy and Terms pages. Chrome first-run completed signed out; notification prompt declined. [Privacy](PIXEL8_MANUAL_20261116/evidence/privacy_page.png), [Terms](PIXEL8_MANUAL_20261116/evidence/terms_actual.png). Legal contents not reviewed for compliance. |
| About / licenses / individual license | Pass | Version 0.1.0 (1), license list and Media3 detail; return navigation. [About](PIXEL8_MANUAL_20261116/evidence/about_dialog.png), [licenses](PIXEL8_MANUAL_20261116/evidence/licenses.png), [detail](PIXEL8_MANUAL_20261116/evidence/license_detail.png). |
| Enlarged text / landscape | Partial smoke check | Font scale 1.3 and landscape applied temporarily; Settings landscape screenshot renders; restored original display settings. Transient null-root dump and incomplete navigation prevent a full accessibility/layout pass. [Landscape](PIXEL8_MANUAL_20261116/evidence/settings_landscape.png), [original values](PIXEL8_MANUAL_20261116/evidence/original_display_settings.json). |

## Artifact validation

All eight pulled test artifacts completed full decoding with exit code 0 and no FFmpeg error output when preserving variable frame timestamps. This does not override F2/F3: a decodable file can still have incorrect timing.

| Artifact | Verified result |
|---|---|
| [Muted recording](PIXEL8_MANUAL_20261116/evidence/recording.mp4) | H.264 720×1280; 20.320478s; no audio as selected |
| [Edited MP4](PIXEL8_MANUAL_20261116/evidence/export.mp4) | H.264 1280×720 with rotation metadata; 10.119322s video; 10.180499s stereo AAC, 44100Hz; non-silent |
| [Region clip](PIXEL8_MANUAL_20261116/evidence/region.mp4) | 598×1200; 42.863144s |
| [Facecam clip](PIXEL8_MANUAL_20261116/evidence/facecam.mp4) | 307.296589s video; 125.397333s AAC — F2 |
| [Auto-stop clip](PIXEL8_MANUAL_20261116/evidence/autostop.mp4) | 11.054200s despite five-second selection — F3 |
| [GIF](PIXEL8_MANUAL_20261116/evidence/export.gif) | 180×320; 102 frames; 10.17s; no audio |
| [Local RTMP capture](PIXEL8_MANUAL_20261116/evidence/local_livestream.flv) | H.264 720×1280; 14.989s; mute selected |
| [Photo output](PIXEL8_MANUAL_20261116/evidence/photo_output.jpg) | JPEG 2048×779; visible crop/transform/annotations; 205298 bytes |

Machine-readable streams, decode results and SHA-256: [artifact_validation.json](PIXEL8_MANUAL_20261116/evidence/artifact_validation.json). Re-run using [verify_artifacts.py](PIXEL8_MANUAL_20261116/evidence/verify_artifacts.py). Copy hashes and restore hashes are retained alongside the files.

## Remaining gates and limits

The table above identifies specific partial branches rather than treating them as passes. In addition, this run does not establish physical-device camera/audio quality, protected internal-audio behavior, every audio-source/codec/quality combination, storage-full/provider-revocation handling, successful ASR accuracy, long export/recording endurance, RTMPS, or a complete TalkBack/large-text/landscape/localization audit. No destructive failure injection was applied to pre-existing user data. Debug-only component showcase and artificial empty/error routes were not treated as production user screens.

## Final device/workspace state

- App left running on the same Pixel 8 AVD, capture idle; baseline Light / Follow system / 1080p / 30 FPS / Internal Audio restored. Reset defaults also reset other recording preferences; they are not claimed to match every pre-session custom value.
- Facecam off, auto-stop cleared by reset; overlay permission returned to denied. Temporary font/rotation changes restored.
- Existing original media and draft remain. New QA recordings/exports, screenshot, mixed project, QA_Project, spoken fixture and downloaded Tiny model remain for reproduction. Duplicate QA draft and session-created JPEG were deleted through the tested UI. External QA copy/SRT remain in Alarms/QA_Pixel8; folder browsing disconnected. Temporary livestream destination forgotten; receiver completed.
- Emulator runs headless because GUI startup hit Qt/OpenGL errors. No production deployment, application-code fix or Git commit was made.
- Evidence includes screenshots/XML, logs, media and helper scripts. Earlier UI Automator calls could leave stale XML on null-root failure; screenshots/output artifacts take precedence. The helper was corrected to use unique dump files and reject missing-root results. In particular, disregard `recovered_home.xml`; `recovered_ready` is the valid home capture.

**Review recommendation:** investigate F1–F3 and reproduce F4 on a stable emulator/physical device before release. Keep the successful output workflows as regression cases. Do not describe this session as a full pass of every feature branch.
