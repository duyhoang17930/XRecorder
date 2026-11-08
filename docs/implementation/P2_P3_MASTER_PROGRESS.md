# P2/P3 implementation progress

Updated 08/11/2026. TASK07 current delivery/evidence:
[TASK07 final report](TASK_07_FINAL_REPORT_VI.md),
[globalization matrix](TASK_07_GLOBALIZATION_MATRIX.md),
[executed checks](TASK_07_TEST_EVIDENCE.md).
G0–G5 implemented/verified; G6 native regression/main APK/native accessibility verified.
Same-corpus performance gate remains OPEN; human/physical/P1 integration gates
remain separate. The quality table below is the prior07/11 checkpoint, not a
PASS assertion for every TASK07 source change.

Prior quality-task baseline:
`b9aea926c1ab024dd32a139e5ab43b0e0e584908`, main. No commit/push in this task.
[Final quality report](P2_P3_FINAL_QUALITY_REPORT_VI.md) owns delivery verdict;
[TEST_EVIDENCE](P2_P3_TEST_EVIDENCE.md) indexes executed checks.

M0-M6 implementation from the previous task remains in place. Independent P2/P3
backends are implemented; physical/HCI/full P1 integration acceptance stays OPEN.

| Quality gate | Current result |
|---|---|
| A Library | 3 before/3 after profile trials, same1009-image corpus. Median trial raster p95 43.711 to40.515ms; software-GPU jank remains. Cache unchanged. |
| B UX | Black preview fixed with SurfaceView hybrid fallback; portrait sizing/crop/rotation and stale-state guards. 320/411dp/theme/text200 native matrix PASS; human sessions NOT RUN. |
| C AI | 38 real jobs/35 inferences across12 stimuli; Base default. Queue-poison fix, real native timing, restore model/language. Cancel worker drain+next decode9616 to518ms; all3 models regression PASS. |
| D Media | 12 audio/layer outputs full decode/signals PASS; actual preview/export mask parity PASS. EXIF1-8/display metadata, ICC/JPEG/mixed/speed subtitles PASS. Six input cases plus H264/HEVC outputs PASS. MP4/GIF queue regression PASS. |
| E Safety | Published-URI finalizing-checkpoint replay after real process stop PASS; same URI/no duplicate/source/draft preserved. Current real SAF/download/SRT/disconnect and corrupt-draft/trash-restore reruns PASS. |
| F Lifecycle/device |30 previews/20 export-cancel after pause+stop cleanup PASS, releaseFailures0; median/max dispose489.5/741ms. API34 native/media/JNI + steady preview PASS; both main.dart APK packaging/16KiB/signature checks PASS. |

Final host checkpoint: analyze clean3.7s,143 tests PASS26s,3 native JUnit PASS23s; no skip. API34 added6 Tiny/Base multilingual jobs; cancel drain+next decode515ms.

16 protected P1 files retain exact baseline SHA256. This is source-integrity
proof, not capture runtime signoff. No media/draft/model/reference deletion.
Cleanup removed the stale generated HTML/report generator and consolidated evidence;
the five required quality reports remain; raw evidence stays ignored under build/verification/final_p2_p3.
