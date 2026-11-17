# Prompt 09B — Export integration test matrix

**Environment:** `emulator-5554`, Pixel_7 AVD, Android 17 / API 37 / x86_64. Package remained `com.xrecorder.xrecorder`. Installed artifact was the x86_64 profile APK because debug APK installation did not fit the AVD's remaining `/data` space.

## Android focused cases

| Case | Status | Evidence / limits |
|---|---|---|
| E01 — Open existing saved export-capable project | PASS | Read the existing 09A project `project_1794820476111724` and its saved source, audio track and two edited subtitle cues. The production project file remained byte-identical. |
| E02 — Submit export and verify queue/progress | PASS | Real production queue jobs advanced through queued/running/finalizing/completed. The active job progress samples remained below 100 until its completion callback. |
| E03 — Queue multiple jobs safely | PASS | Submitted an active job and a second queued job; queued job stayed cancellable. Subsequent exports ran serially through the single active Transformer. |
| E04 — Cancel queued job | PASS | Cancelled before execution; terminal state was `cancelled`, with no output URI or publication. |
| E05 — Cancel running job | PARTIAL | Requested cancellation during a running 22-second controlled encode. It did not expose a successful URI; retry of the same ID completed and published one row. Immediate native codec/resource release was not measured. |
| E06 — Controlled failure and retry | PARTIAL | Nonexistent MediaStore source propagated an `Asset loader error`, left no output, and remained failed on retry. Running-cancel retry succeeded. Revoked SAF access, unsupported codec, real publication failure, low-storage UI and process death were not run. |
| E07 — Multi-clip MP4 | PARTIAL | Exported split/reordered second-half-then-first-half project; H.264 320×180, 11.000 s, 264 decoder buffers / 22,809,600 decoded bytes, MediaCodec EOS. Frame-to-source order was requested but not independently compared. |
| E08 — Transform and speed MP4 | PARTIAL | Crop 0.1–0.9, rotation 90°, horizontal flip and speed 1.25 exported; H.264 256×180, 8.800 s, 264 buffers / 18,247,680 decoded bytes, EOS. Crop dimensions and speed duration changed as expected. Rotation/flip pixels were not independently checked. |
| E09 — Mixed-audio MP4 | PARTIAL | Output AAC decoded to EOS (11.036 s, 173 buffers, 353,152 PCM bytes at 16 kHz mono) alongside 11.000 s video. Added 1-second WAV requested at 3,500 ms had maximum normalized correlation 0.771 at about 14 ms from its requested offset. Source-video audio and added audio were not isolated; no full-duration drift test. |
| E10 — Saved subtitle project SRT and burn-in | PARTIAL | Project cues were loaded and passed into the composition without Whisper rerun. Pixel-level burn-in, edited text/timestamps in newly exported SRT, and trim/split/reorder/speed cue mapping were not independently verified in this run. Prompt08's prior SRT/burn-in evidence is historical, not a current Prompt09B PASS. |
| E11 — GIF | PASS | Current output was GIF89a, 160×90, 11,000 ms, 900,986 bytes. Android `Movie` decoded the animation and found multiple distinct sampled frames. MediaStore row had `image/gif`, app ownership and pending=0. |
| E12 — Publication, Library, preservation and errors | PARTIAL | Five new MP4 and two GIF rows across focused runs had app ownership, expected MIME, nonzero sizes and pending=0; no duplicate retry row or cancelled partial row. Library-screen visibility and true provider publication failure were not UI-tested. Source/project/model/preferences/grants were rechecked and preserved. |

## Real output identities

| Type | MediaStore URI | Name | Bytes | Elapsed | Independent validation |
|---|---|---|---:|---:|---|
| Multi-clip/audio MP4 | `content://media/external/video/media/709` | `Edited_143b8681-1bc0-4351-8e88-ead7e69c4df5.mp4` | 577,156 | 9,135 ms | `video/avc` 320×180, 11.000 s / 264 buffers to EOS; `audio/mp4a-latm` 11.036 s / 173 buffers to EOS; SHA-256 `5dc7ed1386b2c4413fd8d59bb432f12564e425c8d9030914d20bb4fb5cc0336b`. |
| Crop/rotate/flip/speed MP4 | `content://media/external/video/media/710` | `Edited_8e93838f-6233-4828-8714-4110de271cbc.mp4` | 564,204 | 6,845 ms | `video/avc` 256×180, 8.800 s / 264 buffers to EOS; AAC 8.860 s / 139 buffers to EOS; SHA-256 `2424e0a980e36b49c47af46a4c7ba41191fee5a375dabef0b62b93354e2b2bbe`. |
| GIF | `content://media/external/images/media/711` | `Edited_85cf076c-026c-448b-bf4c-511df55e5f18.gif` | 900,986 | 18,432 ms | GIF89a, 160×90, 11,000 ms, multi-frame Android decode; SHA-256 `bc49ea9c52794026d01df809ad9f19e3efab1b160291220f26786857c099a25c`. |
| Same-ID cancel retry MP4 | `content://media/external/video/media/712` | `Edited_5686423a-e111-4730-9f5c-01339c12aa1e.mp4` | 975,540 | 15,411 ms | `video/avc` 854×480, 22.000 s / 528 buffers to EOS; AAC 22.044 s / 345 buffers to EOS; one MediaStore row; SHA-256 `d664dd6eef2ba6bf4aa6fd2e9185c6727d88e9ffea570158f64532d9582a0145`. |
| Retry of original cache-purge failure | `content://media/external/video/media/713` | `Edited_6676b83d-39b9-4ed0-9b33-35a2fa88c1cd.mp4` | 975,540 | 17,787 ms | Previously failed job became completed under the same ID after the temp-path fix; H.264 854×480, 22.000 s / 528 buffers to EOS; AAC 22.044 s / 345 buffers to EOS; exactly one named row; SHA-256 `d5c4d89c6f78a8f15bab5cbb60c02a7a533f5140b7dc8d4c26f7860790df0425`. |

The prior exploratory run also produced two MP4s and one GIF, all fully decoded/animation-checked. Its retry exposed the cache-purge defect described in the audit; that original failed job has now been retried after the fix. Prompt09B total: **six distinct MP4 outputs fully decoded and two GIF outputs validated**. No output overwrote an existing item.

## Host, build and install checks

| Check | Result |
|---|---|
| Kotlin/JVM `EditorStorageTest`, `TimelineAudioLimitTest`, `SubtitleTextTest` | PASS — 6/6 |
| `Task09BExportHistoryInstrumentation` | PASS — 11/11 journal, publication-recovery and write-fault assertions |
| `Task09BExportIntegrationInstrumentation` | PASS — 5/5 cases in the successful post-fix run |
| `flutter test` / `flutter analyze` | NOT RUN — Flutter CLI/version invocation remained hung for over two minutes; existing Dart processes were not killed. |
| Debug build | `assembleDebug` and `assembleDebugAndroidTest` succeeded. Universal APK was 180,957,550 bytes; x86_64 debug split was 87,666,502 bytes. Both install attempts failed with `INSTALL_FAILED_INSUFFICIENT_STORAGE`; no app data was cleared. |
| Profile build/install | PASS — `assembleProfile --target-platform=android-x64 -Psplit-per-abi=true`; `adb install -r` succeeded in place and preserved data. Pulled installed base APK SHA-256 equals `A495BD41830A12F04290C4A05A29C7FEDD1AB9BCA245A1FA4D888E90540B25E6`. |
| Release build | NOT RUN successfully — online dependency resolution completed, but release compilation fails because the generated plugin registrant references dev-only `integration_test`. No production dependency was changed to work around it. |
| `git diff --check` | PASS |

## Preservation and storage

- All 12 existing project baseline SHA-256 values from Prompt09A match; project directory still contains 14 JSONs (the 12 originals and two earlier task-owned projects). The exported target draft SHA remains `92a317b5ea6b8410dcba48e78f02bac7cd82baf3da256ffca907f8294d3d1c7e`.
- Selected source video SHA stayed `99226db5e4dab095797869a36faab9626e92fd111fa086363729af266b4c6a0d`; added WAV SHA stayed `20c64d20421cb40bbe14241596f3cc171e915560a4687bb0b4d694792d68c5bd`.
- Tiny model SHA stayed `be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21`; all seven checked preferences and the full persisted SAF grant snapshot matched preflight.
- MediaStore counts increased only by this prompt's outputs: videos 25→31 and images 341→343. New outputs were finalized (`is_pending=0`); no pending video/image row remained. No existing row was deleted.
- Free `/data` before the first bounded export was 384,778,240 bytes; after all Prompt09B outputs, including retry, it was 374,603,776 bytes (365,824 KiB; about 9.7 MiB consumed). The core integration run ended at 377,208,832 bytes; the later failed-job retry consumed about 2.4 MiB. Each real queue submission passed storage preflight; no low-space exhaustion was induced.

## Gate summary

| Gate | Status | Note |
|---|---|---|
| G01 Queue state consistency | PASS | Stable ID, serial dispatch, queue persistence/progress observed. |
| G02 Queued cancellation | PASS | Cancelled before start, no output. |
| G03 Running cancellation semantics | PARTIAL | No publication and same-ID retry passed; native teardown timing not measured. |
| G04 Failure/retry | PASS | Original cache-purge failed job recovered after the fix with same-ID retry and one valid row; missing source continues to fail truthfully without output. |
| G05 Multi-clip edit order | PARTIAL | Full decode and plan creation pass; output frame order not independently compared. |
| G06 Transform/speed mapping | PARTIAL | Crop and duration evidence pass; rotation/flip pixels not inspected. |
| G07 Audio mix/timing | PARTIAL | AAC decode and offset correlation pass; signal isolation/drift not established. |
| G08 Existing subtitle cue export | PARTIAL | Saved cues loaded; fresh SRT values/pixels not independently validated. |
| G09 Subtitle burn-in after edits | PARTIAL | Composition path exercised; pixel/time mapping not inspected, especially speed mapping. |
| G10 GIF validity | PASS | Signature, dimensions, duration and changing animation decode pass. |
| G11 MediaStore publication | PASS | New URI, owner, MIME, name, size and pending=0 verified. |
| G12 No broken completed/cancelled media | PASS | Cancel/failure gave no completed URI/row; retries created one valid row. |
| G13 Source/project preservation | PASS | Baseline hashes, target draft, model, settings and grants preserved. |
| G14 UI/progress/error states | PARTIAL | Queue/status source reviewed; no Flutter UI runtime exercise. |
| G15 No severe export regression | PASS | Current production queue outputs decoded; image path unchanged and historical Prompt07A retained. |
