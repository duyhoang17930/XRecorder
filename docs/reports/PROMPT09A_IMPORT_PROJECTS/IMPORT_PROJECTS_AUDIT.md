# Prompt 09A — Import and project persistence audit

**Date:** 2026-11-16

**Workspace:** `D:\FAU_App\XRecorder`

**Device:** Pixel_7 AVD, `emulator-5554`, Android 17 / API 37 / x86_64

**Result:** No product-source defect was reproduced; no Dart, Kotlin, or native source was changed.

## Scope and sources reviewed

Reviewed the repository instructions and local routing notes, the relevant TASK10 feature matrix/bug register entries, the Prompt05/05A Media Library handoff, Prompt06+07A Android QA update, Prompt08 subtitle handoff, and physical-device QA handoff. Source review covered the media repository and picker, MediaStore/SAF catalog, editor source selection and relink flow, audio-track picker, project model/controller/repository, native editor bridge/storage, and focused Flutter/native tests.

## Current source architecture

| Source | Identity and access | Persistence and limits |
|---|---|---|
| MediaStore video/photo | `content://media/...` URI; queried with `ContentResolver`. Library selection resolves metadata through the URI, not by treating it as a filesystem path. The app library lists app-owned rows. | Projects store the URI string. Details include display name, MIME type, size and available duration/dimensions/rotation or EXIF orientation. Thumbnail decoding is bounded. |
| SAF document | `content://.../document/...` returned by `ACTION_OPEN_DOCUMENT`. Audio import uses `audio/*`; selected audio stays a content URI in the track. | A persistable read grant is taken where offered. Metadata and duration are read through the resolver/metadata retriever. No blanket source copy is made. |
| SAF tree | `content://.../tree/...` returned by `ACTION_OPEN_DOCUMENT_TREE`. Children are enumerated through `DocumentsContract` using the tree URI. | The read grant and selected folder URI are persisted. Enumeration is direct-child only and filters supported media MIME types; nested folders are not recursively scanned. An empty/inaccessible tree is shown as empty/error, not as a successful import. |
| App project/draft | App-private `files/projects/project_<id>.json`. | Schema version 1. Each clip stores source URI, name, trim bounds, source duration, image/video type, crop, rotation and flips. The effects map stores speed/export preferences, audio tracks, layers, and subtitle cues/styles. |
| Temporary/derived data | Thumbnail/cache and photo-editor copy outputs are separate from project source references. | Temporary paths are not used as durable source IDs. Photo editing opens a copy workflow; the selected original is not overwritten. |

`EditorBridge` resolves media through `ContentResolver` and obtains a file descriptor/metadata from the provider; it does not assume `content://` is a direct path. `MediaCatalog` validates URI scheme, MIME, display name, size and access, and returns recoverable failures for missing grants/documents. Video duration, dimensions and rotation and image dimensions/orientation are queried where available. Audio tracks keep the selected document URI with source duration and trim/offset/gain data.

The Flutter project model accepts version 1, caps projects at 30 clips, and provides defaults for older/missing optional fields. Malformed project JSON is counted as unreadable in the list rather than deleted. Native draft saves use `AtomicFile` start/finish/fail semantics. Editor autosaves are coalesced; failed writes retain the open edit state and expose retry/keep-editing behavior. Existing historical files were inspected and hash-checked but not migrated or rewritten.

Relink is available from the selected clip’s **Replace source** menu. It validates the replacement’s media kind and, for video, duration against the existing clip end. It changes only the clip source URI/name/duration and preserves project identity, trim, crop, transform, effects, audio and subtitles. A missing source displays “Couldn’t play this video. Check access or choose another file.” while keeping the project and timeline available.

## SAF empty-folder investigation

The formerly reported empty-folder behavior was reproduced with the tree currently selected by the app: `0000-0000:Documents/Prompt05__SS`. That folder is actually empty. The known task fixture was on the separate `primary:Documents/Prompt05_SAF_QA_20261115` volume/path. DocumentsUI showed the fixture under that primary folder, and the app enumerated it after selecting that tree. The Prompt08 tree also enumerated its direct video correctly. The old observation therefore does not establish a catalog bug; it is consistent with selecting a different empty folder/storage root. The catalog correctly displayed zero items for the empty tree.

## Observed implementation behavior and limitations

- SAF folder enumeration is direct-child only; nested folders are not included in a parent folder’s result.
- Provider permission revocation and SD-card removal were not simulated on this emulator. Physical/OEM follow-up is listed in `docs/qa/PHYSICAL_DEVICE_QA_HANDOFF.md`.
- The previous Video Library search-input ANR was not reproduced in this import/project pass; no resolution claim is made.
- No export queue or broad export QA was performed; those remain Prompt09B scope.
- No unsupported-codec or power-loss save fault was induced on device. Focused Flutter tests cover failed-save retry; the native `EditorStorageTest` cases validate storage estimates, not interrupted project writes.

## Baseline project identities

All 12 projects present at preflight were hash-checked again after QA. Every SHA-256 matched. Two additional task-owned drafts were created with independent IDs and are listed in the test matrix/final handoff.

| Project file | Baseline SHA-256 |
|---|---|
| `project_1793872695793809.json` | `ff686a1a27edd8cd1fc88a5c5b241ff9ece3423454274cb545bba89273ee4a0b` |
| `project_1793872731095098.json` | `b933cee4c1dd8d2935faa113b95cdc40dd5009f52671437142fb0def969c3485` |
| `project_1793873265519242.json` | `564e17de04043aeb2daec64b18fecea222dc0e9e92054d80637b678a547f8ebc` |
| `project_1793873285734029.json` | `2eaa571803629927d9fdccaaa2eb51bd13e77b88cefbba92a3ca00f0be1593a2` |
| `project_1794303132745581.json` | `5f210d05752651801b95e92f9db0ed61e1ad60a255f4b0f04712a7707a7f3a97` |
| `project_1794303136702785.json` | `8e761c53225ce534a77267024781760b4bf4265d91507c198767f39dab9320b0` |
| `project_1794303140310584.json` | `4bc2380c762c8ab959c7fb2d187b2e257b8e31adb8125d5fef12f224303f23c0` |
| `project_1794303415721451.json` | `e22a2e1650ba6691c450e842c6c0dd5c4b3a070ba37c54bc6cd0ec458afe8e2f` |
| `project_1794759299435822.json` | `49084280ce716946e509b508ef93b7b11e405a3670268fa3e07f8235b223cdf2` |
| `project_1794791168352701.json` | `a80bfcc956da03b544056470eb648882ae9a02f93fd8e10bf0df1df5c145da1d` |
| `project_1794804603075477.json` | `f100b328c70b3da43dab629fce0d0d0b3645c08c764370d4dd0b9355e25f7ba1` |
| `project_1794806461743397.json` | `83a7434a6f754d51483b03185c85b4df29ec264daeae54a5756e843243f635cb` |

Baseline settings/media-folder/speech-model preference hashes were also recorded before tests and matched after the original folder selection was restored; exact values are in the final handoff.
