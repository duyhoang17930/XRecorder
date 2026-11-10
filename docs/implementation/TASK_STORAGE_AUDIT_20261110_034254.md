# TASK Storage Audit ? 2026-11-10 03:42:54 UTC

## 1. T?m t?t ?i?u h?nh

Audit ch? ??c: kh?ng ??c n?i dung/hashes, kh?ng build/test/emulator, kh?ng cleanup. Workspace ???c duy?t metadata; junction/symlink/reparse point b? b? qua. Allocated size d?ng Windows GetCompressedFileSizeW. T?ng directory l? inclusive/path-based.

Project c? **146,175,364,746 B (146.175 GB; 136.136 GiB)** logical bytes; build c? **138,737,974,867 B (138.738 GB; 129.210 GiB)**. ? D: c?n **34,854,887,424 / 244,373,778,432 (14.3%)**. Hai l??t metadata tr??c l?ch **6,199,050,240 bytes (~6.20 GB)** d? s? file g?n nh? kh?ng ??i; nguy?n nh?n ch?a x?c ??nh. Verdict PARTIAL v? storage snapshot kh?ng ?n ??nh.

Kh?ng c? target ???c ch?ng minh an to?n ?? x?a: **safe recovery 0 GB**. C?c cache build t?ch bi?t ch? c? th? c?n nh?c c? ?i?u ki?n, t?ng t?i ?a **2,851,643,289 B (2.852 GB; 2.656 GiB) logical / 2,851,643,289 B (2.852 GB; 2.656 GiB) allocated** sau khi ??i chi?u jobs/references/evidence v? ???c duy?t. Kh?ng t?nh evidence, APK, AVD, fixtures, models, backups hay media.

## 2. Repository/Git

- Root: D:\FAU_App\XRecorder
- Branch/HEAD cu?i: main / 64e84ec0f952c4e28063488812933010f05bfa7d
- Status cu?i: ## main...origin/main
- Staged/unstaged/untracked cu?i: 0 / 0 / 0.
- HEAD ??u/cu?i: 64e84ec0f952c4e28063488812933010f05bfa7d -> 64e84ec0f952c4e28063488812933010f05bfa7d.
- Snapshot ??u: branch main, status ## main...origin/main.
- Ban ??u staged/unstaged/untracked: 0 / 0 / 0; tr?ng th?i quan s?t ban ??u c? staged TASK09B files. Sau ?? status/HEAD thay ??i b?n ngo?i audit v? cu?i c?ng clean. Kh?ng c? Git mutating commands; kh?ng kh?i ph?c tr?ng th?i c?.

## 3. T?ng project/build

| Scope | Files | Logical size | Allocated/path sum |
| --- | --- | --- | --- |
| Project | 25,330 | 146,175,364,746 B (146.175 GB; 136.136 GiB) | 145,710,452,362 B (145.710 GB; 135.703 GiB) |
| build/ | 18,437 | 138,737,974,867 B (138.738 GB; 129.210 GiB) | 138,273,062,483 B (138.273 GB; 128.777 GiB) |
| Outside build/ | 6,893 | 7,437,389,879 B (7.437 GB; 6.927 GiB) | 7,437,389,879 B (7.437 GB; 6.927 GiB) |

Allocation errors=0; traversal errors=0; skipped reparse entries=0; st_nlink>1 paths=0. Allocation totals are path sums and physical uniqueness is not proven if Windows hardlink metadata is incomplete.
### Disk free

- D: total 244,373,778,432 B; available 34,854,887,424 B; 14.3% free, via read-only disk usage API.
### Immediate build subdirectories

| Directory | Logical | Allocated | Files | Latest descendant mtime (UTC) |
| --- | --- | --- | --- | --- |
| .cxx | 174,725,837 B (0.175 GB; 0.163 GiB) | 174,725,837 B (0.175 GB; 0.163 GiB) | 319 | 2026-11-09 18:36:22 UTC |
| app | 3,572,635,958 B (3.573 GB; 3.327 GiB) | 3,572,635,958 B (3.573 GB; 3.327 GiB) | 3,861 | 2026-11-10 02:40:29 UTC |
| commit_p2_p3 | 91,608 B (0.000 GB; 0.000 GiB) | 91,608 B (0.000 GB; 0.000 GiB) | 7 | 2026-11-07 05:06:37 UTC |
| dfc37ff5513ab911e6470454752e2885 | 5,193 B (0.000 GB; 0.000 GiB) | 5,193 B (0.000 GB; 0.000 GiB) | 5 | 2026-11-10 02:38:54 UTC |
| f05bfb3d5907fd0115f5797e28554b94 | 9,322 B (0.000 GB; 0.000 GiB) | 9,322 B (0.000 GB; 0.000 GiB) | 5 | 2026-11-09 11:37:31 UTC |
| final_api34_avd | 5,485,528,565 B (5.486 GB; 5.109 GiB) | 5,421,696,501 B (5.422 GB; 5.049 GiB) | 25 | 2026-11-07 19:33:00 UTC |
| integration_test | 1,511,661 B (0.002 GB; 0.001 GiB) | 1,511,661 B (0.002 GB; 0.001 GiB) | 662 | 2026-11-09 18:36:22 UTC |
| native_assets | 45 B (0.000 GB; 0.000 GiB) | 45 B (0.000 GB; 0.000 GiB) | 1 | 2026-11-09 18:27:59 UTC |
| qa_python | 15,853,103 B (0.016 GB; 0.015 GiB) | 15,853,103 B (0.016 GB; 0.015 GiB) | 219 | 2026-11-06 17:25:12 UTC |
| qa_tools | 71,478,210 B (0.071 GB; 0.067 GiB) | 71,478,210 B (0.071 GB; 0.067 GiB) | 1 | 2026-11-07 02:24:45 UTC |
| reports | 144,069 B (0.000 GB; 0.000 GiB) | 144,069 B (0.000 GB; 0.000 GiB) | 1 | 2026-11-10 02:40:27 UTC |
| research | 49,971,415 B (0.050 GB; 0.047 GiB) | 49,971,415 B (0.050 GB; 0.047 GiB) | 2,148 | 2026-11-10 02:37:22 UTC |
| task021 | 325,149,216 B (0.325 GB; 0.303 GiB) | 325,149,216 B (0.325 GB; 0.303 GiB) | 3 | 2026-11-05 12:06:53 UTC |
| task021_avd | 9,769,224,149 B (9.769 GB; 9.098 GiB) | 9,705,392,085 B (9.705 GB; 9.039 GiB) | 38 | 2026-11-08 07:20:03 UTC |
| task022 | 490,534,676 B (0.491 GB; 0.457 GiB) | 490,534,676 B (0.491 GB; 0.457 GiB) | 4 | 2026-11-06 01:45:50 UTC |
| task03 | 541,598,617 B (0.542 GB; 0.504 GiB) | 541,598,617 B (0.542 GB; 0.504 GiB) | 16 | 2026-11-06 03:20:50 UTC |
| task031 | 706,387,912 B (0.706 GB; 0.658 GiB) | 706,387,912 B (0.706 GB; 0.658 GiB) | 6 | 2026-11-06 07:42:26 UTC |
| test_cache | 245,352,904 B (0.245 GB; 0.229 GiB) | 245,352,904 B (0.245 GB; 0.229 GiB) | 3 | 2026-11-09 18:28:52 UTC |
| tmp | 0 B (0.000 GB; 0.000 GiB) | 0 B (0.000 GB; 0.000 GiB) | 0 | ? |
| unit_test_assets | 2,977,725 B (0.003 GB; 0.003 GiB) | 2,977,725 B (0.003 GB; 0.003 GiB) | 17 | 2026-11-09 18:27:59 UTC |
| verification | 116,901,185,928 B (116.901 GB; 108.873 GiB) | 116,563,937,672 B (116.564 GB; 108.559 GiB) | 11,017 | 2026-11-10 03:40:31 UTC |

## 4. Top 20 largest build directories

Directory sizes include descendants and overlap when nested; do not sum rows. Latest mtime is newest descendant file. Purpose/reference are path-based assessments, not complete consumer graph.

| Relative path | Logical | Allocated | Files | Latest file mtime (UTC) | Purpose | Workflow reference | Classification |
| --- | --- | --- | --- | --- | --- | --- | --- |
| build/verification | 116,901,185,928 B (116.901 GB; 108.873 GiB) | 116,563,937,672 B (116.564 GB; 108.559 GiB) | 11,017 | 2026-11-10 03:40:31 UTC | QA/evidence/fixtures; preserve | May be referenced by TASK reports/manifests | PROTECTED |
| build/verification/task08 | 66,668,103,323 B (66.668 GB; 62.090 GiB) | 66,604,271,259 B (66.604 GB; 62.030 GiB) | 3,359 | 2026-11-10 01:13:25 UTC | QA/evidence/fixtures; preserve | May be referenced by TASK reports/manifests | PROTECTED |
| build/verification/task09b | 18,562,247,960 B (18.562 GB; 17.287 GiB) | 18,498,481,432 B (18.498 GB; 17.228 GiB) | 2,462 | 2026-11-10 03:40:31 UTC | QA/evidence/fixtures; preserve | May be referenced by TASK reports/manifests | PROTECTED |
| build/verification/task09b/run_20261109T113727956224Z_f64203 | 18,562,247,719 B (18.562 GB; 17.287 GiB) | 18,498,481,191 B (18.498 GB; 17.228 GiB) | 2,451 | 2026-11-10 03:40:31 UTC | QA/evidence/fixtures; preserve | May be referenced by TASK reports/manifests | PROTECTED |
| build/verification/task07 | 18,079,500,298 B (18.080 GB; 16.838 GiB) | 17,933,682,698 B (17.934 GB; 16.702 GiB) | 4,123 | 2026-11-09 05:39:20 UTC | QA/evidence/fixtures; preserve | May be referenced by TASK reports/manifests | PROTECTED |
| build/verification/task07/avds | 16,490,202,599 B (16.490 GB; 15.358 GiB) | 16,344,384,999 B (16.344 GB; 15.222 GiB) | 50 | 2026-11-09 05:39:20 UTC | QA/evidence/fixtures; preserve | May be referenced by TASK reports/manifests | PROTECTED |
| build/verification/task08/avds | 12,327,579,159 B (12.328 GB; 11.481 GiB) | 12,263,747,095 B (12.264 GB; 11.422 GiB) | 25 | 2026-11-09 06:15:23 UTC | QA/evidence/fixtures; preserve | May be referenced by TASK reports/manifests | PROTECTED |
| build/verification/task08/avds/ThreeHRecorder_TASK08_API36.avd | 12,327,579,028 B (12.328 GB; 11.481 GiB) | 12,263,746,964 B (12.264 GB; 11.422 GiB) | 24 | 2026-11-09 06:15:23 UTC | QA/evidence/fixtures; preserve | May be referenced by TASK reports/manifests | PROTECTED |
| build/verification/task09 | 12,322,919,663 B (12.323 GB; 11.477 GiB) | 12,259,087,599 B (12.259 GB; 11.417 GiB) | 601 | 2026-11-09 13:37:31 UTC | QA/evidence/fixtures; preserve | May be referenced by TASK reports/manifests | PROTECTED |
| build/verification/task09b/run_20261109T113727956224Z_f64203/avds | 12,209,876,791 B (12.210 GB; 11.371 GiB) | 12,146,110,263 B (12.146 GB; 11.312 GiB) | 24 | 2026-11-10 03:40:31 UTC | QA/evidence/fixtures; preserve | May be referenced by TASK reports/manifests | PROTECTED |
| build/verification/task09b/run_20261109T113727956224Z_f64203/avds/ThreeHRecorder_TASK09B_API36.avd | 12,209,876,622 B (12.210 GB; 11.371 GiB) | 12,146,110,094 B (12.146 GB; 11.312 GiB) | 23 | 2026-11-10 03:40:31 UTC | QA/evidence/fixtures; preserve | May be referenced by TASK reports/manifests | PROTECTED |
| build/verification/task07/avds/ThreeHRecorder_TASK07_API34_Clone.avd | 9,981,625,758 B (9.982 GB; 9.296 GiB) | 9,899,640,222 B (9.900 GB; 9.220 GiB) | 23 | 2026-11-09 05:39:20 UTC | QA/evidence/fixtures; preserve | May be referenced by TASK reports/manifests | PROTECTED |
| build/verification/task09/avds | 9,773,379,230 B (9.773 GB; 9.102 GiB) | 9,709,547,166 B (9.710 GB; 9.043 GiB) | 23 | 2026-11-09 11:21:23 UTC | QA/evidence/fixtures; preserve | May be referenced by TASK reports/manifests | PROTECTED |
| build/verification/task09/avds/ThreeHRecorder_TASK09_API36.avd | 9,773,379,055 B (9.773 GB; 9.102 GiB) | 9,709,546,991 B (9.710 GB; 9.043 GiB) | 22 | 2026-11-09 11:21:23 UTC | QA/evidence/fixtures; preserve | May be referenced by TASK reports/manifests | PROTECTED |
| build/task021_avd | 9,769,224,149 B (9.769 GB; 9.098 GiB) | 9,705,392,085 B (9.705 GB; 9.039 GiB) | 38 | 2026-11-08 07:20:03 UTC | AVD disk/snapshot/QA state | Live guest state not inspected | PROTECTED |
| build/task021_avd/ThreeHRecorder_Task021.avd | 9,768,988,443 B (9.769 GB; 9.098 GiB) | 9,705,156,379 B (9.705 GB; 9.039 GiB) | 31 | 2026-11-08 07:20:03 UTC | AVD disk/snapshot/QA state | Live guest state not inspected | PROTECTED |
| build/verification/task08/offline_checkpoint_v2_20261109T041649Z_140e2301 | 9,258,402,552 B (9.258 GB; 8.623 GiB) | 9,258,402,552 B (9.258 GB; 8.623 GiB) | 26 | 2026-11-09 04:19:36 UTC | QA/evidence/fixtures; preserve | May be referenced by TASK reports/manifests | PROTECTED |
| build/verification/task08/offline_checkpoint_v2_20261109T041649Z_140e2301/ThreeHRecorder_TASK08_API36.avd | 9,258,397,076 B (9.258 GB; 8.623 GiB) | 9,258,397,076 B (9.258 GB; 8.623 GiB) | 24 | 2026-11-09 04:17:50 UTC | QA/evidence/fixtures; preserve | May be referenced by TASK reports/manifests | PROTECTED |
| build/verification/task08/offline_checkpoint_v2_20261109T040853Z_4d4ea6d8 | 9,146,794,744 B (9.147 GB; 8.519 GiB) | 9,146,794,744 B (9.147 GB; 8.519 GiB) | 26 | 2026-11-09 04:11:45 UTC | QA/evidence/fixtures; preserve | May be referenced by TASK reports/manifests | PROTECTED |
| build/verification/task08/offline_checkpoint_v2_20261109T040853Z_4d4ea6d8/ThreeHRecorder_TASK08_API36.avd | 9,146,789,268 B (9.147 GB; 8.519 GiB) | 9,146,789,268 B (9.147 GB; 8.519 GiB) | 24 | 2026-11-09 04:09:31 UTC | QA/evidence/fixtures; preserve | May be referenced by TASK reports/manifests | PROTECTED |

## 5. Top 30 largest build files

| Relative path | Logical | Allocated | mtime (UTC) | Classification |
| --- | --- | --- | --- | --- |
| verification/task08/avds/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img.qcow2 | 8,992,391,168 B (8.992 GB; 8.375 GiB) | 8,992,391,168 B (8.992 GB; 8.375 GiB) | 2026-11-09 06:15:20 UTC | PROTECTED |
| verification/task09b/run_20261109T113727956224Z_f64203/avds/ThreeHRecorder_TASK09B_API36.avd/userdata-qemu.img.qcow2 | 8,875,212,800 B (8.875 GB; 8.266 GiB) | 8,875,278,336 B (8.875 GB; 8.266 GiB) | 2026-11-10 03:40:31 UTC | PROTECTED |
| task021_avd/ThreeHRecorder_Task021.avd/userdata-qemu.img.qcow2 | 6,442,909,696 B (6.443 GB; 6.000 GiB) | 6,442,909,696 B (6.443 GB; 6.000 GiB) | 2026-11-08 07:19:59 UTC | PROTECTED |
| verification/task09/avds/ThreeHRecorder_TASK09_API36.avd/userdata-qemu.img.qcow2 | 6,438,977,536 B (6.439 GB; 5.997 GiB) | 6,438,977,536 B (6.439 GB; 5.997 GiB) | 2026-11-09 11:21:21 UTC | PROTECTED |
| verification/task08/offline_checkpoint_v2_20261109T041649Z_140e2301/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img.qcow2 | 5,923,209,216 B (5.923 GB; 5.516 GiB) | 5,923,209,216 B (5.923 GB; 5.516 GiB) | 2026-11-09 04:17:35 UTC | PROTECTED |
| verification/task08/offline_checkpoint_v2_20261109T040853Z_4d4ea6d8/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img.qcow2 | 5,811,666,944 B (5.812 GB; 5.413 GiB) | 5,811,666,944 B (5.812 GB; 5.413 GiB) | 2026-11-09 04:09:18 UTC | PROTECTED |
| verification/task08/offline_checkpoint_v2_20261109T034847Z_fa387232/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img.qcow2 | 5,363,662,848 B (5.364 GB; 4.995 GiB) | 5,363,662,848 B (5.364 GB; 4.995 GiB) | 2026-11-09 03:49:08 UTC | PROTECTED |
| verification/task08/offline_checkpoint_v2_20261109T034457Z_f0393303/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img.qcow2 | 5,348,917,248 B (5.349 GB; 4.982 GiB) | 5,348,917,248 B (5.349 GB; 4.982 GiB) | 2026-11-09 03:45:19 UTC | PROTECTED |
| verification/task08/offline_checkpoint_v1_20261108T095427Z_10b59617/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img.qcow2 | 5,258,215,424 B (5.258 GB; 4.897 GiB) | 5,258,215,424 B (5.258 GB; 4.897 GiB) | 2026-11-08 09:54:49 UTC | PROTECTED |
| verification/task07/avds/ThreeHRecorder_TASK07_16KB.avd/userdata-qemu.img.qcow2 | 4,257,415,168 B (4.257 GB; 3.965 GiB) | 4,257,415,168 B (4.257 GB; 3.965 GiB) | 2026-11-09 05:31:36 UTC | PROTECTED |
| verification/task07/avds/ThreeHRecorder_TASK07_API34_Clone.avd/userdata-qemu.img.qcow2 | 3,430,285,312 B (3.430 GB; 3.195 GiB) | 3,430,285,312 B (3.430 GB; 3.195 GiB) | 2026-11-09 05:39:15 UTC | PROTECTED |
| verification/task07/avds/ThreeHRecorder_TASK07_API34_Clone.avd/userdata-qemu.img | 3,239,641,088 B (3.240 GB; 3.017 GiB) | 3,239,641,088 B (3.240 GB; 3.017 GiB) | 2026-11-07 19:33:54 UTC | PROTECTED |
| final_api34_avd/ThreeHRecorder_Final_API34.avd/userdata-qemu.img.qcow2 | 3,239,641,088 B (3.240 GB; 3.017 GiB) | 3,239,641,088 B (3.240 GB; 3.017 GiB) | 2026-11-07 10:47:05 UTC | PROTECTED |
| verification/task09b/run_20261109T113727956224Z_f64203/avds/ThreeHRecorder_TASK09B_API36.avd/snapshots/default_boot/ram.img | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 2026-11-09 11:38:45 UTC | PROTECTED |
| verification/task09/avds/ThreeHRecorder_TASK09_API36.avd/snapshots/default_boot/ram.img | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 2026-11-09 09:21:19 UTC | PROTECTED |
| verification/task08/offline_checkpoint_v2_20261109T041649Z_140e2301/ThreeHRecorder_TASK08_API36.avd/snapshots/default_boot/ram.img | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 2026-11-09 04:16:56 UTC | PROTECTED |
| verification/task08/offline_checkpoint_v2_20261109T040853Z_4d4ea6d8/ThreeHRecorder_TASK08_API36.avd/snapshots/default_boot/ram.img | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 2026-11-09 04:09:00 UTC | PROTECTED |
| verification/task08/offline_checkpoint_v2_20261109T034847Z_fa387232/ThreeHRecorder_TASK08_API36.avd/snapshots/default_boot/ram.img | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 2026-11-09 03:48:52 UTC | PROTECTED |
| verification/task08/offline_checkpoint_v2_20261109T034457Z_f0393303/ThreeHRecorder_TASK08_API36.avd/snapshots/default_boot/ram.img | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 2026-11-09 03:45:03 UTC | PROTECTED |
| verification/task08/offline_checkpoint_v1_20261108T095427Z_10b59617/ThreeHRecorder_TASK08_API36.avd/snapshots/default_boot/ram.img | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 2026-11-08 09:54:33 UTC | PROTECTED |
| verification/task08/avds/ThreeHRecorder_TASK08_API36.avd/snapshots/default_boot/ram.img | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 2026-11-08 07:18:10 UTC | PROTECTED |
| verification/task07/avds/ThreeHRecorder_TASK07_API34_Clone.avd/snapshots/default_boot/ram.img | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 2026-11-09 04:38:54 UTC | PROTECTED |
| task021_avd/ThreeHRecorder_Task021.avd/snapshots/default_boot/ram.img | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 2026-11-05 11:45:54 UTC | PROTECTED |
| verification/task07/avds/ThreeHRecorder_TASK07_16KB.avd/snapshots/default_boot/ram.img | 2,147,549,184 B (2.148 GB; 2.000 GiB) | 2,147,549,184 B (2.148 GB; 2.000 GiB) | 2026-11-09 05:26:18 UTC | PROTECTED |
| final_api34_avd/ThreeHRecorder_Final_API34.avd/snapshots/default_boot/ram.img | 2,147,549,184 B (2.148 GB; 2.000 GiB) | 2,147,549,184 B (2.148 GB; 2.000 GiB) | 2026-11-07 10:22:03 UTC | PROTECTED |
| verification/task08/m6_api36_main_restore_v1/archive_private_v1/task08_backup_v1_f91f6793405e4fb1b591dc91bc696a29.tar | 900,559,360 B (0.901 GB; 0.839 GiB) | 900,559,360 B (0.901 GB; 0.839 GiB) | 2026-11-09 06:11:42 UTC | PROTECTED |
| verification/task08/memory/library_ar_light_200_v2/archive_private_v1/task08_backup_v1_ee2ed31e27ca47b5a41d04cec442650d.tar | 890,755,072 B (0.891 GB; 0.830 GiB) | 890,755,072 B (0.891 GB; 0.830 GiB) | 2026-11-09 06:01:18 UTC | PROTECTED |
| verification/task08/m6_api36_final_install_v1/archive_private_v1/task08_backup_v1_c43cf6be3869428a95e6c62f41e9e6a0.tar | 889,888,768 B (0.890 GB; 0.829 GiB) | 889,888,768 B (0.890 GB; 0.829 GiB) | 2026-11-09 05:41:16 UTC | PROTECTED |
| verification/task09/run_20261109T091518633188Z/final_main_install_v1/archive_private_v1/task08_backup_v1_6a2b9fd99dc54f5caef724d9ce982421.tar | 863,328,256 B (0.863 GB; 0.804 GiB) | 863,328,256 B (0.863 GB; 0.804 GiB) | 2026-11-09 10:14:08 UTC | PROTECTED |
| verification/task08/m6_api34_final_install_v1/archive_private_v1/task08_backup_v1_bef1b51f907f4b3fb996fdb641a2b805.tar | 547,949,056 B (0.548 GB; 0.510 GiB) | 547,949,056 B (0.548 GB; 0.510 GiB) | 2026-11-09 05:35:29 UTC | PROTECTED |

## 6. Totals by extension

| Extension | Files | Logical | Allocated |
| --- | --- | --- | --- |
| .qcow2 | 43 | 69,462,530,328 B (69.463 GB; 64.692 GiB) | 69,462,595,864 B (69.463 GB; 64.692 GiB) |
| .img | 55 | 40,950,169,838 B (40.950 GB; 38.138 GiB) | 40,485,191,918 B (40.485 GB; 37.705 GiB) |
| .tar | 136 | 13,269,162,294 B (13.269 GB; 12.358 GiB) | 13,269,162,294 B (13.269 GB; 12.358 GiB) |
| .apk | 247 | 8,780,566,620 B (8.781 GB; 8.178 GiB) | 8,780,566,620 B (8.781 GB; 8.178 GiB) |
| .so | 104 | 2,394,286,656 B (2.394 GB; 2.230 GiB) | 2,394,286,656 B (2.394 GB; 2.230 GiB) |
| .bin | 187 | 1,489,529,360 B (1.490 GB; 1.387 GiB) | 1,489,529,360 B (1.490 GB; 1.387 GiB) |
| .log | 1,288 | 354,786,203 B (0.355 GB; 0.330 GiB) | 354,786,203 B (0.355 GB; 0.330 GiB) |
| .dill | 4 | 324,544,432 B (0.325 GB; 0.302 GiB) | 324,544,432 B (0.325 GB; 0.302 GiB) |
| .json | 1,571 | 314,042,106 B (0.314 GB; 0.292 GiB) | 314,042,106 B (0.314 GB; 0.292 GiB) |
| .mp4 | 393 | 238,244,792 B (0.238 GB; 0.222 GiB) | 238,244,792 B (0.238 GB; 0.222 GiB) |
| .png | 3,599 | 196,756,114 B (0.197 GB; 0.183 GiB) | 196,756,114 B (0.197 GB; 0.183 GiB) |
| .dll | 16 | 137,327,088 B (0.137 GB; 0.128 GiB) | 137,327,088 B (0.137 GB; 0.128 GiB) |
| .jar | 101 | 106,745,638 B (0.107 GB; 0.099 GiB) | 106,745,638 B (0.107 GB; 0.099 GiB) |
| .wav | 97 | 93,073,836 B (0.093 GB; 0.087 GiB) | 93,073,836 B (0.093 GB; 0.087 GiB) |
| .sym | 12 | 91,492,636 B (0.091 GB; 0.085 GiB) | 91,492,636 B (0.091 GB; 0.085 GiB) |
| .o | 114 | 86,647,628 B (0.087 GB; 0.081 GiB) | 86,647,628 B (0.087 GB; 0.081 GiB) |
| .a | 15 | 85,356,072 B (0.085 GB; 0.079 GiB) | 85,356,072 B (0.085 GB; 0.079 GiB) |
| [no extension] | 427 | 52,010,501 B (0.052 GB; 0.048 GiB) | 52,010,501 B (0.052 GB; 0.048 GiB) |
| .dex | 313 | 38,385,452 B (0.038 GB; 0.036 GiB) | 38,385,452 B (0.038 GB; 0.036 GiB) |
| .zip | 2 | 34,731,473 B (0.035 GB; 0.032 GiB) | 34,731,473 B (0.035 GB; 0.032 GiB) |
| .dat | 1,073 | 30,323,717 B (0.030 GB; 0.028 GiB) | 30,323,717 B (0.030 GB; 0.028 GiB) |
| .txt | 900 | 29,548,773 B (0.030 GB; 0.028 GiB) | 29,548,773 B (0.030 GB; 0.028 GiB) |
| .pyd | 30 | 22,275,072 B (0.022 GB; 0.021 GiB) | 22,275,072 B (0.022 GB; 0.021 GiB) |
| .pyc | 662 | 16,988,269 B (0.017 GB; 0.016 GiB) | 16,988,269 B (0.017 GB; 0.016 GiB) |
| .xml | 1,668 | 13,328,750 B (0.013 GB; 0.012 GiB) | 13,328,750 B (0.013 GB; 0.012 GiB) |
| .py | 751 | 12,084,467 B (0.012 GB; 0.011 GiB) | 12,084,467 B (0.012 GB; 0.011 GiB) |
| .cpp | 311 | 11,474,484 B (0.011 GB; 0.011 GiB) | 11,474,484 B (0.011 GB; 0.011 GiB) |
| .partial | 8 | 10,499,072 B (0.010 GB; 0.010 GiB) | 10,499,072 B (0.010 GB; 0.010 GiB) |
| .tsv | 19 | 10,312,066 B (0.010 GB; 0.010 GiB) | 10,312,066 B (0.010 GB; 0.010 GiB) |
| .jsonl | 49 | 8,246,692 B (0.008 GB; 0.008 GiB) | 8,246,692 B (0.008 GB; 0.008 GiB) |
| .pack | 2 | 8,203,801 B (0.008 GB; 0.008 GiB) | 8,203,801 B (0.008 GB; 0.008 GiB) |
| .h | 259 | 7,072,845 B (0.007 GB; 0.007 GiB) | 7,072,845 B (0.007 GB; 0.007 GiB) |
| .otf | 7 | 4,942,016 B (0.005 GB; 0.005 GiB) | 4,942,016 B (0.005 GB; 0.005 GiB) |
| .ap_ | 17 | 4,898,997 B (0.005 GB; 0.005 GiB) | 4,898,997 B (0.005 GB; 0.005 GiB) |
| .c | 179 | 4,637,102 B (0.005 GB; 0.004 GiB) | 4,637,102 B (0.005 GB; 0.004 GiB) |
| .ttf | 14 | 4,163,644 B (0.004 GB; 0.004 GiB) | 4,163,644 B (0.004 GB; 0.004 GiB) |
| .class | 401 | 3,052,378 B (0.003 GB; 0.003 GiB) | 3,052,378 B (0.003 GB; 0.003 GiB) |
| .prt | 1 | 2,549,900 B (0.003 GB; 0.002 GiB) | 2,549,900 B (0.003 GB; 0.002 GiB) |
| .model | 1 | 2,423,393 B (0.002 GB; 0.002 GiB) | 2,423,393 B (0.002 GB; 0.002 GiB) |
| .gif | 13 | 2,138,123 B (0.002 GB; 0.002 GiB) | 2,138,123 B (0.002 GB; 0.002 GiB) |
| .tab_i | 48 | 1,900,544 B (0.002 GB; 0.002 GiB) | 1,900,544 B (0.002 GB; 0.002 GiB) |
| .cl | 182 | 1,814,192 B (0.002 GB; 0.002 GiB) | 1,814,192 B (0.002 GB; 0.002 GiB) |
| .flat | 460 | 1,756,772 B (0.002 GB; 0.002 GiB) | 1,756,772 B (0.002 GB; 0.002 GiB) |
| .hpp | 80 | 1,694,679 B (0.002 GB; 0.002 GiB) | 1,694,679 B (0.002 GB; 0.002 GiB) |
| .pyi | 272 | 1,643,670 B (0.002 GB; 0.002 GiB) | 1,643,670 B (0.002 GB; 0.002 GiB) |
| .exe | 12 | 1,625,997 B (0.002 GB; 0.002 GiB) | 1,625,997 B (0.002 GB; 0.002 GiB) |
| .keystream | 56 | 1,605,632 B (0.002 GB; 0.001 GiB) | 1,605,632 B (0.002 GB; 0.001 GiB) |
| .csv | 30 | 1,391,679 B (0.001 GB; 0.001 GiB) | 1,391,679 B (0.001 GB; 0.001 GiB) |
| .cu | 190 | 1,173,358 B (0.001 GB; 0.001 GiB) | 1,173,358 B (0.001 GB; 0.001 GiB) |
| .js | 14 | 1,164,334 B (0.001 GB; 0.001 GiB) | 1,164,334 B (0.001 GB; 0.001 GiB) |
| .values | 11 | 1,139,786 B (0.001 GB; 0.001 GiB) | 1,139,786 B (0.001 GB; 0.001 GiB) |
| .cuh | 91 | 994,810 B (0.001 GB; 0.001 GiB) | 994,810 B (0.001 GB; 0.001 GiB) |
| .globals | 398 | 706,450 B (0.001 GB; 0.001 GiB) | 706,450 B (0.001 GB; 0.001 GiB) |
| .z | 7 | 693,518 B (0.001 GB; 0.001 GiB) | 693,518 B (0.001 GB; 0.001 GiB) |
| .metal | 37 | 655,668 B (0.001 GB; 0.001 GiB) | 655,668 B (0.001 GB; 0.001 GiB) |
| .patch | 3 | 645,047 B (0.001 GB; 0.001 GiB) | 645,047 B (0.001 GB; 0.001 GiB) |
| .md | 58 | 614,063 B (0.001 GB; 0.001 GiB) | 614,063 B (0.001 GB; 0.001 GiB) |
| .comp | 162 | 610,124 B (0.001 GB; 0.001 GiB) | 610,124 B (0.001 GB; 0.001 GiB) |
| .at | 56 | 578,322 B (0.001 GB; 0.001 GiB) | 578,322 B (0.001 GB; 0.001 GiB) |
| .tab | 60 | 442,385 B (0.000 GB; 0.000 GiB) | 442,385 B (0.000 GB; 0.000 GiB) |
| .frag | 21 | 404,376 B (0.000 GB; 0.000 GiB) | 404,376 B (0.000 GB; 0.000 GiB) |
| .ninja | 6 | 399,769 B (0.000 GB; 0.000 GiB) | 399,769 B (0.000 GB; 0.000 GiB) |
| .lib | 21 | 393,706 B (0.000 GB; 0.000 GiB) | 393,706 B (0.000 GB; 0.000 GiB) |
| .glsl | 30 | 392,335 B (0.000 GB; 0.000 GiB) | 392,335 B (0.000 GB; 0.000 GiB) |
| .cxx | 1 | 392,122 B (0.000 GB; 0.000 GiB) | 392,122 B (0.000 GB; 0.000 GiB) |
| .d | 5 | 379,422 B (0.000 GB; 0.000 GiB) | 379,422 B (0.000 GB; 0.000 GiB) |
| .html | 32 | 359,929 B (0.000 GB; 0.000 GiB) | 359,929 B (0.000 GB; 0.000 GiB) |
| .sh | 41 | 240,740 B (0.000 GB; 0.000 GiB) | 240,740 B (0.000 GB; 0.000 GiB) |
| .wgsl | 43 | 232,007 B (0.000 GB; 0.000 GiB) | 232,007 B (0.000 GB; 0.000 GiB) |
| .tmpl | 7 | 227,816 B (0.000 GB; 0.000 GiB) | 227,816 B (0.000 GB; 0.000 GiB) |
| .java | 47 | 216,532 B (0.000 GB; 0.000 GiB) | 216,532 B (0.000 GB; 0.000 GiB) |
| .cmake | 65 | 195,797 B (0.000 GB; 0.000 GiB) | 195,797 B (0.000 GB; 0.000 GiB) |
| .m | 9 | 160,445 B (0.000 GB; 0.000 GiB) | 160,445 B (0.000 GB; 0.000 GiB) |
| .jpg | 39 | 127,391 B (0.000 GB; 0.000 GiB) | 127,391 B (0.000 GB; 0.000 GiB) |
| .pxd | 7 | 108,402 B (0.000 GB; 0.000 GiB) | 108,402 B (0.000 GB; 0.000 GiB) |
| .gz | 4 | 108,117 B (0.000 GB; 0.000 GiB) | 108,117 B (0.000 GB; 0.000 GiB) |
| .yml | 23 | 100,291 B (0.000 GB; 0.000 GiB) | 100,291 B (0.000 GB; 0.000 GiB) |
| .dart | 12 | 92,225 B (0.000 GB; 0.000 GiB) | 92,225 B (0.000 GB; 0.000 GiB) |
| .rb | 33 | 79,620 B (0.000 GB; 0.000 GiB) | 79,620 B (0.000 GB; 0.000 GiB) |
| .mp3 | 1 | 76,447 B (0.000 GB; 0.000 GiB) | 76,447 B (0.000 GB; 0.000 GiB) |
| .i | 1 | 74,660 B (0.000 GB; 0.000 GiB) | 74,660 B (0.000 GB; 0.000 GiB) |
| .ini | 68 | 72,065 B (0.000 GB; 0.000 GiB) | 72,065 B (0.000 GB; 0.000 GiB) |
| .go | 18 | 68,196 B (0.000 GB; 0.000 GiB) | 68,196 B (0.000 GB; 0.000 GiB) |
| .idx | 2 | 67,412 B (0.000 GB; 0.000 GiB) | 67,412 B (0.000 GB; 0.000 GiB) |
| .sample | 28 | 51,654 B (0.000 GB; 0.000 GiB) | 51,654 B (0.000 GB; 0.000 GiB) |
| .pbxproj | 2 | 42,794 B (0.000 GB; 0.000 GiB) | 42,794 B (0.000 GB; 0.000 GiB) |
| .rbs | 1 | 34,593 B (0.000 GB; 0.000 GiB) | 34,593 B (0.000 GB; 0.000 GiB) |
| .properties | 33 | 34,280 B (0.000 GB; 0.000 GiB) | 34,280 B (0.000 GB; 0.000 GiB) |
| .aar | 3 | 32,380 B (0.000 GB; 0.000 GiB) | 32,380 B (0.000 GB; 0.000 GiB) |
| .kt | 12 | 31,009 B (0.000 GB; 0.000 GiB) | 31,009 B (0.000 GB; 0.000 GiB) |
| .f90 | 61 | 30,581 B (0.000 GB; 0.000 GiB) | 30,581 B (0.000 GB; 0.000 GiB) |
| .swift | 8 | 27,839 B (0.000 GB; 0.000 GiB) | 27,839 B (0.000 GB; 0.000 GiB) |
| .bat | 22 | 20,621 B (0.000 GB; 0.000 GiB) | 20,621 B (0.000 GB; 0.000 GiB) |
| .uniqueid4 | 1 | 20,440 B (0.000 GB; 0.000 GiB) | 20,440 B (0.000 GB; 0.000 GiB) |
| .pyx | 4 | 17,843 B (0.000 GB; 0.000 GiB) | 17,843 B (0.000 GB; 0.000 GiB) |
| .vim | 1 | 16,268 B (0.000 GB; 0.000 GiB) | 16,268 B (0.000 GB; 0.000 GiB) |
| .in | 14 | 14,349 B (0.000 GB; 0.000 GiB) | 14,349 B (0.000 GB; 0.000 GiB) |
| .uniqueid0 | 1 | 12,775 B (0.000 GB; 0.000 GiB) | 12,775 B (0.000 GB; 0.000 GiB) |
| .gradle | 9 | 12,472 B (0.000 GB; 0.000 GiB) | 12,472 B (0.000 GB; 0.000 GiB) |
| .css | 6 | 11,667 B (0.000 GB; 0.000 GiB) | 11,667 B (0.000 GB; 0.000 GiB) |
| .f | 24 | 11,332 B (0.000 GB; 0.000 GiB) | 11,332 B (0.000 GB; 0.000 GiB) |
| .m4 | 1 | 11,048 B (0.000 GB; 0.000 GiB) | 11,048 B (0.000 GB; 0.000 GiB) |
| .pb | 2 | 10,930 B (0.000 GB; 0.000 GiB) | 10,930 B (0.000 GB; 0.000 GiB) |
| .storyboard | 2 | 10,211 B (0.000 GB; 0.000 GiB) | 10,211 B (0.000 GB; 0.000 GiB) |
| .rst | 1 | 10,110 B (0.000 GB; 0.000 GiB) | 10,110 B (0.000 GB; 0.000 GiB) |
| .rev | 2 | 9,428 B (0.000 GB; 0.000 GiB) | 9,428 B (0.000 GB; 0.000 GiB) |
| .dockerfile | 7 | 9,094 B (0.000 GB; 0.000 GiB) | 9,094 B (0.000 GB; 0.000 GiB) |
| .dm | 6 | 9,057 B (0.000 GB; 0.000 GiB) | 9,057 B (0.000 GB; 0.000 GiB) |
| .fits | 1 | 8,640 B (0.000 GB; 0.000 GiB) | 8,640 B (0.000 GB; 0.000 GiB) |
| .srt | 13 | 7,902 B (0.000 GB; 0.000 GiB) | 7,902 B (0.000 GB; 0.000 GiB) |
| .ps1 | 2 | 7,022 B (0.000 GB; 0.000 GiB) | 7,022 B (0.000 GB; 0.000 GiB) |
| .0 | 2 | 6,664 B (0.000 GB; 0.000 GiB) | 6,664 B (0.000 GB; 0.000 GiB) |
| .cmd | 3 | 6,567 B (0.000 GB; 0.000 GiB) | 6,567 B (0.000 GB; 0.000 GiB) |
| .mk | 4 | 5,466 B (0.000 GB; 0.000 GiB) | 5,466 B (0.000 GB; 0.000 GiB) |
| .build | 3 | 4,783 B (0.000 GB; 0.000 GiB) | 4,783 B (0.000 GB; 0.000 GiB) |
| .yaml | 1 | 4,559 B (0.000 GB; 0.000 GiB) | 4,559 B (0.000 GB; 0.000 GiB) |
| .xcscheme | 1 | 3,996 B (0.000 GB; 0.000 GiB) | 3,996 B (0.000 GB; 0.000 GiB) |
| .ac | 1 | 3,907 B (0.000 GB; 0.000 GiB) | 3,907 B (0.000 GB; 0.000 GiB) |
| .am | 1 | 3,840 B (0.000 GB; 0.000 GiB) | 3,840 B (0.000 GB; 0.000 GiB) |
| .gbnf | 3 | 3,711 B (0.000 GB; 0.000 GiB) | 3,711 B (0.000 GB; 0.000 GiB) |
| .stamp | 4 | 3,709 B (0.000 GB; 0.000 GiB) | 3,709 B (0.000 GB; 0.000 GiB) |
| .cfg | 2 | 3,412 B (0.000 GB; 0.000 GiB) | 3,412 B (0.000 GB; 0.000 GiB) |
| .pyf | 7 | 2,433 B (0.000 GB; 0.000 GiB) | 2,433 B (0.000 GB; 0.000 GiB) |
| .pc | 7 | 2,304 B (0.000 GB; 0.000 GiB) | 2,304 B (0.000 GB; 0.000 GiB) |
| .mm | 1 | 2,297 B (0.000 GB; 0.000 GiB) | 2,297 B (0.000 GB; 0.000 GiB) |
| .nvim | 1 | 2,083 B (0.000 GB; 0.000 GiB) | 2,083 B (0.000 GB; 0.000 GiB) |
| .unicode | 1 | 2,033 B (0.000 GB; 0.000 GiB) | 2,033 B (0.000 GB; 0.000 GiB) |
| .template | 1 | 1,855 B (0.000 GB; 0.000 GiB) | 1,855 B (0.000 GB; 0.000 GiB) |
| .ld | 1 | 1,814 B (0.000 GB; 0.000 GiB) | 1,814 B (0.000 GB; 0.000 GiB) |
| .uniqueid2 | 1 | 1,770 B (0.000 GB; 0.000 GiB) | 1,770 B (0.000 GB; 0.000 GiB) |
| .pro | 2 | 1,540 B (0.000 GB; 0.000 GiB) | 1,540 B (0.000 GB; 0.000 GiB) |
| .sum | 1 | 1,398 B (0.000 GB; 0.000 GiB) | 1,398 B (0.000 GB; 0.000 GiB) |
| .len | 168 | 1,344 B (0.000 GB; 0.000 GiB) | 1,344 B (0.000 GB; 0.000 GiB) |
| .plist | 3 | 1,325 B (0.000 GB; 0.000 GiB) | 1,325 B (0.000 GB; 0.000 GiB) |
| .gemspec | 1 | 1,198 B (0.000 GB; 0.000 GiB) | 1,198 B (0.000 GB; 0.000 GiB) |
| .uniqueid3 | 1 | 1,055 B (0.000 GB; 0.000 GiB) | 1,055 B (0.000 GB; 0.000 GiB) |
| .npy | 5 | 1,033 B (0.000 GB; 0.000 GiB) | 1,033 B (0.000 GB; 0.000 GiB) |
| .prof | 1 | 1,032 B (0.000 GB; 0.000 GiB) | 1,032 B (0.000 GB; 0.000 GiB) |
| .npz | 2 | 819 B (0.000 GB; 0.000 GiB) | 819 B (0.000 GB; 0.000 GiB) |
| .kotlin_module | 8 | 792 B (0.000 GB; 0.000 GiB) | 792 B (0.000 GB; 0.000 GiB) |
| .inf | 1 | 790 B (0.000 GB; 0.000 GiB) | 790 B (0.000 GB; 0.000 GiB) |
| .s | 12 | 767 B (0.000 GB; 0.000 GiB) | 767 B (0.000 GB; 0.000 GiB) |
| .pkl | 1 | 716 B (0.000 GB; 0.000 GiB) | 716 B (0.000 GB; 0.000 GiB) |
| .idl | 1 | 698 B (0.000 GB; 0.000 GiB) | 698 B (0.000 GB; 0.000 GiB) |
| .icc | 1 | 480 B (0.000 GB; 0.000 GiB) | 480 B (0.000 GB; 0.000 GiB) |
| .uniqueid1 | 1 | 478 B (0.000 GB; 0.000 GiB) | 478 B (0.000 GB; 0.000 GiB) |
| .mod | 1 | 396 B (0.000 GB; 0.000 GiB) | 396 B (0.000 GB; 0.000 GiB) |
| .entitlements | 1 | 381 B (0.000 GB; 0.000 GiB) | 381 B (0.000 GB; 0.000 GiB) |
| .sha1 | 9 | 360 B (0.000 GB; 0.000 GiB) | 360 B (0.000 GB; 0.000 GiB) |
| .check_cache | 3 | 258 B (0.000 GB; 0.000 GiB) | 258 B (0.000 GB; 0.000 GiB) |
| .profm | 1 | 179 B (0.000 GB; 0.000 GiB) | 179 B (0.000 GB; 0.000 GiB) |
| .f95 | 1 | 144 B (0.000 GB; 0.000 GiB) | 144 B (0.000 GB; 0.000 GiB) |
| .xcworkspacedata | 1 | 142 B (0.000 GB; 0.000 GiB) | 142 B (0.000 GB; 0.000 GiB) |
| .lock | 20 | 136 B (0.000 GB; 0.000 GiB) | 136 B (0.000 GB; 0.000 GiB) |
| .cache | 12 | 120 B (0.000 GB; 0.000 GiB) | 120 B (0.000 GB; 0.000 GiB) |
| .stop | 2 | 100 B (0.000 GB; 0.000 GiB) | 100 B (0.000 GB; 0.000 GiB) |
| .typed | 3 | 59 B (0.000 GB; 0.000 GiB) | 59 B (0.000 GB; 0.000 GiB) |
| .textproto | 1 | 46 B (0.000 GB; 0.000 GiB) | 46 B (0.000 GB; 0.000 GiB) |
| .last | 1 | 42 B (0.000 GB; 0.000 GiB) | 42 B (0.000 GB; 0.000 GiB) |
| .inc | 1 | 17 B (0.000 GB; 0.000 GiB) | 17 B (0.000 GB; 0.000 GiB) |
| .x | 4 | 0 B (0.000 GB; 0.000 GiB) | 0 B (0.000 GB; 0.000 GiB) |
| .alive | 2 | 0 B (0.000 GB; 0.000 GiB) | 0 B (0.000 GB; 0.000 GiB) |
| .lck | 1 | 0 B (0.000 GB; 0.000 GiB) | 0 B (0.000 GB; 0.000 GiB) |

### APK/AAB, intermediates, logs, screenshots/media

| Artifact group | Files | Logical | Allocated |
| --- | --- | --- | --- |
| Other | 11,363 | 113,549,520,492 B (113.550 GB; 105.751 GiB) | 113,084,608,108 B (113.085 GB; 105.318 GiB) |
| Recovery artifacts | 284 | 11,766,909,891 B (11.767 GB; 10.959 GiB) | 11,766,909,891 B (11.767 GB; 10.959 GiB) |
| APK/AAB | 247 | 8,780,566,620 B (8.781 GB; 8.178 GiB) | 8,780,566,620 B (8.781 GB; 8.178 GiB) |
| Android/native intermediates | 1,052 | 3,039,018,256 B (3.039 GB; 2.830 GiB) | 3,039,018,256 B (3.039 GB; 2.830 GiB) |
| Test/performance fixtures | 74 | 718,894,825 B (0.719 GB; 0.670 GiB) | 718,894,825 B (0.719 GB; 0.670 GiB) |
| Logs | 1,288 | 354,786,203 B (0.355 GB; 0.330 GiB) | 354,786,203 B (0.355 GB; 0.330 GiB) |
| Video/audio | 491 | 331,395,075 B (0.331 GB; 0.309 GiB) | 331,395,075 B (0.331 GB; 0.309 GiB) |
| Images/screenshots | 3,638 | 196,883,505 B (0.197 GB; 0.183 GiB) | 196,883,505 B (0.197 GB; 0.183 GiB) |

| Logs/media/archive/fixture group | Files | Logical | Allocated |
| --- | --- | --- | --- |
| Logs | 1,288 | 354,786,203 B (0.355 GB; 0.330 GiB) | 354,786,203 B (0.355 GB; 0.330 GiB) |
| Images/screenshots | 3,638 | 196,883,505 B (0.197 GB; 0.183 GiB) | 196,883,505 B (0.197 GB; 0.183 GiB) |
| Video/audio | 491 | 331,395,075 B (0.331 GB; 0.309 GiB) | 331,395,075 B (0.331 GB; 0.309 GiB) |
| Performance/test fixtures | 237 | 848,221,477 B (0.848 GB; 0.790 GiB) | 848,221,477 B (0.848 GB; 0.790 GiB) |
| Archives/backups | 138 | 13,303,893,767 B (13.304 GB; 12.390 GiB) | 13,303,893,767 B (13.304 GB; 12.390 GiB) |

### TASK07/TASK08/TASK09/TASK09B

Path-marker attribution; TASK09B checked before TASK09. Shared verification paths stay unattributed; not proof that file serves only one task.

| Task bucket | Files | Logical | Allocated |
| --- | --- | --- | --- |
| TASK07 | 4,126 | 18,079,537,624 B (18.080 GB; 16.838 GiB) | 17,933,720,024 B (17.934 GB; 16.702 GiB) |
| TASK08 | 3,400 | 66,668,288,033 B (66.668 GB; 62.090 GiB) | 66,604,455,969 B (66.604 GB; 62.030 GiB) |
| TASK09 | 611 | 12,322,960,681 B (12.323 GB; 11.477 GiB) | 12,259,128,617 B (12.259 GB; 11.417 GiB) |
| TASK09B | 2,496 | 18,562,384,891 B (18.562 GB; 17.288 GiB) | 18,498,618,363 B (18.499 GB; 17.228 GiB) |
| Shared/unattributed | 7,804 | 23,104,803,638 B (23.105 GB; 21.518 GiB) | 22,977,139,510 B (22.977 GB; 21.399 GiB) |

## 7. Android AVD disks/snapshots

Only metadata stat. No boot, ADB, guest image access, QA5560/5554 interaction. AVD/QA state is PROTECTED. QA5560 association for build/task021_avd comes from prior TASK08 report; live guest/checkpoint integrity was not verified.

| AVD/path group | Logical | Allocated | Files | Disk files | Classification |
| --- | --- | --- | --- | --- | --- |
| verification/task08/avds/ThreeHRecorder_TASK08_API36.avd | 12,327,579,028 B (12.328 GB; 11.481 GiB) | 12,263,746,964 B (12.264 GB; 11.422 GiB) | 24 | 7 | PROTECTED; guest state not inspected |
| verification/task09b/run_20261109T113727956224Z_f64203/avds/ThreeHRecorder_TASK09B_API36.avd | 12,209,876,622 B (12.210 GB; 11.371 GiB) | 12,146,110,094 B (12.146 GB; 11.312 GiB) | 23 | 7 | PROTECTED; guest state not inspected |
| verification/task07/avds/ThreeHRecorder_TASK07_API34_Clone.avd | 9,981,625,758 B (9.982 GB; 9.296 GiB) | 9,899,640,222 B (9.900 GB; 9.220 GiB) | 23 | 7 | PROTECTED; guest state not inspected |
| verification/task09/avds/ThreeHRecorder_TASK09_API36.avd | 9,773,379,055 B (9.773 GB; 9.102 GiB) | 9,709,546,991 B (9.710 GB; 9.043 GiB) | 22 | 7 | PROTECTED; guest state not inspected |
| task021_avd/ThreeHRecorder_Task021.avd | 9,768,988,443 B (9.769 GB; 9.098 GiB) | 9,705,156,379 B (9.705 GB; 9.039 GiB) | 31 | 7 | PROTECTED; guest state not inspected |
| verification/task08/offline_checkpoint_v2_20261109T041649Z_140e2301/ThreeHRecorder_TASK08_API36.avd | 9,258,397,076 B (9.258 GB; 8.623 GiB) | 9,258,397,076 B (9.258 GB; 8.623 GiB) | 24 | 7 | PROTECTED; guest state not inspected |
| verification/task08/offline_checkpoint_v2_20261109T040853Z_4d4ea6d8/ThreeHRecorder_TASK08_API36.avd | 9,146,789,268 B (9.147 GB; 8.519 GiB) | 9,146,789,268 B (9.147 GB; 8.519 GiB) | 24 | 7 | PROTECTED; guest state not inspected |
| verification/task08/offline_checkpoint_v2_20261109T034847Z_fa387232/ThreeHRecorder_TASK08_API36.avd | 8,698,654,100 B (8.699 GB; 8.101 GiB) | 8,698,654,100 B (8.699 GB; 8.101 GiB) | 24 | 7 | PROTECTED; guest state not inspected |
| verification/task08/offline_checkpoint_v2_20261109T034457Z_f0393303/ThreeHRecorder_TASK08_API36.avd | 8,683,842,962 B (8.684 GB; 8.087 GiB) | 8,683,842,962 B (8.684 GB; 8.087 GiB) | 24 | 7 | PROTECTED; guest state not inspected |
| verification/task08/offline_checkpoint_v1_20261108T095427Z_10b59617/ThreeHRecorder_TASK08_API36.avd | 8,592,616,852 B (8.593 GB; 8.002 GiB) | 8,592,616,852 B (8.593 GB; 8.002 GiB) | 23 | 7 | PROTECTED; guest state not inspected |
| verification/task07/avds/ThreeHRecorder_TASK07_16KB.avd | 6,508,576,185 B (6.509 GB; 6.062 GiB) | 6,444,744,121 B (6.445 GB; 6.002 GiB) | 24 | 7 | PROTECTED; guest state not inspected |
| final_api34_avd/ThreeHRecorder_Final_API34.avd | 5,485,528,442 B (5.486 GB; 5.109 GiB) | 5,421,696,378 B (5.422 GB; 5.049 GiB) | 24 | 7 | PROTECTED; guest state not inspected |
| verification/task08/new_avd_stderr.log | 11,772,818 B (0.012 GB; 0.011 GiB) | 11,772,818 B (0.012 GB; 0.011 GiB) | 1 | 0 | PROTECTED; guest state not inspected |
| task021_avd | 235,706 B (0.000 GB; 0.000 GiB) | 235,706 B (0.000 GB; 0.000 GiB) | 7 | 0 | PROTECTED; guest state not inspected |
| task03/ffmpeg/avdevice-60.dll | 139,776 B (0.000 GB; 0.000 GiB) | 139,776 B (0.000 GB; 0.000 GiB) | 1 | 0 | PROTECTED; guest state not inspected |
| verification/task08/new_avd_seed.json | 55,706 B (0.000 GB; 0.000 GiB) | 55,706 B (0.000 GB; 0.000 GiB) | 1 | 0 | PROTECTED; guest state not inspected |
| verification/final_p2_p3/qa_avd_stdout.log | 24,718 B (0.000 GB; 0.000 GiB) | 24,718 B (0.000 GB; 0.000 GiB) | 1 | 0 | PROTECTED; guest state not inspected |
| verification/task08/new_avd_stdout.log | 23,418 B (0.000 GB; 0.000 GiB) | 23,418 B (0.000 GB; 0.000 GiB) | 1 | 0 | PROTECTED; guest state not inspected |
| verification/final_p2_p3/qa_avd_stderr.log | 8,192 B (0.000 GB; 0.000 GiB) | 8,192 B (0.000 GB; 0.000 GiB) | 1 | 0 | PROTECTED; guest state not inspected |
| verification/task08/checkpoint_avd_v2.py | 4,081 B (0.000 GB; 0.000 GiB) | 4,081 B (0.000 GB; 0.000 GiB) | 1 | 0 | PROTECTED; guest state not inspected |
| verification/task08/checkpoint_avd_v1.py | 3,460 B (0.000 GB; 0.000 GiB) | 3,460 B (0.000 GB; 0.000 GiB) | 1 | 0 | PROTECTED; guest state not inspected |
| verification/task08/prepare_new_avd.py | 1,843 B (0.000 GB; 0.000 GiB) | 1,843 B (0.000 GB; 0.000 GiB) | 1 | 0 | PROTECTED; guest state not inspected |
| verification/final_p2_p3/asr/no_qa_avd_attempt.log | 1,806 B (0.000 GB; 0.000 GiB) | 1,806 B (0.000 GB; 0.000 GiB) | 1 | 0 | PROTECTED; guest state not inspected |
| verification/task07/avds | 656 B (0.000 GB; 0.000 GiB) | 656 B (0.000 GB; 0.000 GiB) | 3 | 0 | PROTECTED; guest state not inspected |
| verification/task08/offline_checkpoint_v2_20261109T041649Z_140e2301/ThreeHRecorder_TASK08_API36.avd.install_claim_v1.json | 243 B (0.000 GB; 0.000 GiB) | 243 B (0.000 GB; 0.000 GiB) | 1 | 0 | PROTECTED; guest state not inspected |
| verification/task08/offline_checkpoint_v2_20261109T040853Z_4d4ea6d8/ThreeHRecorder_TASK08_API36.avd.install_claim_v1.json | 243 B (0.000 GB; 0.000 GiB) | 243 B (0.000 GB; 0.000 GiB) | 1 | 0 | PROTECTED; guest state not inspected |
| verification/task08/offline_checkpoint_v2_20261109T034847Z_fa387232/ThreeHRecorder_TASK08_API36.avd.install_claim_v1.json | 238 B (0.000 GB; 0.000 GiB) | 238 B (0.000 GB; 0.000 GiB) | 1 | 0 | PROTECTED; guest state not inspected |
| verification/task09/avds | 175 B (0.000 GB; 0.000 GiB) | 175 B (0.000 GB; 0.000 GiB) | 1 | 0 | PROTECTED; guest state not inspected |
| verification/task09b/run_20261109T113727956224Z_f64203/avds | 169 B (0.000 GB; 0.000 GiB) | 169 B (0.000 GB; 0.000 GiB) | 1 | 0 | PROTECTED; guest state not inspected |
| verification/task08/avds | 131 B (0.000 GB; 0.000 GiB) | 131 B (0.000 GB; 0.000 GiB) | 1 | 0 | PROTECTED; guest state not inspected |
| final_api34_avd | 123 B (0.000 GB; 0.000 GiB) | 123 B (0.000 GB; 0.000 GiB) | 1 | 0 | PROTECTED; guest state not inspected |
Largest disk-image files, up to 60:

| Path | Logical | Allocated | mtime (UTC) |
| --- | --- | --- | --- |
| verification/task08/avds/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img.qcow2 | 8,992,391,168 B (8.992 GB; 8.375 GiB) | 8,992,391,168 B (8.992 GB; 8.375 GiB) | 2026-11-09 06:15:20 UTC |
| verification/task09b/run_20261109T113727956224Z_f64203/avds/ThreeHRecorder_TASK09B_API36.avd/userdata-qemu.img.qcow2 | 8,875,212,800 B (8.875 GB; 8.266 GiB) | 8,875,278,336 B (8.875 GB; 8.266 GiB) | 2026-11-10 03:40:31 UTC |
| task021_avd/ThreeHRecorder_Task021.avd/userdata-qemu.img.qcow2 | 6,442,909,696 B (6.443 GB; 6.000 GiB) | 6,442,909,696 B (6.443 GB; 6.000 GiB) | 2026-11-08 07:19:59 UTC |
| verification/task09/avds/ThreeHRecorder_TASK09_API36.avd/userdata-qemu.img.qcow2 | 6,438,977,536 B (6.439 GB; 5.997 GiB) | 6,438,977,536 B (6.439 GB; 5.997 GiB) | 2026-11-09 11:21:21 UTC |
| verification/task08/offline_checkpoint_v2_20261109T041649Z_140e2301/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img.qcow2 | 5,923,209,216 B (5.923 GB; 5.516 GiB) | 5,923,209,216 B (5.923 GB; 5.516 GiB) | 2026-11-09 04:17:35 UTC |
| verification/task08/offline_checkpoint_v2_20261109T040853Z_4d4ea6d8/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img.qcow2 | 5,811,666,944 B (5.812 GB; 5.413 GiB) | 5,811,666,944 B (5.812 GB; 5.413 GiB) | 2026-11-09 04:09:18 UTC |
| verification/task08/offline_checkpoint_v2_20261109T034847Z_fa387232/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img.qcow2 | 5,363,662,848 B (5.364 GB; 4.995 GiB) | 5,363,662,848 B (5.364 GB; 4.995 GiB) | 2026-11-09 03:49:08 UTC |
| verification/task08/offline_checkpoint_v2_20261109T034457Z_f0393303/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img.qcow2 | 5,348,917,248 B (5.349 GB; 4.982 GiB) | 5,348,917,248 B (5.349 GB; 4.982 GiB) | 2026-11-09 03:45:19 UTC |
| verification/task08/offline_checkpoint_v1_20261108T095427Z_10b59617/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img.qcow2 | 5,258,215,424 B (5.258 GB; 4.897 GiB) | 5,258,215,424 B (5.258 GB; 4.897 GiB) | 2026-11-08 09:54:49 UTC |
| verification/task07/avds/ThreeHRecorder_TASK07_16KB.avd/userdata-qemu.img.qcow2 | 4,257,415,168 B (4.257 GB; 3.965 GiB) | 4,257,415,168 B (4.257 GB; 3.965 GiB) | 2026-11-09 05:31:36 UTC |
| verification/task07/avds/ThreeHRecorder_TASK07_API34_Clone.avd/userdata-qemu.img.qcow2 | 3,430,285,312 B (3.430 GB; 3.195 GiB) | 3,430,285,312 B (3.430 GB; 3.195 GiB) | 2026-11-09 05:39:15 UTC |
| verification/task07/avds/ThreeHRecorder_TASK07_API34_Clone.avd/userdata-qemu.img | 3,239,641,088 B (3.240 GB; 3.017 GiB) | 3,239,641,088 B (3.240 GB; 3.017 GiB) | 2026-11-07 19:33:54 UTC |
| final_api34_avd/ThreeHRecorder_Final_API34.avd/userdata-qemu.img.qcow2 | 3,239,641,088 B (3.240 GB; 3.017 GiB) | 3,239,641,088 B (3.240 GB; 3.017 GiB) | 2026-11-07 10:47:05 UTC |
| verification/task09b/run_20261109T113727956224Z_f64203/avds/ThreeHRecorder_TASK09B_API36.avd/snapshots/default_boot/ram.img | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 2026-11-09 11:38:45 UTC |
| verification/task09/avds/ThreeHRecorder_TASK09_API36.avd/snapshots/default_boot/ram.img | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 2026-11-09 09:21:19 UTC |
| verification/task08/offline_checkpoint_v2_20261109T041649Z_140e2301/ThreeHRecorder_TASK08_API36.avd/snapshots/default_boot/ram.img | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 2026-11-09 04:16:56 UTC |
| verification/task08/offline_checkpoint_v2_20261109T040853Z_4d4ea6d8/ThreeHRecorder_TASK08_API36.avd/snapshots/default_boot/ram.img | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 2026-11-09 04:09:00 UTC |
| verification/task08/offline_checkpoint_v2_20261109T034847Z_fa387232/ThreeHRecorder_TASK08_API36.avd/snapshots/default_boot/ram.img | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 2026-11-09 03:48:52 UTC |
| verification/task08/offline_checkpoint_v2_20261109T034457Z_f0393303/ThreeHRecorder_TASK08_API36.avd/snapshots/default_boot/ram.img | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 2026-11-09 03:45:03 UTC |
| verification/task08/offline_checkpoint_v1_20261108T095427Z_10b59617/ThreeHRecorder_TASK08_API36.avd/snapshots/default_boot/ram.img | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 2026-11-08 09:54:33 UTC |
| verification/task08/avds/ThreeHRecorder_TASK08_API36.avd/snapshots/default_boot/ram.img | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 2026-11-08 07:18:10 UTC |
| verification/task07/avds/ThreeHRecorder_TASK07_API34_Clone.avd/snapshots/default_boot/ram.img | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 2026-11-09 04:38:54 UTC |
| task021_avd/ThreeHRecorder_Task021.avd/snapshots/default_boot/ram.img | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 2026-11-05 11:45:54 UTC |
| verification/task07/avds/ThreeHRecorder_TASK07_16KB.avd/snapshots/default_boot/ram.img | 2,147,549,184 B (2.148 GB; 2.000 GiB) | 2,147,549,184 B (2.148 GB; 2.000 GiB) | 2026-11-09 05:26:18 UTC |
| final_api34_avd/ThreeHRecorder_Final_API34.avd/snapshots/default_boot/ram.img | 2,147,549,184 B (2.148 GB; 2.000 GiB) | 2,147,549,184 B (2.148 GB; 2.000 GiB) | 2026-11-07 10:22:03 UTC |
| verification/task09b/run_20261109T113727956224Z_f64203/avds/ThreeHRecorder_TASK09B_API36.avd/cache.img | 69,206,016 B (0.069 GB; 0.064 GiB) | 5,373,952 B (0.005 GB; 0.005 GiB) | 2026-11-09 11:38:44 UTC |
| verification/task09/avds/ThreeHRecorder_TASK09_API36.avd/cache.img | 69,206,016 B (0.069 GB; 0.064 GiB) | 5,373,952 B (0.005 GB; 0.005 GiB) | 2026-11-09 09:21:18 UTC |
| verification/task08/offline_checkpoint_v2_20261109T041649Z_140e2301/ThreeHRecorder_TASK08_API36.avd/cache.img | 69,206,016 B (0.069 GB; 0.064 GiB) | 69,206,016 B (0.069 GB; 0.064 GiB) | 2026-11-09 04:16:49 UTC |
| verification/task08/offline_checkpoint_v2_20261109T040853Z_4d4ea6d8/ThreeHRecorder_TASK08_API36.avd/cache.img | 69,206,016 B (0.069 GB; 0.064 GiB) | 69,206,016 B (0.069 GB; 0.064 GiB) | 2026-11-09 04:08:54 UTC |
| verification/task08/offline_checkpoint_v2_20261109T034847Z_fa387232/ThreeHRecorder_TASK08_API36.avd/cache.img | 69,206,016 B (0.069 GB; 0.064 GiB) | 69,206,016 B (0.069 GB; 0.064 GiB) | 2026-11-09 03:48:47 UTC |
| verification/task08/offline_checkpoint_v2_20261109T034457Z_f0393303/ThreeHRecorder_TASK08_API36.avd/cache.img | 69,206,016 B (0.069 GB; 0.064 GiB) | 69,206,016 B (0.069 GB; 0.064 GiB) | 2026-11-09 03:44:57 UTC |
| verification/task08/offline_checkpoint_v1_20261108T095427Z_10b59617/ThreeHRecorder_TASK08_API36.avd/cache.img | 69,206,016 B (0.069 GB; 0.064 GiB) | 69,206,016 B (0.069 GB; 0.064 GiB) | 2026-11-08 09:54:27 UTC |
| verification/task08/avds/ThreeHRecorder_TASK08_API36.avd/cache.img | 69,206,016 B (0.069 GB; 0.064 GiB) | 5,373,952 B (0.005 GB; 0.005 GiB) | 2026-11-08 07:18:10 UTC |
| verification/task07/avds/ThreeHRecorder_TASK07_API34_Clone.avd/cache.img | 69,206,016 B (0.069 GB; 0.064 GiB) | 5,373,952 B (0.005 GB; 0.005 GiB) | 2026-11-07 19:38:59 UTC |
| verification/task07/avds/ThreeHRecorder_TASK07_16KB.avd/cache.img | 69,206,016 B (0.069 GB; 0.064 GiB) | 5,373,952 B (0.005 GB; 0.005 GiB) | 2026-11-07 19:42:15 UTC |
| task021_avd/ThreeHRecorder_Task021.avd/cache.img | 69,206,016 B (0.069 GB; 0.064 GiB) | 5,373,952 B (0.005 GB; 0.005 GiB) | 2026-11-05 10:26:34 UTC |
| final_api34_avd/ThreeHRecorder_Final_API34.avd/cache.img | 69,206,016 B (0.069 GB; 0.064 GiB) | 5,373,952 B (0.005 GB; 0.005 GiB) | 2026-11-07 10:22:02 UTC |
| verification/task09b/run_20261109T113727956224Z_f64203/avds/ThreeHRecorder_TASK09B_API36.avd/encryptionkey.img | 18,874,368 B (0.019 GB; 0.018 GiB) | 18,874,368 B (0.019 GB; 0.018 GiB) | 2025-08-27 00:20:01 UTC |
| verification/task09/avds/ThreeHRecorder_TASK09_API36.avd/encryptionkey.img | 18,874,368 B (0.019 GB; 0.018 GiB) | 18,874,368 B (0.019 GB; 0.018 GiB) | 2025-08-27 00:20:01 UTC |
| verification/task08/offline_checkpoint_v2_20261109T041649Z_140e2301/ThreeHRecorder_TASK08_API36.avd/encryptionkey.img | 18,874,368 B (0.019 GB; 0.018 GiB) | 18,874,368 B (0.019 GB; 0.018 GiB) | 2026-11-09 04:16:50 UTC |
| verification/task08/offline_checkpoint_v2_20261109T040853Z_4d4ea6d8/ThreeHRecorder_TASK08_API36.avd/encryptionkey.img | 18,874,368 B (0.019 GB; 0.018 GiB) | 18,874,368 B (0.019 GB; 0.018 GiB) | 2026-11-09 04:08:54 UTC |
| verification/task08/offline_checkpoint_v2_20261109T034847Z_fa387232/ThreeHRecorder_TASK08_API36.avd/encryptionkey.img | 18,874,368 B (0.019 GB; 0.018 GiB) | 18,874,368 B (0.019 GB; 0.018 GiB) | 2026-11-09 03:48:47 UTC |
| verification/task08/offline_checkpoint_v2_20261109T034457Z_f0393303/ThreeHRecorder_TASK08_API36.avd/encryptionkey.img | 18,874,368 B (0.019 GB; 0.018 GiB) | 18,874,368 B (0.019 GB; 0.018 GiB) | 2026-11-09 03:44:57 UTC |
| verification/task08/offline_checkpoint_v1_20261108T095427Z_10b59617/ThreeHRecorder_TASK08_API36.avd/encryptionkey.img | 18,874,368 B (0.019 GB; 0.018 GiB) | 18,874,368 B (0.019 GB; 0.018 GiB) | 2026-11-08 09:54:28 UTC |
| verification/task08/avds/ThreeHRecorder_TASK08_API36.avd/encryptionkey.img | 18,874,368 B (0.019 GB; 0.018 GiB) | 18,874,368 B (0.019 GB; 0.018 GiB) | 2025-08-27 00:20:01 UTC |
| verification/task07/avds/ThreeHRecorder_TASK07_API34_Clone.avd/encryptionkey.img | 18,874,368 B (0.019 GB; 0.018 GiB) | 720,896 B (0.001 GB; 0.001 GiB) | 2026-11-07 19:33:54 UTC |
| verification/task07/avds/ThreeHRecorder_TASK07_16KB.avd/encryptionkey.img | 18,874,368 B (0.019 GB; 0.018 GiB) | 18,874,368 B (0.019 GB; 0.018 GiB) | 2026-09-09 03:30:53 UTC |
| task021_avd/ThreeHRecorder_Task021.avd/encryptionkey.img | 18,874,368 B (0.019 GB; 0.018 GiB) | 18,874,368 B (0.019 GB; 0.018 GiB) | 2025-08-27 00:20:01 UTC |
| final_api34_avd/ThreeHRecorder_Final_API34.avd/encryptionkey.img | 18,874,368 B (0.019 GB; 0.018 GiB) | 18,874,368 B (0.019 GB; 0.018 GiB) | 2026-04-26 05:21:14 UTC |
| verification/task09b/run_20261109T113727956224Z_f64203/avds/ThreeHRecorder_TASK09B_API36.avd/userdata-qemu.img | 15,794,176 B (0.016 GB; 0.015 GiB) | 15,794,176 B (0.016 GB; 0.015 GiB) | 2026-11-09 11:38:44 UTC |
| verification/task09/avds/ThreeHRecorder_TASK09_API36.avd/userdata-qemu.img | 15,794,176 B (0.016 GB; 0.015 GiB) | 15,794,176 B (0.016 GB; 0.015 GiB) | 2026-11-09 09:21:18 UTC |
| verification/task08/offline_checkpoint_v2_20261109T041649Z_140e2301/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img | 15,794,176 B (0.016 GB; 0.015 GiB) | 15,794,176 B (0.016 GB; 0.015 GiB) | 2026-11-09 04:17:02 UTC |
| verification/task08/offline_checkpoint_v2_20261109T040853Z_4d4ea6d8/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img | 15,794,176 B (0.016 GB; 0.015 GiB) | 15,794,176 B (0.016 GB; 0.015 GiB) | 2026-11-09 04:09:05 UTC |
| verification/task08/offline_checkpoint_v2_20261109T034847Z_fa387232/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img | 15,794,176 B (0.016 GB; 0.015 GiB) | 15,794,176 B (0.016 GB; 0.015 GiB) | 2026-11-09 03:48:58 UTC |
| verification/task08/offline_checkpoint_v2_20261109T034457Z_f0393303/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img | 15,794,176 B (0.016 GB; 0.015 GiB) | 15,794,176 B (0.016 GB; 0.015 GiB) | 2026-11-09 03:45:09 UTC |
| verification/task08/offline_checkpoint_v1_20261108T095427Z_10b59617/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img | 15,794,176 B (0.016 GB; 0.015 GiB) | 15,794,176 B (0.016 GB; 0.015 GiB) | 2026-11-08 09:54:38 UTC |
| verification/task08/avds/ThreeHRecorder_TASK08_API36.avd/userdata-qemu.img | 15,794,176 B (0.016 GB; 0.015 GiB) | 15,794,176 B (0.016 GB; 0.015 GiB) | 2026-11-08 07:18:09 UTC |
| task021_avd/ThreeHRecorder_Task021.avd/encryptionkey.img.qcow2 | 8,126,464 B (0.008 GB; 0.008 GiB) | 8,126,464 B (0.008 GB; 0.008 GiB) | 2026-11-08 06:21:39 UTC |
| verification/task08/offline_checkpoint_v2_20261109T041649Z_140e2301/ThreeHRecorder_TASK08_API36.avd/encryptionkey.img.qcow2 | 7,798,784 B (0.008 GB; 0.007 GiB) | 7,798,784 B (0.008 GB; 0.007 GiB) | 2026-11-09 04:16:50 UTC |
| verification/task08/avds/ThreeHRecorder_TASK08_API36.avd/encryptionkey.img.qcow2 | 7,798,784 B (0.008 GB; 0.007 GiB) | 7,798,784 B (0.008 GB; 0.007 GiB) | 2026-11-09 05:40:12 UTC |

## 8. Protected evidence, recovery and caches

### TASK08 QA5560 recovery ? PROTECTED

- Prior TASK08 report: m0_private_before.tar 805,376 B (payload 705,622 B), 127 private files; 116 projects; 77 ASR jobs; 3 models (Tiny 77,691,713 B; Base 147,951,465 B; Small 190,085,487 B); 54 known external inputs 431,070,187 B. Counts overlap and are not unique-byte totals.
- build/task021_avd/ThreeHRecorder_Task021.avd qcow2 was previously recorded as 6,442,909,696 B, mtime 2026-11-08 07:19:59 UTC. Current report does not open VM; live checkpoint integrity remains unverified.
- Preserve build/verification/task08/followup_20261109T063823024767Z manifests, private/model/external recheck, offline disk identity, journals/drafts/history, incident/failure logs. No payload hashes were computed.
- TASK08 remains PARTIAL because original snapshot is unavailable; SAF permissions need user reauthorization through Android UI as described in recovery report.
### TASK07/08/09/09B ? PROTECTED

- Preserve build/verification/**, QA manifests/reports/APKs, screenshots/videos, fixtures, models, original failure evidence, logs and retained media. These directories mix unique evidence and outputs; not disposable cache.
- Prior TASK09B report: 1,095 original files, 569 evidence files (~2,548,967,105 B), 60 retained fixtures. No QA device queried.
- Do not infer disposability from timestamps for models, media, archives, drafts, journals or evidence.
### Regenerable inventory ? conditional

Only isolated generated-cache roots are considered for future review; none was deleted.

| Narrow path | Logical | Allocated | Files | Latest mtime (UTC) | Condition |
| --- | --- | --- | --- | --- | --- |
| build/app/intermediates | 2,673,769,397 B (2.674 GB; 2.490 GiB) | 2,673,769,397 B (2.674 GB; 2.490 GiB) | 2,974 | 2026-11-10 02:40:23 UTC | Generated cache; check active jobs, evidence and references before any future approved cleanup |
| build/.cxx | 174,725,837 B (0.175 GB; 0.163 GiB) | 174,725,837 B (0.175 GB; 0.163 GiB) | 319 | 2026-11-09 18:36:22 UTC | Generated cache; check active jobs, evidence and references before any future approved cleanup |
| build/app/tmp | 3,148,010 B (0.003 GB; 0.003 GiB) | 3,148,010 B (0.003 GB; 0.003 GiB) | 363 | 2026-11-09 18:36:44 UTC | Generated cache; check active jobs, evidence and references before any future approved cleanup |
| build/native_assets | 45 B (0.000 GB; 0.000 GiB) | 45 B (0.000 GB; 0.000 GiB) | 1 | 2026-11-09 18:27:59 UTC | Generated cache; check active jobs, evidence and references before any future approved cleanup |

Conditional upper bound: **2,851,643,289 B (2.852 GB; 2.656 GiB) allocated / 2,851,643,289 B (2.852 GB; 2.656 GiB) logical**. Removal may require full rebuild and toolchain/dependencies; active jobs and custom contents must be checked.

## 9. Duplicate/obsolete candidates ? unverified

Rows match basename and logical size only. No file-content hashing or exact manifest identity check; these are not proven duplicates or deletion recommendations.

| Basename | Same logical size | Copies | Paths (up to 8) | Identity |
| --- | --- | --- | --- | --- |
| ram.img | 3,221,291,008 B (3.221 GB; 3.000 GiB) | 10 | verification/task09b/run_20261109T113727956224Z_f64203/avds/ThreeHRecorder_TASK09B_API36.avd/snapshots/default_boot/ram.img<br>verification/task09/avds/ThreeHRecorder_TASK09_API36.avd/snapshots/default_boot/ram.img<br>verification/task08/offline_checkpoint_v2_20261109T041649Z_140e2301/ThreeHRecorder_TASK08_API36.avd/snapshots/default_boot/ram.img<br>verification/task08/offline_checkpoint_v2_20261109T040853Z_4d4ea6d8/ThreeHRecorder_TASK08_API36.avd/snapshots/default_boot/ram.img<br>verification/task08/offline_checkpoint_v2_20261109T034847Z_fa387232/ThreeHRecorder_TASK08_API36.avd/snapshots/default_boot/ram.img<br>verification/task08/offline_checkpoint_v2_20261109T034457Z_f0393303/ThreeHRecorder_TASK08_API36.avd/snapshots/default_boot/ram.img<br>verification/task08/offline_checkpoint_v1_20261108T095427Z_10b59617/ThreeHRecorder_TASK08_API36.avd/snapshots/default_boot/ram.img<br>verification/task08/avds/ThreeHRecorder_TASK08_API36.avd/snapshots/default_boot/ram.img | Basename+size only; identity unverified |
| ram.img | 2,147,549,184 B (2.148 GB; 2.000 GiB) | 2 | verification/task07/avds/ThreeHRecorder_TASK07_16KB.avd/snapshots/default_boot/ram.img<br>final_api34_avd/ThreeHRecorder_Final_API34.avd/snapshots/default_boot/ram.img | Basename+size only; identity unverified |
| 3hrecorder-qa-debug.apk | 192,045,080 B (0.192 GB; 0.179 GiB) | 2 | verification/p2_p3/apk/3HRecorder-qa-debug.apk<br>verification/final_p2_p3/apk/3HRecorder-QA-debug.apk | Basename+size only; identity unverified |
| main-debug.apk | 192,044,437 B (0.192 GB; 0.179 GiB) | 2 | task031/main-debug.apk<br>task03/main-debug.apk | Basename+size only; identity unverified |
| ggml-small-q5_1.bin | 190,085,487 B (0.190 GB; 0.177 GiB) | 2 | verification/task08/fixture_stage_v1/ggml-small-q5_1.bin<br>verification/p2_p3/models/ggml-small-q5_1.bin | Basename+size only; identity unverified |
| ggml-base.bin | 147,951,465 B (0.148 GB; 0.138 GiB) | 2 | verification/task08/fixture_stage_v1/ggml-base.bin<br>verification/p2_p3/models/ggml-base.bin | Basename+size only; identity unverified |
| app-debug.apk | 120,020,876 B (0.120 GB; 0.112 GiB) | 2 | app/outputs/flutter-apk/app-debug.apk<br>app/outputs/apk/debug/app-debug.apk | Basename+size only; identity unverified |
| kernel_blob.bin | 79,191,528 B (0.079 GB; 0.074 GiB) | 2 | app/intermediates/flutter/debug/flutter_assets/kernel_blob.bin<br>app/intermediates/assets/debug/mergeDebugAssets/flutter_assets/kernel_blob.bin | Basename+size only; identity unverified |
| ggml-tiny.bin | 77,691,713 B (0.078 GB; 0.072 GiB) | 2 | verification/task08/fixture_stage_v1/ggml-tiny.bin<br>verification/p2_p3/models/ggml-tiny.bin | Basename+size only; identity unverified |
| cache.img | 69,206,016 B (0.069 GB; 0.064 GiB) | 12 | verification/task09b/run_20261109T113727956224Z_f64203/avds/ThreeHRecorder_TASK09B_API36.avd/cache.img<br>verification/task09/avds/ThreeHRecorder_TASK09_API36.avd/cache.img<br>verification/task08/offline_checkpoint_v2_20261109T041649Z_140e2301/ThreeHRecorder_TASK08_API36.avd/cache.img<br>verification/task08/offline_checkpoint_v2_20261109T040853Z_4d4ea6d8/ThreeHRecorder_TASK08_API36.avd/cache.img<br>verification/task08/offline_checkpoint_v2_20261109T034847Z_fa387232/ThreeHRecorder_TASK08_API36.avd/cache.img<br>verification/task08/offline_checkpoint_v2_20261109T034457Z_f0393303/ThreeHRecorder_TASK08_API36.avd/cache.img<br>verification/task08/offline_checkpoint_v1_20261108T095427Z_10b59617/ThreeHRecorder_TASK08_API36.avd/cache.img<br>verification/task08/avds/ThreeHRecorder_TASK08_API36.avd/cache.img | Basename+size only; identity unverified |
| app-x86_64-profile.apk | 38,821,854 B (0.039 GB; 0.036 GiB) | 2 | app/outputs/flutter-apk/app-x86_64-profile.apk<br>app/outputs/apk/profile/app-x86_64-profile.apk | Basename+size only; identity unverified |
| app-arm64-v8a-profile.apk | 37,085,165 B (0.037 GB; 0.035 GiB) | 2 | app/outputs/flutter-apk/app-arm64-v8a-profile.apk<br>app/outputs/apk/profile/app-arm64-v8a-profile.apk | Basename+size only; identity unverified |
| app-armeabi-v7a-profile.apk | 34,037,431 B (0.034 GB; 0.032 GiB) | 2 | app/outputs/flutter-apk/app-armeabi-v7a-profile.apk<br>app/outputs/apk/profile/app-armeabi-v7a-profile.apk | Basename+size only; identity unverified |
| before_private.tar | 23,034,880 B (0.023 GB; 0.021 GiB) | 2 | verification/task08/performance/owned_drift_control_411_v1/before_private.tar<br>verification/task08/performance/owned_after_411_v1/before_private.tar | Basename+size only; identity unverified |
| before_external.tar | 22,729,728 B (0.023 GB; 0.021 GiB) | 4 | verification/task08/performance/owned_drift_control_411_v1/before_external.tar<br>verification/task08/performance/owned_before_320/before_external.tar<br>verification/task08/performance/owned_after_411_v1/before_external.tar<br>verification/task08/memory/library_ar_light_200_v1/before_external.tar | Basename+size only; identity unverified |
| libapp.so | 19,138,824 B (0.019 GB; 0.018 GiB) | 3 | app/intermediates/merged_native_libs/profile/mergeProfileNativeLibs/out/lib/x86_64/libapp.so<br>app/intermediates/merged_jni_libs/profile/mergeProfileJniLibFolders/out/x86_64/libapp.so<br>app/generated/jniLibs/copyJniLibsflutterBuildProfile/x86_64/libapp.so | Basename+size only; identity unverified |
| libapp.so | 19,083,668 B (0.019 GB; 0.018 GiB) | 3 | app/intermediates/merged_native_libs/profile/mergeProfileNativeLibs/out/lib/armeabi-v7a/libapp.so<br>app/intermediates/merged_jni_libs/profile/mergeProfileJniLibFolders/out/armeabi-v7a/libapp.so<br>app/generated/jniLibs/copyJniLibsflutterBuildProfile/armeabi-v7a/libapp.so | Basename+size only; identity unverified |
| libapp.so | 19,068,056 B (0.019 GB; 0.018 GiB) | 3 | app/intermediates/merged_native_libs/profile/mergeProfileNativeLibs/out/lib/arm64-v8a/libapp.so<br>app/intermediates/merged_jni_libs/profile/mergeProfileJniLibFolders/out/arm64-v8a/libapp.so<br>app/generated/jniLibs/copyJniLibsflutterBuildProfile/arm64-v8a/libapp.so | Basename+size only; identity unverified |
| encryptionkey.img | 18,874,368 B (0.019 GB; 0.018 GiB) | 12 | verification/task09b/run_20261109T113727956224Z_f64203/avds/ThreeHRecorder_TASK09B_API36.avd/encryptionkey.img<br>verification/task09/avds/ThreeHRecorder_TASK09_API36.avd/encryptionkey.img<br>verification/task08/offline_checkpoint_v2_20261109T041649Z_140e2301/ThreeHRecorder_TASK08_API36.avd/encryptionkey.img<br>verification/task08/offline_checkpoint_v2_20261109T040853Z_4d4ea6d8/ThreeHRecorder_TASK08_API36.avd/encryptionkey.img<br>verification/task08/offline_checkpoint_v2_20261109T034847Z_fa387232/ThreeHRecorder_TASK08_API36.avd/encryptionkey.img<br>verification/task08/offline_checkpoint_v2_20261109T034457Z_f0393303/ThreeHRecorder_TASK08_API36.avd/encryptionkey.img<br>verification/task08/offline_checkpoint_v1_20261108T095427Z_10b59617/ThreeHRecorder_TASK08_API36.avd/encryptionkey.img<br>verification/task08/avds/ThreeHRecorder_TASK08_API36.avd/encryptionkey.img | Basename+size only; identity unverified |
| libthreeh_whisper.so | 16,441,088 B (0.016 GB; 0.015 GiB) | 3 | app/intermediates/merged_native_libs/profile/mergeProfileNativeLibs/out/lib/arm64-v8a/libthreeh_whisper.so<br>app/intermediates/merged_native_libs/debug/mergeDebugNativeLibs/out/lib/arm64-v8a/libthreeh_whisper.so<br>app/intermediates/cxx/Debug/2r2g364a/obj/arm64-v8a/libthreeh_whisper.so | Basename+size only; identity unverified |

Potential collisions may include ram.img, debug APKs, sdk-fragment.jar and ggml model copies; snapshots/profiles can differ. Require trusted hashes, provenance, signing/profile and reference checks before any future removal.

## 10. Classification summary

| Category | Size | Classification | Recoverable | Risk |
| --- | --- | --- | --- | --- |
| TASK07/08/09/09B evidence, recovery, media/models/fixtures, AVD | See task/AVD tables; paths overlap | PROTECTED | 0 GB approved | Very high: unique recovery/evidence/state loss |
| APK/AAB QA outputs | See artifact/top-file tables | REQUIRED / UNKNOWN | 0 GB verified | High: lose tested artifact or traceability |
| Isolated generated cache | 2,851,643,289 B (2.852 GB; 2.656 GiB) logical / 2,851,643,289 B (2.852 GB; 2.656 GiB) allocated | REGENERABLE conditional | Up to 2.852 after authorization | Medium: rebuild cost/failure or unique cache state |
| Same-name/size candidates | Overlaps other categories | POTENTIALLY REDUNDANT, unverified | 0 GB | High: byte identity not established |
| test_cache, QA tooling, reports, research, tmp, remaining paths | Included in build total | UNKNOWN / mixed | 0 GB | Medium-high: unique test inputs/evidence possible |

## 11. Cleanup candidates ranked by safety

No target is verified safe. This is only a future review order:

1. **Conditional, MEDIUM confidence:** isolated cache roots above, up to 2.852 allocated. Verify active jobs, exact files, no unique evidence, toolchain and user approval. Regenerate using normal build workflow in a separate authorized task. Safe estimate now: 0 GB.
2. **Conditional, LOW confidence:** same-name/size APK or model copies. No recoverable size assigned until hashes, signer/profile, QA references and retention owner confirm. Wrong removal may lose only tested copy.
3. **Exclude from cleanup candidates:** verification, TASK08 recovery, every AVD/snapshot, logs/screenshots/videos, models, fixtures, media, archives, drafts/journals. Preserve.

## 12. Risks/dependencies/authorization

- Metadata size changed ~6.20 GB across earlier snapshots; no cause attributed. Size is not stable.
- QA5560 live guest/checkpoint was not inspected; TASK08 original snapshot remains unavailable.
- SAF external URI permissions may require user action in system picker; follow TASK08 manual recovery instructions.
- Future cleanup needs user approval for exact paths, active process check, manifest/reference and retention audit, and backup for non-regenerable data.
- Git HEAD/status changed during audit. No reset/checkout/restore or corrective mutation was done.

## 13. Future storage strategy

1. Keep recovery evidence/source media in managed persistent storage outside disposable build outputs; manifest source, path, size, ingest hash, timestamp, device and owner.
2. Separate reproducible build products from QA evidence; test tools need explicit output roots, quotas and bounded retention.
3. Reuse QA environment only when authorized; preserve AVD snapshots until disk lineage/checkpoint references are verified.
4. Reuse canonical fixture plus immutable manifest; deduplicate only after content hash and provenance match.
5. Apply bounded retention only to noncritical temp/logs with owner/expiry/review; exclude TASK08 incident data.
6. Future cleanup: inventory -> reference audit -> required backup -> user approves exact paths -> isolated cleanup task -> verify build/QA/evidence manifests.

## 14. Method and limitations

- Read path, directory entries, stat, mtime, link count and allocated-size metadata only. No content read/hash, test/build, ADB or emulator operation.
- Reparse/junction/symlink excluded; directory totals inclusive and path-based. st_nlink>1 count=0; physical uniqueness cannot be fully proven if filesystem link metadata is incomplete.
- Purpose/references are path heuristics and prior task reports, not complete dependency graph. Latest directory mtime means latest descendant file.
- Final enumeration: 25,330 project files; 18,437 build files; traversal errors=0; allocation errors=0; skipped reparse=0.

STORAGE AUDIT: PARTIAL
FILES DELETED: 0
EXISTING FILES MODIFIED: 0
CLEANUP EXECUTED: NO
ESTIMATED SAFE RECOVERY: 0 GB
ESTIMATED CONDITIONAL RECOVERY: 2.852 GB
PROTECTED DATA: PRESERVED / NOT VERIFIED
