# Prompt 09B — Export pipeline audit

**Date:** 2026-11-16  
**Workspace:** `D:\FAU_App\XRecorder`  
**Device:** Pixel_7 AVD, `emulator-5554`, Android 17 / API 37 / x86_64  
**Result:** One reproducible temp-file loss defect was fixed. The existing Media3 export engine and project model remain in use.

## Existing architecture

| Area | Current implementation and reachability | Audit result |
|---|---|---|
| Queue and job history | Native `ExportQueue` is the editor method-channel backend. It assigns UUID job IDs, stores snapshots in `AtomicFile(files/export_jobs.json)`, limits active/queued work to ten, selects the first queued row, and runs one Media3 `Transformer` at a time. | Implemented and reachable. One active job; remaining jobs wait in insertion order. The Export screen polls while foreground/current, refreshes on resume/route return, and suppresses duplicate commands per job ID. |
| MP4 composition | `EditorComposition` builds one Media3 composition from project clips. It maps clip trim bounds, clip ordering, image duration, crop, rotate, flip, aspect/height, frame rate, speed, video effects, timed overlays, source audio, and separately mixed audio sequences. H.264/AAC output is published through `EditorOutput`/`MediaOutput`. | Implemented. Only selected combinations were exercised in this prompt; individual visual transforms and every effect are not all independently verified. |
| GIF | The same composition is encoded to a temporary MP4, then `GifWriter` samples it and writes the requested animation. Supported policy is up to 15 seconds, 5/10/20 fps, 160/320/480-pixel edge and 0–20 repeats. | Implemented and reachable. One current short GIF was decoded in this prompt. |
| Audio | `EditorAudio` and the composition mixer support project source audio, up to eight added tracks, optional music, track trim/offset/gain/fades, global volume/pitch and bounded output duration. | Implemented; a short offset added-track mix was exercised. Independent separation of both source signals and drift measurement remain incomplete. |
| Subtitles | Saved project cues and styles are passed to `SubtitleOverlay` during composition; SRT export is a separate Flutter-to-native SAF document flow (`MediaCatalog.exportSrt`). | Burn-in path is implemented and reachable. Prompt09B output pixels and saved-project SRT were not independently inspected in this run. Prompt08’s earlier real SRT and burn-in evidence remains historical only. |
| Photos | Photo Editor PNG/JPEG publication is a separate path from the native video queue. | Not affected by this prompt’s only production change (video temp directory); historical Prompt07A PNG/JPEG PASS retained, not rerun. |
| Publication | `MediaOutput` creates a pending MediaStore row, copies/writes the completed payload, and clears pending only at commit. Abort deletes its task-owned pending row. | Current MP4/GIF output rows were app-owned with expected MIME/name, nonzero size and `is_pending=0`. No invalid or cancelled output was left pending. A real MediaStore provider failure was not induced. |
| Progress and controls | The queue holds progress per job. The Flutter Export screen displays queue/running/finalizing/terminal states, error, retry/cancel and open-saved-media actions. `list()` caps Media3's early 100% report to 99 until completion. | Code path inspected and native progress transitions observed. This prompt did not exercise the Flutter screen UI itself. |

## Lifecycle and recovery

The queue persists before starting work. `queued` jobs are selected serially; `running` advances to `finalizing`, then `completed` only after MediaStore commit. Encoder/publication exceptions become `failed`; cancellation becomes `cancelled`. A failed/cancelled job can be retried under the same job ID and output name. The successful same-ID retry in the integration test published exactly one row.

On queue construction after process interruption, stale `running`, `queued` and `finalizing` records are examined. A task-owned pending MediaStore row is removed; a non-pending row with a nonempty descriptor may be restored as completed; otherwise the job is marked failed with a retry message. The stale temp is deleted. This recovery trusts nonzero file size for a previously published row; it does not fully decode it during startup. Interrupted work is not advertised as background-safe. The Export screen tells users to keep the app open, and there is no foreground export service.

Queued cancellation was verified before dispatch. Running cancellation was requested against an active native encode; no URI was reported and a retry completed. The test does not establish immediate codec teardown or measure when every native resource is released: Media3 cancellation can finish asynchronously, while the queue records the requested terminal state immediately.

The existing process-death instrumentation was not run. Its prerequisite checks a retained QA SAF tree, but the current `media_transfer.json` points to `primary:Alarms`, not the required `primary:Documents/Task09B_SAF_QA_20261109_f64203`; no SAF grant was created, removed or changed to satisfy that unrelated prerequisite. Journal recovery/fault scenarios were exercised by the history instrumentation instead.

## Reproduced defect and focused change

**Reproduction:** During the first real integration attempt, Android `installd` purged the active `cache/export_<job>.mp4` while Media3 was encoding. Completion then failed the nonempty-temp precondition with the unhelpful message `Failed requirement.`. The queue retained a failed job and no successful MediaStore output. Other short exports and queued cancellation still worked.

**Root cause:** The encoder's in-progress output lived in Android's purgeable cache directory. This is not a safe location for a long-running export, including while the process is background/cached.

**Change:** `ExportQueue.temporary()` now places each job's work file in app-private `files/export_work/export_<id>.mp4`, creating/checking that directory and returning a clear `IOException` if it is unavailable. Existing queue recovery and cleanup call the same path helper. Storage preflight remains on the same `/data` volume. Integration instrumentation asserts an active temp is in `files/export_work`, not `cache`.

**Regression evidence:** After rebuilding/installing the profile x86_64 APK, the integration suite passed and produced six fully MediaCodec-decoded MP4 outputs across bounded runs. I retried the original failed task-owned job `6676b83d-39b9-4ed0-9b33-35a2fa88c1cd` after the fix: its prior `Failed requirement.` state became completed, it reached decoder EOS, and exactly one row was published under the same ID/name. Running-cancel same-ID retry also completed. This is evidence for the corrected current path; it is not a process-kill or long-background stress test.

## Known limitations

- No actual process-death/restart export was run in Prompt09B; recovery logic is source-audited and synthetic journal recovery is covered by the history instrumentation.
- Media3 rotation/flip pixels, clip-order pixels, subtitle burn-in pixels, and exact source-to-output cue mapping were not independently decoded/inspected. Track dimensions/duration alone do not prove them.
- Global-speed subtitle cues remain project-time values. The current composition validates cue end against speed-adjusted output duration and applies a global cue overlay offset; untouched cues that extend beyond the shortened output can be rejected. Complex trim/split/reorder/speed cue mapping is not established.
- Audio output was fully decoded and the added 1-second WAV was correlated near its requested offset, but both sources were not isolated and A/V drift was not measured across the full program.
- Background export, thermal behavior, OEM codecs and long exports remain physical-device work; the AVD had limited storage and only short jobs were used.
