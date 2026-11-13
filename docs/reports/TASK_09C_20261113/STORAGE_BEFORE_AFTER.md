# TASK09C storage before / after

Decimal GB = bytes / 1,000,000,000. Sizes below are logical file lengths, not
allocated AVD clusters. Metadata scans do not follow junctions or hash disk images.

| Measurement | Baseline | After host validation |
| --- | ---: | ---: |
| Repository logical bytes | 152401172646 | 152414281434 |
| Repository logical GB | 152.401173 | 152.414281 |
| build logical bytes | 144218346589 | 144218316909 |
| D: free bytes | 27958640640 | 27943596032 |

The after snapshot precedes writing itself and the final narrative reports.
The [closing measurement](closing_summary.json) records D: free space at
27,934,060,544 bytes and about 22.26 MB of task report/inventory artifacts.
Baseline includes the new inventory tool; initial read-only measurements
differ by its approximately 4.8 KB only. Metadata/evidence added by this task
and normal host-test caches account for growth. Final report files add a small
further amount. No broad storage reduction is claimed.

## Executed cleanup

[Exact allowlist](ephemeral_allowlist.json) and [result](ephemeral_cleanup_result.json):
two ignored CPython caches removed after valid-header/source/hash/ownership,
no-active-Python and PowerShell WhatIf gates.

- Logical bytes removed: **47,853**.
- Free immediately before deletion: **27,948,941,312 bytes**.
- Free immediately after deletion: **27,948,990,464 bytes**.
- Observed free-space gain: **49,152 bytes = 0.000049152 GB**.
- Allocated bytes attributable only to this operation were not independently
  measured; concurrent host activity can affect volume free space.
- Source line reductions and build-cache size changes are not counted as recovered
  disk space. No moved file is counted as deletion.

The overall D: free-space delta across the task is negative. Reports account for
about 22.26 MB; normal test-cache changes and other host activity may also contribute.
This is not proof that all volume changes came from this task.

## Retained large storage

`build/verification/`: 121,648,898,279 bytes;
`build/task021_avd/`: 9,769,224,149 bytes;
`build/final_api34_avd/`: 5,485,528,565 bytes;
`.dart_tool/`: 6,812,647,450 bytes at baseline.
These mix active cache and/or protected data. They are **not deletion allowlists**.

[97 large retained files](LARGE_FILE_RETENTION.json) contain exact paths/sizes.
Largest: TASK09B userdata qcow2, 12,164,071,424 bytes. Recovery checkpoints,
QA5560 lineage, all other AVDs/snapshots, AI models, user/QA media and private
backups remain untouched. Size+mtime preservation was checked; no VM boot/install,
guest data check or external disk traversal occurred.

## Remaining proposal

[One historical duplicate APK](DELETION_PROPOSAL.md), **89,467,873 logical bytes**
(0.089468 GB), is pending separate user approval plus a fresh process/reference
check. Its retained twin has identical SHA-256. No meaningful GB-scale deletion
is authorized: retention ownership and a storage plan are still needed before
considering larger regenerable or historical artifacts.

