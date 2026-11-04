# Phase 6 — Capture tools

Implemented:

- A separate OS-consented screenshot session with a three-second delay, ImageReader capture, pending PNG output and catalog refresh only after commit. Recording and screenshot sessions cannot overlap.
- Full-screen capture followed by normalized image cropping. The photo tools screen explicitly labels this fallback; it is not live region recording.
- Pen, rectangle, circle, color, stroke eraser and undo/redo. Marks are burned into a newly rendered PNG. Source remains intact. Working width is capped at 2048 pixels; native input has size/dimension limits.
- Optional front-camera TextureView overlay during recording. Camera and overlay grants are requested only when enabled, camera foreground-service type is declared, and camera/window resources are released on completion/failure. Devices without a front camera fail preflight clearly. Full-display capture includes the overlay.
- Android Show taps guidance, without cross-app touch observation or simulated global indicators.

Validation on 2026-11-04, Android 16/API 36 emulator:

- Screenshot integration passed; screenshot pixels were inspected. Extended test saved a cropped annotated copy (MediaStore IDs 46 and 47) and verified source dimensions unchanged. Initial image metadata omission was fixed and test rerun successfully.
- Facecam integration passed after configuring an emulated front camera. Overlay, camera and projection permission screens were exercised. A frame extracted from the saved MP4 visibly contains the emulated camera image. Full video decode completed without errors (MediaStore ID 43).
- Analyzer clean; 14 host tests passed, including annotation pixel rendering/source preservation; Android debug builds succeeded.
- Ignored evidence: `build/verification/phase6-screenshot.png`, `phase6-cropped-annotated.png`, `phase6-facecam.mp4`, `phase6-facecam.png`.

Limitations / outstanding checks: annotation currently edits still images after capture, not live drawing over other apps. Video region cropping belongs to editor/export. Facecam uses a fixed top-right position and needs physical front-camera rotation, camera-busy, denied permission, background/lock and long-session testing. Emulator tests do not establish all-device compositing behavior.

Platform reference: [foreground service camera requirements](https://developer.android.com/develop/background-work/services/fgs/service-types).
