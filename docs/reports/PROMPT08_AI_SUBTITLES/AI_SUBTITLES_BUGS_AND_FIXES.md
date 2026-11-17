# Prompt08 AI Subtitles Bugs and Fixes

## P08-01 — Selected model reset when the dialog reopened

- Reproduction: choose Tiny in the offline transcription dialog, close it, recreate the dialog/controller, and inspect the model selection.
- Before fix: the dialog restored the speech language from SettingsController but initialized the model field to Base each time. A recreated dialog silently changed the selection.
- Root cause: speech model was not part of persisted settings.
- Fix: SettingsController now validates and persists Tiny, Base and Small-q5_1; restores Base for missing/invalid stored values; and resets to Base with the other preferences. The transcription dialog initializes from this setting and writes selections immediately.
- Regression coverage: settings persistence/validation/reset test and widget test that recreates the dialog and verifies Tiny is still selected. Android selected Tiny for the real job. At task close, Base and Auto were restored.
- Files: lib/features/settings/settings_controller.dart, lib/features/editor/transcription_dialog.dart, test/settings_persistence_test.dart, test/transcription_model_safety_test.dart.

## P08-02 — Model removal deleted immediately

- Reproduction: activate Remove downloaded model for an installed model.
- Before fix: the UI invoked the native delete operation directly. It had an active-job guard but no user confirmation.
- Root cause: the destructive native operation was wired directly to the button.
- Fix: show an explicit confirmation with Cancel and Remove actions. Recheck mounted state and active job state after awaiting the dialog before calling the native removal method.
- Regression coverage: widget test verifies Cancel makes no native delete call and explicit confirmation makes exactly one. No Android model was removed during runtime QA.
- Localization: confirmation text is present in all 14 supported ARB files.

## Other findings

- The current Tiny import, Auto/English recognition, edited cue persistence, SRT output and real MP4 subtitle pixels passed on the AVD.
- No new defect was reproduced in the tested one-clip AAC path.
- The test did not cover Vietnamese recognition, stereo/audio offset edge cases, missing/corrupt audio, runtime cancel/retry, background process recovery, or subtitle remapping through trim/split/reorder/speed changes. These are unverified conditions, not fixes claimed by this report.
