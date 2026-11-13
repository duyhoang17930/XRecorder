# TASK09D active vs archive plan

**PARTIAL readiness:** path decisions and sequence are ready for review;
destination, 120 reference migrations, owner decisions and restoration checks
are not approved or completed. Nothing was moved.

## Active tree

Keep source/config/dependencies, runtime assets/licenses/fonts, current tests,
required fixtures and reusable tools in place. Keep the [canonical index](../../README.md),
[canonical path list](CANONICAL_PATHS.json), latest UI06/TASK09B/P1 handoffs and
TASK09C preservation baselines accessible. Dated reports certify only their
recorded revision; current source remains authoritative.

Keep QA06/QA05B helper dependencies, unresolved-defect reproduction material,
recovery validators and all source/model/user data. TASK08 recovery remains
PARTIAL; no archival plan resolves lost guest state.

## Long-term archive

Recommended layout on a separately approved volume:

```text
<archive-volume>/3HRecorder/<dated-bundle>/
  manifest.json
  checksums.sha256
  restore-instructions.md
  repo/
    docs/<original relative paths>
    build/<original relative paths>
```

P02 holds old APKs with source/cert/build provenance. P03/P04/P05/P07 hold report,
visual, performance and reproduction cohorts. Preserve relative paths inside
the bundle; keep unique FAIL/PARTIAL and incident facts. Copy license/helper
dependencies into the bundle where required while retaining active originals.

P06 old AVDs require a separate retirement/backing-chain plan. QA5560 and TASK08
recovery materials stay protected at original locations in this task. A future
long-term recovery archive must keep all lineage/checkpoint manifests and guest
state; do not choose a checkpoint based only on date or file size.

## Capacity and operation sequence

At baseline C: had **17205112832 bytes** free (17.205 GB);
D: had **27933327360 bytes** free. No other mounted destination was found.
C: cannot hold the full 41.344 GB proposed set, and using it for
a smaller subset needs an explicit capacity/OS-space decision. D: is the same
volume as the source: moving within it frees **0 bytes**.

Prefer a named external/network destination with capacity for the chosen cohorts
plus verification/rollback margin. Approximately 55 GB free covers this entire
41.34 GB proposal with margin; a separate later recovery archive would need more.
No archive copy, compression, deduplication or relocation has run.

1. User names exact groups/action/destination; owners approve AVD retirement and
   historic reproductions as appropriate. Recheck destination and free space.
2. Materialize the exact CSV subset into an execution manifest with fresh size,
   SHA-256, link count, sparse allocation and source revision/provenance.
3. Resolve reference/dependency closure. Handle the 120 canonical links before
   removing any referenced target. Keep unchanged historical facts and verdicts.
4. Stop relevant writers using an authorized process plan; do not kill/boot/clear
   user environments. Do not delete coordination locks as a shortcut.
5. Copy selected files preserving repo-relative paths and required metadata.
   Verify every copied byte/checksum, count and manifest; preserve notice files.
6. Restore representative APK/report+image/runner cohorts to an isolated approved
   scratch location. Validate documented links and reproducibility. AVD restore
   requires separately authorized safe hardware/VM testing; do not use QA5560.
7. Show verified copy/restore results and exact original-path removal list.
   Apply any explicit copy-plus-removal approval already given, using WhatIf and
   exact files. If only copying was approved, request removal approval at this point.
8. Measure actual allocated/free-space change; record source tombstones and archive
   mappings. Keep catalog/manifests active and verify links again.

Before a move, archive-catalog navigation and link changes must be concrete and
reviewable. No placeholder text file should silently replace a PNG, script or APK.
Git recovery is a useful option for 892 clean tracked historical files; it does
not recover untracked evidence or ignored private data.

## What is not proposed

No app source refactor, fixture/model/media deletion, license removal, full workspace
backup, hundreds-of-GB copy on D:, broad cache clean, Git reset/clean/stash,
staging/commit/push or TASK10 integration.

