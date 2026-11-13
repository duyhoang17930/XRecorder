# TASK09D historical retention audit

2026-11-13. HEAD `e008fbb095be62db9538f4c598cbff89e6ceb7aa`, main/origin/main.
This task changed no application source, dependency or P1 contract.

## Scope and evidence reused

Reused TASK09C after_inventory.json, CLEANUP_MANIFEST.json, storage/preservation
reports, Python inventory and duplicate proofs. Git exactly matched TASK09C's
closing snapshot at start: **59 modified tracked, 7 original deleted tracked,
863 untracked, zero staged**. No new full workspace traversal or AVD payload scan.

Classified **14,890 historical path records**, plus separately verified three
compiler caches. Read 3,170 bounded source/document/script files for retention
references; cache preflight searched 7,834 bounded text files. Fresh Windows
allocation metadata was queried for 642 substantial files, then for small
approval-candidate files. Source/config/asset/document preservation uses 618 hashes.
Counts refer to metadata/selected content inspection, not full playback of media.

## Classification

| Category | Count / meaning |
| --- | --- |
| A current development | 138 primary records: canonical guidance, current handoffs, helper dependencies, notices |
| B current tests/tools | 758 primary records with conservative active references |
| C important history | 12,695 primary records; archive where appropriate, not blanket protected |
| D recoverable from Git | 892 secondary records, clean tracked paths at captured HEAD |
| E regenerable | Three individually verified compiler caches removed; no historical observation called regenerable |
| F exact duplicate | 204 primary historical records; provenance still matters |
| G superseded temporary output | Four primary records; remain approval-gated historical material |
| H protected/uncertain | 1,091 primary records: incident/recovery, models, private backups, disk lineage |

D is a secondary flag and is not added to primary counts.
[RETENTION_DECISIONS.csv](RETENTION_DECISIONS.csv) records exact paths, categories,
reason, Git recoverability, known references and individual decisions.
The remaining C records are distinguished from protected H; many are proposed
for long-term archive, while P1 technical history stays with its owner.

## Concrete value/dependency findings

- The 245.70 MB Flutter test kernels are incremental compiler state, not saved QA
  results. SDK TestCompiler constructs these paths and repopulates them from
  source. Their only discovered filename references are old size inventories.
- QA06 imports qa05b from the prior UI05B directory. Keep those helper modules
  active; do not archive folders independently by date.
- Current runtime assets, test fixtures, licenses, fonts, original reference
  media and reusable tool/ validators remain active and untouched.
- Old performance traces record an actual historical workload. A new benchmark
  does not recreate those observations; they should be archived with raw data.
- Dated TASK01–09/09B, UI01–06 and P2/P3 reports preserve unique facts, including
  FAIL/PARTIAL. Older implementation prompts/plans are historical guidance, not
  current implementation authority.
- The two APKs sampled as same-size in TASK09C are different SHA payloads. They
  remain distinct archive artifacts. Only the verified UI02 APK twin is a
  deletion proposal.
- TASK08 checkpoints have separate manifests and materially different userdata
  lengths. Their allSourceAndCopySha256Exact flag verifies each original copy;
  it does not prove different checkpoints equivalent.
- QA5560 `build/task021_avd/`, all TASK08 recovery checkpoints/incident material,
  retained model weights, private backup archives and source/QA media are not
  automatic-cleanup candidates. No full historical recovery is claimed.

## Executed cleanup

Exactly three ignored regular files under `build/test_cache/build/` were
removed after SHA/kernel-magic/reference, no-test-process, exclusive-open,
path-containment and WhatIf gates. [Removal manifest](FILES_REMOVED_MANIFEST.json)
records every path and hash. Logical bytes: **245,697,944**; allocated bytes:
**245,702,656**. Observed volume free gain matches allocation exactly.
Historical reports, screenshots/videos, APKs, scripts, AVDs and backups deleted: **0**.

## Approval and archival opportunities

| Group | Files | Logical bytes | Allocated bytes | Proposed action |
| --- | ---: | ---: | ---: | --- |
| P01 | 1 | 89467873 | 89468928 | Delete one exact historical APK duplicate |
| P02 | 148 | 7399823866 | 7400128512 | Off-volume archive of older QA APKs |
| P03 | 548 | 81164195 | 82285640 | Off-volume archive of older visual captures |
| P04 | 697 | 101044928 | 102112480 | Off-volume archive of old reports, logs, runners and plans |
| P05 | 105 | 4568060 | 4693632 | Off-volume archive of historical performance observations |
| P06 | 98 | 31749110394 | 31475942592 | Conditional off-volume archive of older non-QA5560 AVD cohorts |
| P07 | 10989 | 2172729648 | 2188947088 | Off-volume archive of remaining old QA reproduction/source snapshots |

Groups are non-overlapping exact CSV entries, not directory-deletion permissions.
[APPROVAL_FILES.csv](APPROVAL_FILES.csv) lists **12586 files** in seven
decision groups. Non-AVD archival cohorts contain 12487 files and
9778167352 allocated bytes. With P01, potential off-volume/deletion
recovery is 9.867636 GB. P06 adds 31.475943 GB only after
high-risk lineage/owner/restoration gates. No proposed archival operation ran.

There are **120 canonical Markdown links** into P03/P04/P05/P07.
[Dependency manifest](CANONICAL_ARCHIVE_DEPENDENCIES.json) records exact edges;
these groups cannot be moved until reference migration or a validated archive
catalog/restore workflow is approved. P01's identical retained APK is excluded
from other proposals to keep the deletion independent.

## Documentation and Git hygiene

[Current documentation index](../../README.md) now explicitly indexes architecture,
feature status, testing, globalization, known bugs, TASK10 prerequisites and
retention decisions. Current reports stay dated; none was rewritten as PASS.
The active reference catalog also had 90 incorrect `../images/` links. They now
point to the existing `../image/` files. Only target prefixes changed; original
catalog bytes are recoverable by reversing that prefix, verified by baseline hash.
No asset was renamed, moved or deleted. See [link repair](REFERENCE_LINK_REPAIR.json).

Most untracked originals are UI05/05B/06 evidence, plus necessary new source/tests
and TASK09C reports. They are real work, not 863 disposable files.
No new ignore rule is warranted for cache paths already covered by /build/.
Existing *.log hides two evidence logs under docs; consider narrowly unignoring
those exact files after ownership review, rather than hiding more documentation:

- `docs/reports/TASK_UI_UX_02C_1794306547967/final_validation_1794308971153.log`
- `docs/reports/TASK_UI_UX_06_20261111_172021_ffa4c9/resume_avd_c343ae55.log`

.gitignore/index are unchanged. No staging/commit/push/rebase occurred.
Read the [archival plan](ACTIVE_VS_ARCHIVE_PLAN.md) and
[approval manifest](CLEANUP_APPROVAL_MANIFEST.md) before any future action.

## Final verification

[VALIDATION.json](VALIDATION.json): 618 hash checks preserve application/config/
asset files and original document content. Only the two authorized documentation
files changed; no original untracked file is lost. The only missing inventory
paths are the three removed caches. P1/recovery/model/AVD metadata has no delta.
Python report-helper syntax, JSON parsing and git diff --check pass.

The project Markdown check examined 2,106 local targets: no broken target was
introduced in changed/new documents. After the 90 repairs, 45 unresolved target
candidates remain in unchanged historical reports, including links to the seven
reference assets already deleted before TASK09C. They are listed rather than
restored or rewritten. No Flutter/native/device test was needed or run.

