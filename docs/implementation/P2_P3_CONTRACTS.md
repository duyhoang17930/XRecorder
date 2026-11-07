# Ownership & contracts

## P1 immutable boundary

`lib/features/recording/**`, `android/app/src/main/kotlin/com/xrecorder/xrecorder/recording/**`, `lib/features/settings/recording_settings_form.dart`, `audio_video_settings_screen.dart` read-only. `studio_create_sheet.dart` chứa capture UI: không extract/sửa capture semantics. `MainActivity` nếu cần chỉ thêm P2/P3 registrations, giữ capture channel.

Proof tại checkpoint: `git diff --exit-code 5cdda32084be772f61153bc453ef3675b932ab41 -- lib/features/recording android/app/src/main/kotlin/com/xrecorder/xrecorder/recording lib/features/settings/recording_settings_form.dart lib/features/settings/audio_video_settings_screen.dart lib/core/widgets/studio_create_sheet.dart`.

## Contracts hiện có

07/11/2026: P2/P3 activity request codes use1701–1705 (folder/audio/model/SRT/destination).
P1 owns702–706; SupportBridge owns704. Prior selectAudio702/SRT704 collisions
were exposed by real DocumentsUI testing; P1 and Support bridge are unchanged.

| Boundary | Contract thực | Preservation/test |
|---|---|---|
| P1 → P2 saved | `CaptureController(onSaved: media.refresh)` trong app; broadcast native current/event | Không đổi P1 event; controller/widget baseline tests. Native screenshot/capture smoke riêng. |
| P2 → P3 media | `MediaScope`/`CatalogRepository.list/find`, `MediaItem.uri` content URI | Picker dùng cùng repository; không scanner riêng; native persistable read grants. |
| P3 → P2 saved | MediaStore observer + `MediaScope.refresh` trên export/photo completion | Không báo Saved trước commit; background resume check. |
| P2 ↔ settings | `SettingsController`/`SettingsStore` document v2 | Recording fields không đổi semantics; restore trước runApp. |
| P3 preview/export | `EditProject.toJson` → `EditorComposition.build` | Cùng transforms/time; snapshot immutable; additions backward compatible, không rename P1 fields. |
| P3 draft | editor channel list/find/save/delete; AtomicFile | Document version1 hiện tại; extensions có defaults cho old drafts; unsupported/corrupt phải có recovery, không overwrite. |
| P3 export | exportStart/List/Cancel/Retry | queued/running/finalizing/completed/failed/cancelled; finalizing không cho cancel; retry job cũ. |
| P2 media action | `com.xrecorder/media`; content grants, owned checks | SAF copy/read-back hash; move xóa nguồn chỉ sau khi bản đích hoàn tất và có quyền thật. |

## Implemented additive changes

- P3 still-image/flip/subtitles fields chỉ trong editor models; preserve legacy defaults.
- ASR offline dùng whisper.cpp, chỉ tải model khi người dùng chọn Download; không có server/paid API.
- Shortcut route request P2 chỉ Edit/Photo destinations; không khởi động capture từ shortcut mới.
- Không gọi P1 MediaOutput/RecordingMuxer khác contract hiện có; không sửa implementation của chúng.

M3: `TimelineClip` version1 additive `isImage/flipH/flipV` defaults false, copyWith source relink preserves crop/range. P1 RecordingSettings unchanged. Native Media3 1.11.1 imageDurationMs/frameRate + existing effects serve preview/export. EditorOutput publishes valid Transformer MP4 independently of P1 muxer (supports outputs without mandatory audio). Photo output still uses existing `saveImage` PNG contract; original bytes are not overwritten. P2 native describe width/height mean display dimensions after rotation metadata.

Recovery follow-up: draft read/write limit is1048576 **UTF-8 bytes**; oversized payload rejected before AtomicFile.startWrite. Native list includes backup-only bases, delegates rollback to AtomicFile and emits version=-1 sentinel for unreadable entries; Dart counts/reports them while preserving valid drafts. Export async checkpoint catches history-write failures; before publication →Failed, after commit →Saved +warning, no duplicate Retry. Actual journal EACCES and process-kill during encode were tested; physical disk-full/ENOSPC and exact publication-window kill remain unverified.

## Editor additions — 07/11/2026

- `audioTracks`: tối đa8, `{uri,sourceDurationMs,inMs,outMs,offsetMs,volume,fadeInMs,fadeOutMs,voice,noiseReduction}`.
  Source in/out là thời gian file gốc; offset/fade là milliseconds trên output.
  Gain dùng headroom chung khi mix (bao gồm legacy music), voice none/deep/bright/robot;
  noiseReduction chạy RNNoise480-frame48kHz, giữ số samples đầu vào và xử lý từng channel.
- `layers`: tối đa40, text/sticker/drawing; normalized x/y, scale.1–4, rotation±360,
  start/end trên output; drawing points normalized và null ngắt nét, tối đa2048.
- Subtitle text tối đa2000 ký tự/cue, tối đa200 cue sorted/nonoverlap. Styles:
  white/yellow, small/normal/large, dark/none, top/bottom; word wrap/safe-area fit.
  Speed đổi retime cues/layers; trim cuối timeline cắt phần ngoài, Undo giữ bản đầy đủ.
- Preview/export dùng `EditorComposition`; ASR lấy audio-only cùng composition/DSP.
- `decodePhoto`: EXIF applied, sRGB, bounded2048. `saveImage` giữ PNG mặc định;
  additive format png/jpeg, maxEdge480/720/1080/2048, JPEG quality60–100; không overwrite nguồn.
- `exportSrt` mở ACTION_CREATE_DOCUMENT, ghi UTF-8 sau picker consent.
- `exportList` có thể chứa `{type:notice,message}` khi giữ bản recovery của history lỗi;
  notice không phải export job và không có Retry/Cancel.

## Offline transcription contract

Engine whisper.cpp v1.9.5, JNI Android CPU armv7/arm64/x86_64. Model store nằm trong
app no-backup directory. tiny/base/small-q5_1 multilingual được kiểm kích thước và SHA256
trước publish. Weights không bundle APK. Download/import có progress/cancel; file đang cài
không thay thế model hợp lệ trước khi checksum qua.

- `transcriptionModels`, `transcriptionAvailability`: installed/verified metadata và onDevice/notConfigured.
- `transcriptionStart`: `{operationId,audioUri,durationMs,language,model,project?}`;
  language vi/en/auto, <=10 phút. Khi có project, render edited audio riêng rồi mono16k decode.
- `transcriptionPoll`: `{id,type,projectId,createdAt,state,phase,progress,segments,error,elapsedMs}`.
  State queued/running/completed/failed/cancelled, progress0–1; timestamp milliseconds.
  Engine callbacks cập nhật progress và abort; không transcript giả hay audio upload.
- `transcriptionDownloadModel` / `transcriptionImportModel`: trả job ID; dùng cùng Poll/Cancel.
- `transcriptionDeleteModel`: chỉ xóa model private được người dùng chọn; từ chối nếu model
  đang dùng bởi job, hoặc đang xóa. Không gọi trong cleanup/tests với model đã tồn tại.
- `transcriptionJobs`: checkpoint jobs, matching projectId để mở lại UI; process restart đổi
  unfinished thành Failed/interrupted, giữ kết quả hoàn thành và draft/media.
- `transcriptionCancel`: hủy Transformer/decoder và native abort; không áp dụng kết quả muộn.
- RAM preflight trước decode; tiny/base/small reserve192/320/640MiB cộng PCM buffers.
  Digital silence trả completed/empty segments, không gọi engine để tạo hallucinated cues.

`audioInfo` chạy trên editor worker, ngoài nhánh export-only; URI content có grant thật,
duration lấy bằng MediaMetadataRetriever. Native DocumentsUI regression kiểm tra4000ms.
`releaseFolder` chỉ bỏ grant/pref của tree được chọn, không xóa file. Transfer từ destination
đã disconnect phải fail trước khi copy/move. Preview giữ playhead khi cập nhật effects,
retime theo speed và bỏ kết quả load cũ bằng generation guard.

Real tiny/base/small multilingual, edited-audio→ASR→SRT/burn-in và model download trên AVD
đã chạy. Physical thermal/battery, rộng corpus và final P1→P2→P3 là gate riêng.
