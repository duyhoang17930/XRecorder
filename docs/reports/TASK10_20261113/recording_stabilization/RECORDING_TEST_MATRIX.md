# Current recording matrix

Historical passes remain in parent TASK10 reports and are not promoted to current acceptance. Device: Pixel_7/emulator-5554/API37/x86_64/16KB. Current session: 3GiB, headless SwiftShader. Profile APK identity: `candidate_install.json`; source tree contains this continuation's uncommitted changes. No physical device run.

| Case | Input / expected | Current status / evidence |
| --- | --- | --- |
| T01 | 30s mute; changing frames/full decode | NOT RUN on candidate |
| T02 | 60s controlled internal; waveform continuity | NOT RUN; short Mixed with micGain0 attempted first |
| T03 | 60s microphone; track/timing | NOT RUN; physical acoustic quality DEVICE-ONLY |
| T04 | 60s mixed; independent source alignment | NOT RUN; shorter diagnostic excludes microphone contribution |
| T05 | repeated pause/resume; active timeline | NOT RUN; existing reader pause regression passes |
| T06 | continuous-motion source; cues/source/encoded agreement | PARTIAL investigation; original player retained; runtime results recorded separately |
| T07 | representative supported codec/FPS/size tuples | NOT RUN; existing capability contracts retained |
| T08 | Home/other app/return/Stop | NOT RUN on candidate |
| T09 | rotation/size changes and legal consent | NOT RUN on candidate |
| T10 | task-owned interrupted finalized input; retained recovery | NOT RUN; historical recovery inputs absent from current AVD state; do not fabricate preservation |
| T11 | local and received RTMP independent decode/parity | Short runtime diagnostic in progress; see runtime follow-up |
| T12 | 5min controlled baseline, bounded FIFO/memory | NOT RUN; short reproduction must qualify first |

Executed host gates: analyzer clean; Flutter553PASS; native160tests/28suites/0failure-error-skip; Python19PASS. Native QA APK compiles; profile build succeeds. Raw evidence: flutter_analyze.txt, flutter_full.txt, native_full.txt, native_counts.json, python_tests.txt, profile_build.txt and qa_seed_build2.txt. These do not certify G1/G2/G5/G6.

Setup failures retained in parent `live_audio_stab3_result.json` and local `stab1_host.txt`, `stab2_host.txt`, `stab3_host.txt`: missing URI115, legacy preference-document mismatch and shell-owned source read denial respectively. All occurred before recording; no product quality verdict inferred.

## Final checkpoint (supersedes in-progress rows above)

- T06 PARTIAL: `stab_motion2` changing source152checked frames; `stab_stress1`2694checked frames/2611unique IDs,4early source-readiness mismatches retained. Source-present readiness was not measured in that stress run, so these4frames cannot be attributed conclusively to projection/encoder freeze. A final15s source diagnostic records first/last draw timestamps and source/network cadence.
- T11 PARTIAL: `stab_stress1` local/received full decode PASS.2745received video and14307received AAC packets all match unique contiguous local ranges, no missing tail; local pre-connection prefix3video/22audio packets explicitly reported. Relative timestamp rebasing difference .082ms. End-to-end audio quality FAIL remains.
- T12 PARTIAL: one5minute controlled source baseline completed; active capture305960ms, URI52. No192block saturation/crash observed; peak FIFO22, sampled queued6, PSS183478→196740KiB/max197315KiB. Cadence about9fps at nominal30fps. Fixed-offset audio fails at startup and after source79s; no second long run attempted.
- T02/T04 remain PARTIAL/NOT RUN for their full distinct requirements: the longer baseline controls internal contribution with microphone acquisition active but gain0. It is not a microphone acoustic/default-Mixed acceptance test. T01/T03/T05/T07–T10 are not newly executed; PhaseC full controls audit remains deferred while G1 fails.
- Final source diagnostic `stab_source_diag`: workflow PASS, source draw rate48.91Hz vs sent video9.44fps, source AudioTrack underrun counter0 and timestamps available. Drawing callbacks do not by themselves prove physical display presentation. Projection/input-surface/encoder cadence separation remains open.
- Final host tests:553Flutter,161native,19Python PASS; analyzer clean. Runtime waveform/loop quality validators FAIL, so overall automated acceptance is FAIL despite host passes. Diff check and Python syntax checks pass. Test-only source-counter APK compiles (`qa_source_counters_build.txt`).
- Current monitored preservation PASS:13original monitored files match including8drafts and exact session-entry settings; changed capture journal/install marker excluded explicitly. Full historical Tiny/recovery-state gate UNVERIFIED/FAIL. See `final_preservation.json`.
