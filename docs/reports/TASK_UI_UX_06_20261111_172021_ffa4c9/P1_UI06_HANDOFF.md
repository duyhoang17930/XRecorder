# UI06 — P1 handoff, pending owner approval

## Auto-stop text overlap
Source: lib/features/settings/recording_settings_form.dart:396–439.
User screenshot: ../../implementation/UI/Screenshot%202026-11-11%20165104.png.
The supporting Text is immediately followed by a TextFormField with a floating label. No spacing separates their painted text. This is a source-backed explanation consistent with the screenshot, not yet a verified Android fix.

Proposed presentation-only patch: [P1_AUTOSTOP_SPACING_PROPOSED.patch](P1_AUTOSTOP_SPACING_PROPOSED.patch).
Add start alignment and 24dp between supporting text and input. Preserve the numeric keyboard, 0..86400 validation, no-limit value0, error behavior, Cancel/Save and SettingsController update.
Status: WAITING FOR P1 OWNER APPROVAL. This patch has NOT been applied.
After approval: test320/360/393/411, portrait/landscape, text100/150/200, IME and invalid/min/max values. Do not certify from source alone.

## Screenshot request / delay
P1 CaptureController.screenshot guards concurrent requests synchronously; native capture owns permission, minimize, fixed3s countdown and success after commit.
P2 removes permanent Home caption and delegates the same public API from the compact Create presenter. No capture/native settings are rewritten.
New requested 0/3/5/10 screenshot delay is NOT supported by the existing contract and must not be faked. Recording countdown is a separate P1 setting.
P1 needs to decide schema migration/default and native parameter before any configurable screenshot-delay UI; pre-capture feedback must clear before capture so it cannot enter the image. No actual screenshot/recording run in this task.

## Other P1 gates carried forward
Four Recording Setup tests remain from UI05B: stale resolution normalization contract, three pinned-handle locators36x4 versus actual40x3. Keep assertions/source unchanged; owner resolves.
Recording setup/form still has hardcoded English; new-install theme default remains pending P1 coordination.
Region unavailable and livestream not connected are removed from primary Create presentation, with original source/routes retained. Offline ASR is real in P3 Subtitle Editor; it is not represented by the disconnected legacy Create card.

## Protected scope
Recording native/Dart, MainActivity, SettingsController, recording form/screen and original studio_create_sheet.dart remain unchanged. New P2 presenter calls public setup/screenshot entrypoints and does not change capture semantics.
TASK10 NOT STARTED.

## Runtime journal delta found by final preservation audit

Evidence: [capture_journal_runtime_comparison.json](capture_journal_runtime_comparison.json), [data_preservation_acceptance.json](data_preservation_acceptance.json).

The original idle session retained the same ID `ab7bfdc7-0614-4241-b81b-cd8f7468a6cd`, `state=idle`, `startedAt=0`, `elapsedMs=0`, `outputUri=null` and no error. Two values changed: `config.countdown: 3 → 0`, `countdownRemaining: 3 → 0`. Recording preferences in `app_settings.xml`, including countdown3s, are byte-identical to the UI06 preflight. No app recording/screenshot was run.

Read-only source findings: `CaptureJournal.initialize()` restores selected fields, does not restore `countdownRemaining`, invokes `CaptureConfig.from()` inside `runCatching`, then calls `save()` unconditionally. `CaptureState` starts with countdownRemaining0 and the default CaptureConfig countdown0. `CaptureConfig.from()` validates the current display and encoder; rejecting the saved1280×720 config on the scaled411×920 QA display is a plausible explanation for the config fallback, not an instrumented proof of the swallowed exception.

P1 review requested: journal round-trip behavior for idle/terminal sessions, config validation versus restoration, and countdown restoration under scaled QA displays. Do not change capture semantics from P2. No journal was manually restored or overwritten. The original archive and all subsequent backups are retained. This is an observed runtime metadata change, not a claim of a new recording or lost media.
