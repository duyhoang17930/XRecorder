# Physical-device QA handoff

All cases below are **NOT RUN**. Run after the development prompts are complete; emulator results do not count as physical-device passes.

| ID | Hardware/OEM-only test | Expected behavior | Status |
|---|---|---|---|
| PDH-01 | Record microphone audio with speech and timed cues. | Decoded audio has no unexplained gaps or severe clipping. | NOT RUN |
| PDH-02 | Record internal and mixed audio from allowed real-device sources. | Source selection and Android audio-capture policy are respected. | NOT RUN |
| PDH-03 | Recheck known audio continuity, A/V sync and low video cadence on a real chipset. | Record whether emulator defects reproduce and capture measured results. | NOT RUN |
| PDH-04 | Sustain supported hardware codecs, resolution and FPS. | Output decodes and matches metadata without early thermal or encoder failure. | NOT RUN |
| PDH-05 | Exercise Projection through Home, another app, lock/unlock and rotation under OEM background rules. | OS/OEM interruptions are handled safely; no false Saved state or corrupt media. | NOT RUN |
| PDH-06 | Change wired/Bluetooth audio route, mic privacy and competing microphone use. | Source loss is reported clearly; capture resources and output recover safely. | NOT RUN |
| PDH-07 | Use front/rear physical cameras for Facecam under varied lighting/orientation. | Correct camera, orientation, placement and A/V alignment. | NOT RUN |
| PDH-08 | Toggle camera privacy or contend with another camera app. | Clear failure/recovery; camera and overlay resources are released. | NOT RUN |
| PDH-09 | Use Floating Ball across launcher and other apps on OEM firmware. | Ball remains reachable, draggable and correctly dismissed/stopped. | NOT RUN |
| PDH-10 | Draw and interact through overlays using real touch and rotation. | Touch reaches the intended control; drawing stays aligned in output. | NOT RUN |
| PDH-11 | Change Wi-Fi/cellular network during a QA livestream. | Reconnect/error behavior is clear; credentials remain private. | NOT RUN |
| PDH-12 | Run offline Whisper on ARM CPU/RAM with realistic media. | No OOM/ANR; cancellation and memory pressure recover safely. | NOT RUN |
| PDH-13 | Record continuously while observing battery, temperature and memory. | No unexplained thermal throttling, resource growth or severe cadence loss. | NOT RUN |
| PDH-15 | Test removable SD/SAF only on a device with an OEM provider. | Access changes do not alter or lose source media. | NOT RUN |
| PDH-16 | Test Screenshot consent, background completion and rotation on OEM firmware. | PNG contains the permitted current screen at the correct orientation; interruption creates no false output. | NOT RUN |
