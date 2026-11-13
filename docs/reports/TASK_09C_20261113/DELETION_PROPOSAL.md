# Separate approval proposal — one historical APK copy

**Not executed. Group C requires separate user approval under TASK09C.**
This proposal excludes all AVDs, models, media, drafts, backups, recovery and unique QA evidence.

| Role | Exact path | Logical bytes | SHA-256 |
| --- | --- | ---: | --- |
| Proposed removal | `D:/FAU_App/XRecorder/build/uiux02/workspace/build/app/outputs/apk/debug/app-debug.apk` | 89,467,873 | `a18bdf68262e243818ef6906e0842ae5aa2f78f8127815ad80374866a6b0c3ce` |
| Retained recovery twin | `D:/FAU_App/XRecorder/build/uiux02/workspace/build/app/outputs/flutter-apk/app-debug.apk` | 89,467,873 | `a18bdf68262e243818ef6906e0842ae5aa2f78f8127815ad80374866a6b0c3ce` |

[Measured duplicate proof](historical_apk_duplicate.json).
Both paths are Git-ignored. Owner: UI/UX 02 QA snapshot/retention owner; not inferred
to be abandoned. Potential recoverable logical bytes: 89,467,873; allocated/free
space gain is not measured until an authorized future operation.

Risk: the historical snapshot's Gradle/Flutter consumers may expect both output
paths, and build-internal/external references were not exhaustively disproven.
Preserving the retained twin preserves payload bytes, not every aspect of snapshot
layout or provenance. No canonical archived report or QA result would be removed.

Before any approved execution: recheck hash, references, active process ownership,
retention requirements and exact target; run WhatIf. Recovery would copy only the
retained identical APK back to the missing path and verify SHA-256. No large new
backup or AVD copy is needed. No action is authorized merely by this document.

