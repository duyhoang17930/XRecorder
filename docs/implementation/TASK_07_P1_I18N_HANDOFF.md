# TASK07 — P1 localization handoff (no P1 patch applied)

Status: **P1 INTEGRATION OPEN**. P2/P3 provide Flutter generated localization,
12 target locales, persisted app-locale selection, system fallback and RTL.
The17 protected P1 source hashes still match the TASK07 start snapshot.
This document proposes presentation changes for the P1 owner; it authorizes no
change to recording/capture, consent, encoder, audio routing or session state.

| P1 surface | Existing copy / proposed resource | Owner action |
|---|---|---|
| `core/widgets/studio_create_sheet.dart` | Create, Close create menu, Screen recorder, quick-tool labels | Use generated getters at the widget boundary, including tooltips and semantics. Keep callbacks, consent flow and dismiss/handoff contexts. |
| `features/recording/capture_status_presentation.dart` | Ready, Error, Preparing, Starting, Recording, Paused, Allow screen capture | Resolve display text against the current widget locale; retain native state enum values and icon mapping. |
| Screenshot status | Allow screenshot, Saving screenshot, Screenshot saved, Capturing screenshot | Keep screenshot state independent of video recording controls. |
| Countdown | `p1StartingInSeconds(seconds)`, `p1ScreenshotInSeconds(seconds)` | Typed numeric placeholders/ICU, locale-aware display; do not localize native durations or change the3s screenshot countdown. |
| Settings forms | Audio & Video Settings, resolution/FPS/audio/orientation choices, toggles, gain units | Keep stored English tokens and accepted v0/v1/v2 choices. Supply a display-label mapper, as the shared theme ChoiceGroup already supports. |
| Record hero summary | resolution · FPS · audio mode | Localize display labels only. `recordingSnapshot` must continue reading original tokens. |
| Capture controls/errors | Start/Pause/Resume/Stop, consent/cancel/retry, failed-save messages | Localize at presentation boundaries, retaining state guards and native commands. Use dialog/sheet builder contexts during dismissal. |
| Android recording service/overlay | Ongoing notification, countdown, stop/pause, toast/error resources | P1 owns native resource integration. P2's `P2Locale` intentionally changes only editor/preview resources and does not recreate MainActivity or change global application locales. |

Existing generated keys include `create`, `close`, `video`, `photo`, `cancel`,
`settings`, and a stable-message adapter for P2/P3. Add clearly named P1 keys
where meanings differ; do not translate arbitrary user-authored text through
the adapter. Non-English resources remain **TRANSLATION REVIEW PENDING**.

Required P1 verification: active recording/countdown/pause/resume and screenshot
consent while switching locales; no duplicate subscription/session/permission
request; same stored capture snapshot before/after language changes; Android
notifications and accessibility labels in the resolved language;320/411dp,
200% text, Arabic RTL, Light/Dark. P2's automated idle recording fixture and
layout checks are not a substitute for P1's real capture acceptance.

The P1 hero/quick tools can still appear in English inside a localized library.
This is a known ownership boundary, not certification of whole-app translation.
Final P1→P2→P3 recording integration waits for the owner's ready build. P2/P3
implementation and synthetic/real licensed-media verification continue independently.
