# TASK09D storage recovery report

## Measured cleanup

| Measurement | Bytes |
| --- | ---: |
| Three removed files, logical length | 245,697,944 |
| Measured allocated storage of those single-link regular files | **245,702,656** |
| D: free immediately before deletion | 27,931,983,872 |
| D: free immediately after deletion | 28,177,686,528 |
| Observed free-space increase | **245,702,656** |

**Recovered: 0.245702656 GB** (decimal), approximately 234.32 MiB.
The short-window volume delta matches allocation; volume measurements can still
include unrelated host activity. Source file allocation and volume delta are
reported independently. [Every removed path/hash](FILES_REMOVED_MANIFEST.json).

Executed archive moves: **0**. Space freed by moving to another volume: **0**.
Space saved through historical deduplication: **0**; P01 awaits approval.
Within-volume moves would free no space.

D: free space at TASK09D baseline was 27,933,327,360 bytes. At validation it was
about 28.170 GB, a net observed improvement of about 0.236 GB after roughly 7.4 MB
of report/manifest output and other possible host writes. This net volume change
is separate from the exactly measured 245,702,656-byte cache deletion. The latest
snapshot and report overhead are recorded in [VALIDATION.json](VALIDATION.json).

TASK09C's reused snapshot reports 152,414,281,434 logical workspace bytes before
its final report writes; today's task starts at approximately 152.4 GB.
No new full workspace scan was run and no exact final workspace size is claimed.
Subtracting logical cache lengths is only an estimate; new reports and other host
writes must also be included in any later complete total.

## Allocation method

Windows GetFileInformationByHandleEx(FileStandardInfo).AllocationSize measures
allocated file storage; logical EOF and hard-link counts were recorded separately
for 642 substantial files. GetCompressedFileSizeW is also recorded for sparse/
compressed-storage comparisons. Approval tables use AllocationSize, including
fresh measurements for small candidates, not apparent AVD virtual disk capacity.
Only metadata was queried; huge AVD payloads were not hashed or copied.
[Allocation records](ALLOCATED_STORAGE.json).

## Approval opportunities

| Group | Files | Logical bytes | Allocated bytes | Proposed action |
| --- | ---: | ---: | ---: | --- |
| P01 | 1 | 89467873 | 89468928 | Delete one exact historical APK duplicate |
| P02 | 148 | 7399823866 | 7400128512 | Off-volume archive of older QA APKs |
| P03 | 548 | 81164195 | 82285640 | Off-volume archive of older visual captures |
| P04 | 697 | 101044928 | 102112480 | Off-volume archive of old reports, logs, runners and plans |
| P05 | 105 | 4568060 | 4693632 | Off-volume archive of historical performance observations |
| P06 | 98 | 31749110394 | 31475942592 | Conditional off-volume archive of older non-QA5560 AVD cohorts |
| P07 | 10989 | 2172729648 | 2188947088 | Off-volume archive of remaining old QA reproduction/source snapshots |

P01 is a potential **0.089469 GB** verified duplicate removal.
P02/P03/P04/P05/P07 could free **9.778167 GB** after approved
off-volume archival, full verification/reference work and approved original removal.
Together with P01: **9.867636 GB**.
P06 is a separately gated **31.475943 GB** retention/AVD proposal,
not presently execution-ready. All cohorts: **41.343579 GB** conditional
allocation sum; none is counted as already recovered.

## Largest remaining measured consumers

| Exact repository-relative file | Allocated bytes | Retention |
| --- | ---: | --- |
| `build/verification/task09b/run_20261109T113727956224Z_f64203/avds/ThreeHRecorder_TASK09B_API36.avd/userdata-qemu.img.qcow2` | 12164071424 | Keep; owner/lineage decision required |
| `build/verification/task08/avds/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img.qcow2` | 8992391168 | Keep; owner/lineage decision required |
| `build/task021_avd/ThreeHRecorder_Task021.avd/userdata-qemu.img.qcow2` | 6442909696 | Protected QA5560; keep |
| `build/verification/task09/avds/ThreeHRecorder_TASK09_API36.avd/userdata-qemu.img.qcow2` | 6438977536 | Keep; owner/lineage decision required |
| `build/verification/task08/offline_checkpoint_v2_20261109T041649Z_140e2301/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img.qcow2` | 5923209216 | Keep; owner/lineage decision required |
| `build/verification/task08/offline_checkpoint_v2_20261109T040853Z_4d4ea6d8/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img.qcow2` | 5811666944 | Keep; owner/lineage decision required |
| `build/verification/task08/offline_checkpoint_v2_20261109T034847Z_fa387232/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img.qcow2` | 5363662848 | Keep; owner/lineage decision required |
| `build/verification/task08/offline_checkpoint_v2_20261109T034457Z_f0393303/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img.qcow2` | 5348917248 | Keep; owner/lineage decision required |
| `build/verification/task08/offline_checkpoint_v1_20261108T095427Z_10b59617/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img.qcow2` | 5258215424 | Keep; owner/lineage decision required |
| `build/verification/task07/avds/ThreeHRecorder_TASK07_16KB.avd/userdata-qemu.img.qcow2` | 4257415168 | Keep; owner/lineage decision required |

The five TASK08 offline checkpoints alone contain 128 baseline paths and
44,380,331,607 logical bytes. They are separate recovery checkpoints, not verified
duplicates, and are excluded from this deletion/archive approval set.
QA5560's entire protected AVD lineage stays at its original path.
Current TASK09B AVD, private backup tars, actual retained Whisper weights,
source media and draft-related data are retained.

Only C: and D: were available. C: baseline free 17.205 GB does not
fit the full proposal; D: is the source volume. An archive destination is still
a user decision. Final free space and report overhead are recorded in
VALIDATION.json after reports are created.

