# 3HRecorder — physical-device QA handoff

**Status:** All cases NOT RUN. The owner has no physical Android device available for this development phase. Run after the prompts are complete; record device model, Android/API, APK SHA and direct evidence. Emulator results do not count as hardware PASS.

| ID | What must be tested | Expected behavior | Status |
|---|---|---|---|
| PDH-07 | Real front/back cameras: focus, exposure, optical orientation and mirroring | Preview and MP4 are upright and correctly mirrored; usable focus/exposure; camera frames stay fresh. | NOT RUN |
| PDH-08 | Camera privacy toggle, permission revoke/regrant and another app competing for camera | Facecam availability is truthful; resources release/retry safely; screen recording continues when possible. | NOT RUN |
| PDH-05 | Device cutouts, rounded corners, edge touch and rotating while Facecam/Drawing are active | Controls remain reachable; camera placement and drawing coordinates stay correct; no trapped underlying touches. | NOT RUN |
| PDH-04 | OEM overlay/background restrictions over Home and another app | Floating controls remain usable when permitted; background and Stop behavior follow OEM policy without stale sessions. | NOT RUN |
| PDH-13 | Sustained Facecam + Drawing + screen recording, hardware audio/video, thermal and resource use | No reproducible crash/ANR or uncontrolled heat/resource growth; output finalizes with usable synchronized audio/video. | NOT RUN |
| PDH-16 | Floating Ball visible and interactive while absent from saved MP4 | Ball/menu are absent from decoded pixels, with the changing content behind them preserved and no black hole. This remains a release-blocking requirement. | NOT RUN |
| PDH-18 | Recording footer and key screens at enlarged text, accessibility settings and localized UI | Footer/panels do not cover or clip controls; TalkBack labels and touch targets permit the core flow. | NOT RUN |
| PDH-19 | Screenshot flow on an OEM build and device display | One consented PNG per action with correct source pixels/orientation; no duplicate or overlay-dependent corruption. | NOT RUN |

