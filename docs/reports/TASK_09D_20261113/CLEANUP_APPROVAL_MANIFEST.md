# TASK09D cleanup approval manifest

**NO historical deletion or archival move has been approved/executed by this task.**
TASK09D section 7 requires separate user approval for historical material.
Only three independently eligible compiler caches were cleaned automatically.

Approval must name group IDs, action and destination. It may authorize copy-only
or copy plus verified original removal. Check copies, links, restoration and the
exact-file removal gate first; removal already explicitly authorized does not
require repeated permission. Copy-only approval does not authorize deletion.
No directory-wide wildcard or recursive deletion is authorized.

| Group | Files | Logical bytes | Allocated bytes | Proposed action |
| --- | ---: | ---: | ---: | --- |
| P01 | 1 | 89467873 | 89468928 | Delete one exact historical APK duplicate |
| P02 | 148 | 7399823866 | 7400128512 | Off-volume archive of older QA APKs |
| P03 | 548 | 81164195 | 82285640 | Off-volume archive of older visual captures |
| P04 | 697 | 101044928 | 102112480 | Off-volume archive of old reports, logs, runners and plans |
| P05 | 105 | 4568060 | 4693632 | Off-volume archive of historical performance observations |
| P06 | 98 | 31749110394 | 31475942592 | Conditional off-volume archive of older non-QA5560 AVD cohorts |
| P07 | 10989 | 2172729648 | 2188947088 | Off-volume archive of remaining old QA reproduction/source snapshots |

Exact file lists and byte counts are fixed by [APPROVAL_FILES.csv](APPROVAL_FILES.csv);
proposed cohort count **12586**, seven decisions. Do not interpret
a directory prefix in this report as an allowlist.

## P01 exact duplicate details

Proposed deletion:
`D:/FAU_App/XRecorder/build/uiux02/workspace/build/app/outputs/apk/debug/app-debug.apk`.

Retained twin:
`D:/FAU_App/XRecorder/build/uiux02/workspace/build/app/outputs/flutter-apk/app-debug.apk`.

Both SHA-256:
`a18bdf68262e243818ef6906e0842ae5aa2f78f8127815ad80374866a6b0c3ce`.
Payload each 89,467,873 bytes; target allocation 89,468,928 bytes.
Proof reused from TASK09C and both hashes freshly reverified in
[DUPLICATE_APK_VERIFICATION.json](DUPLICATE_APK_VERIFICATION.json); rehash both immediately
before any approved deletion. Both are Git-ignored. Owner: UI02 QA retention owner.
Original report/size inventories remain intact, with a deletion/twin mapping.
Recovery: copy only the retained identical APK back and verify SHA-256.
The twin is retained outside P02/P07.

## P01 — Delete one exact historical APK duplicate

Exact path set: rows with `proposal=P01` in [APPROVAL_FILES.csv](APPROVAL_FILES.csv).
Every row is a specific file; grouping is for review only. Files: **1**.
Logical bytes: **89467873**; measured allocated bytes: **89468928**
(0.089469 GB). Risk: **Low, after approval**.

Reason: Delete one exact historical APK duplicate. What would be lost without preservation: 89 MB duplicate payload; no unique binary.
Required preservation actions: Keep verified twin at original path; tombstone metadata only.
Source/report references appear per file in `referencing_documents_or_scripts`
and in [canonical dependencies](CANONICAL_ARCHIVE_DEPENDENCIES.json).
No-reference results are not proof against dynamic or external consumers.
Expected recoverable storage is conditional on originals being removed after
an approved off-volume copy and verification; filesystem/volume changes must
be measured again at execution.

## P02 — Off-volume archive of older QA APKs

Exact path set: rows with `proposal=P02` in [APPROVAL_FILES.csv](APPROVAL_FILES.csv).
Every row is a specific file; grouping is for review only. Files: **148**.
Logical bytes: **7399823866**; measured allocated bytes: **7400128512**
(7.400129 GB). Risk: **Medium**.

Reason: Off-volume archive of older QA APKs. What would be lost without preservation: Local access to 148 old binaries; payload must remain restorable.
Required preservation actions: Preserve APK SHA/cert, source revision/dirty provenance, build recipe and failed-run associations.
Source/report references appear per file in `referencing_documents_or_scripts`
and in [canonical dependencies](CANONICAL_ARCHIVE_DEPENDENCIES.json).
No-reference results are not proof against dynamic or external consumers.
Expected recoverable storage is conditional on originals being removed after
an approved off-volume copy and verification; filesystem/volume changes must
be measured again at execution.

## P03 — Off-volume archive of older visual captures

Exact path set: rows with `proposal=P03` in [APPROVAL_FILES.csv](APPROVAL_FILES.csv).
Every row is a specific file; grouping is for review only. Files: **548**.
Logical bytes: **81164195**; measured allocated bytes: **82285640**
(0.082286 GB). Risk: **Medium**.

Reason: Off-volume archive of older visual captures. What would be lost without preservation: Local inline visuals until link migration/catalog is validated.
Required preservation actions: Bundle reports and screenshots/videos together; preserve failures and source/fixture distinction.
Source/report references appear per file in `referencing_documents_or_scripts`
and in [canonical dependencies](CANONICAL_ARCHIVE_DEPENDENCIES.json).
No-reference results are not proof against dynamic or external consumers.
Expected recoverable storage is conditional on originals being removed after
an approved off-volume copy and verification; filesystem/volume changes must
be measured again at execution.

## P04 — Off-volume archive of old reports, logs, runners and plans

Exact path set: rows with `proposal=P04` in [APPROVAL_FILES.csv](APPROVAL_FILES.csv).
Every row is a specific file; grouping is for review only. Files: **697**.
Logical bytes: **101044928**; measured allocated bytes: **102112480**
(0.102112 GB). Risk: **Medium**.

Reason: Off-volume archive of old reports, logs, runners and plans. What would be lost without preservation: Local historical narrative and one-off reproduction tools.
Required preservation actions: Preserve dependency closure, dated facts, FAIL/PARTIAL records and Git recovery identities.
Source/report references appear per file in `referencing_documents_or_scripts`
and in [canonical dependencies](CANONICAL_ARCHIVE_DEPENDENCIES.json).
No-reference results are not proof against dynamic or external consumers.
Expected recoverable storage is conditional on originals being removed after
an approved off-volume copy and verification; filesystem/volume changes must
be measured again at execution.

## P05 — Off-volume archive of historical performance observations

Exact path set: rows with `proposal=P05` in [APPROVAL_FILES.csv](APPROVAL_FILES.csv).
Every row is a specific file; grouping is for review only. Files: **105**.
Logical bytes: **4568060**; measured allocated bytes: **4693632**
(0.004694 GB). Risk: **Medium**.

Reason: Off-volume archive of historical performance observations. What would be lost without preservation: Exact observed measurements cannot be regenerated by a new run.
Required preservation actions: Keep raw trial arrays, timing units/workload/source identities and summaries together.
Source/report references appear per file in `referencing_documents_or_scripts`
and in [canonical dependencies](CANONICAL_ARCHIVE_DEPENDENCIES.json).
No-reference results are not proof against dynamic or external consumers.
Expected recoverable storage is conditional on originals being removed after
an approved off-volume copy and verification; filesystem/volume changes must
be measured again at execution.

## P06 — Conditional off-volume archive of older non-QA5560 AVD cohorts

Exact path set: rows with `proposal=P06` in [APPROVAL_FILES.csv](APPROVAL_FILES.csv).
Every row is a specific file; grouping is for review only. Files: **98**.
Logical bytes: **31749110394**; measured allocated bytes: **31475942592**
(31.475943 GB). Risk: **High; not execution-ready**.

Reason: Conditional off-volume archive of older non-QA5560 AVD cohorts. What would be lost without preservation: Unique guest state, grants and environment if archive is incomplete.
Required preservation actions: Owner sign-off, backing-chain/ini/key/snapshot audit, shutdown/locking, full hash verification and restoration first.
Source/report references appear per file in `referencing_documents_or_scripts`
and in [canonical dependencies](CANONICAL_ARCHIVE_DEPENDENCIES.json).
No-reference results are not proof against dynamic or external consumers.
Expected recoverable storage is conditional on originals being removed after
an approved off-volume copy and verification; filesystem/volume changes must
be measured again at execution.

## P07 — Off-volume archive of remaining old QA reproduction/source snapshots

Exact path set: rows with `proposal=P07` in [APPROVAL_FILES.csv](APPROVAL_FILES.csv).
Every row is a specific file; grouping is for review only. Files: **10989**.
Logical bytes: **2172729648**; measured allocated bytes: **2188947088**
(2.188947 GB). Risk: **Medium/high**.

Reason: Off-volume archive of remaining old QA reproduction/source snapshots. What would be lost without preservation: Old source/build snapshots and complete reproduction context.
Required preservation actions: Include logs, runner dependencies, manifests and license copies; preserve unique failures.
Source/report references appear per file in `referencing_documents_or_scripts`
and in [canonical dependencies](CANONICAL_ARCHIVE_DEPENDENCIES.json).
No-reference results are not proof against dynamic or external consumers.
Expected recoverable storage is conditional on originals being removed after
an approved off-volume copy and verification; filesystem/volume changes must
be measured again at execution.


## Cross-group gates and exclusions

P03/P04/P05/P07 share report-to-evidence dependencies: **120 current canonical
links** enter these sets. Preserve the closure as a self-contained relative-path
bundle and revise active references only under the approved move plan.
The QA06 → QA05B helper dependency remains active; any immutable archival copy
must also preserve matching helper versions and notices without removing originals.

P06 is a **retention review**, not permission to delete guest disks. Its exact
98-file cohort covers older TASK07/TASK09/API34 AVD paths and their adjacent
descriptors. Confirm backing files, encryption keys, snapshots, app/private
state and retirement with the owner. Hash verification/restoration is mandatory
after destination approval. Live/current TASK09B, QA5560, TASK08 checkpoints,
all private backups, actual model weights and user/source media are excluded.

P02/P03/P04/P05/P07 together: **9778167352 allocated bytes**.
P01 plus those cohorts: **9867636280 bytes**.
P06 conditional addition: **31475942592 bytes**.
All groups total **41343578872 bytes**, not guaranteed free space:
hard links, sparse/compressed data, archive overhead and concurrent writes must
be checked again before execution. No same-volume move is counted as recovery.

