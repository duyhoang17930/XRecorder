# Quality results

Audio continuity: **PARTIAL**. Deterministic accepted-tail loss repaired and tested. Historical recurring FIFO saturation and strict waveform seam remain unresolved pending comparable runtime evidence. No waveform threshold changed.

Video continuity: **PARTIAL**. No production video change; historical stale-source observation remains open. Encoded frame count and packet parity do not establish freshness.

A/V synchronization: **PARTIAL**. Accepted sample counter still defines AAC PTS; terminal block uses its actual size. Historical mic/internal timestamp origins differ. No clock-correction or mixer compensation claimed.

Queue/performance: capacity remains192blocks/384KiB; telemetry is constant-space. New codec-duration maxima separate calls from source reads. Source/encoded FPS, long-run drift, memory retention, CPU pressure, codec start/stop latency and five-minute stress not yet accepted. Current SwiftShader runtime differs from previous hardware renderer; do not infer physical or low-end performance.

Local/network parity: prior audio14 packet/pixel parity remains historical. Current capture outputs require full FFmpeg decode, exact packet ordering/hash comparison, cue analysis and unchanged strict waveform validation. No runtime PASS based on successful build, file size or UI.

Current runtime evidence is appended below when available.

## Short current outputs

| Run | Conditions | Actual quality |
| --- | --- | --- |
| stab4 / URI48 | Profile, SwiftShader, VideoView source47, micGain0/internal1 | Both full decodes PASS; every received packet matches a contiguous local packet range;6sampled RGB frames exact;2new cue samples correct. Strict waveform FAIL, initial5s correlation .04576. FIFO peak44, maxread1717ms, maxwrite1454ms. |
| stab_gpu1 / URI49 | Same profile/source/settings, NVIDIA host GPU | Both full decodes PASS; original strict waveform PASS, first5s .999965 and fixed windows .999977/.999949/.999922; sampled packet/pixel/cue parity PASS. FIFO peak11, maxread116ms, maxwrite79ms. A bounded positive result, not universal capture acceptance. |
| stab_motion2 | Host GPU, explicitly looping static PCM, cold view/activity transition | Both full decodes PASS.152frames/51masked IDs pass freshness diagnostic. Fixed-offset audio FAIL at initial windows, interior2–5s >.9997. PSS sampled maximum185527KiB, FIFO peak32. Short qualification exposes residual transition discontinuity. |

Evidence: parent `live_audio_<attempt>_result.json`, `live_audio_<attempt>_media/validation.json`, original `live_audio_stab4_output_validation.json` and `live_audio_stab_gpu1_output_validation.json`, local `stab_motion2_loop_motion_speech_anchor.json`, and `runtime_summary.json`. Missing entries in runtime_summary are not PASS. Received streams may start after encoder initialization; contiguous packet parity is scoped to received packets, not a claim that no startup packets were omitted.

Final native count161PASS/0failures/errors/skips after adding terminal-full-queue failure coverage; `native_final.txt` and `native_final_counts.json`. Flutter553PASS, analyzer clean, Python19PASS remain the executed final product-host gates; subsequent edits are test-only fixture/validator/report changes.

## Five-minute baseline: PARTIAL, quality gates still FAIL

`stab_stress1`, profile candidate, NVIDIA host GPU, same SHA-pinned PCM source looping;1s warmup separates source start from activity setup. Continuous monotonic binary/color marker displayed. Active session305960ms, URI52; full local and received decode PASS. Received2745video/14307AAC packets match contiguous local ranges exactly. Pre-connection local prefix3video/22AAC packets and0missing tail are disclosed. Relative A/V timestamp rebasing difference .082ms is transport parity, not source synchronization acceptance.

Peak FIFO22/192; maximum sampled queued6; max read343.902ms, max queueInput342.358ms, max dequeueOutput126.248ms, max output write160.426ms. PSS first183478KiB/last196740KiB/max197315KiB; this bounded observation does not prove absence of leaks. App CPU delta216057ms over approximately300s observation, excluding work in platform codecs/audioserver/host. No crash/ANR or queue saturation observed. Effective received cadence approximately9fps, not30fps acceptance. No physical-device or low-end performance inference.

Fixed-offset waveform FAIL. Interior2–78s windows are high correlation, but source79s shifts roughly-137.542ms; later source240/299s align near-116.208ms. Realignment recovers >.9999 in representative later windows; this is diagnosis only and does not replace the failing constant-offset gate. Internal AudioTimestamp origin changes approximately128ms around capture82.7s, coincident with read/queueInput maxima rising to344/342ms. Between first/last timestamp observations the source/read deltas are14388224/14387200frames; source-minus-read remains2048..4096frames. This shows no accumulating client FIFO gap, but cannot exclude pre-read platform loss. The live waveform matches local degradation; RTMP packet transport did not introduce it.

Visual diagnostic:2694checked frames/2611unique IDs.4early ID mismatches retained; later accepted IDs have median age55.94ms/max348.51ms. Early source-present readiness was not recorded, so do not relabel those mismatches as an encoder fix or certified frame-zero result. The final short diagnostic measures source draws48.91Hz vs network video9.44fps. Exact source presentation → projection → encoder bottleneck still needs further instrumentation/physical comparison.

Evidence: `stress1_decode.txt`, `stab_stress1_packet_parity.json`, `stab_stress1_loop_motion_speech_anchor.json`, `stab_stress1_loop_motion_drift.json`, `stress_source_clock_steps.json`, `stress_mid_sample.json`, parent `live_audio_stab_stress1_result.json` and final source diagnostic. No thresholds relaxed. No additional long run justified while the source-clock/cadence failure remains unresolved.
