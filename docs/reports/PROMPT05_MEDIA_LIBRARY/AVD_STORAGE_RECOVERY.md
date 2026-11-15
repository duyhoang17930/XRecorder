# Prompt05B — AVD Storage Recovery

Date: 2026-11-16 (Asia/Bangkok)

## Result

**FINAL: BLOCKED** — the APK update still cannot be installed safely. No storage was deleted or modified. The supported AVD resize path was investigated, but this AVD uses a persistent QCOW2 userdata layer and has a saved snapshot. The resize path can remove the QCOW2 layer; a full rollback copy and owner approval are required before attempting it.

## Environment and capacity

| Field | Observed |
|---|---|
| ADB serial / AVD | `emulator-5554` / `Pixel_7` |
| Device model / Android | `sdk_gphone16k_x86_64`, Android 17, API 37 |
| Emulator | 36.1.9.0 (build 13823996) |
| Git | `main`, HEAD `2a009e679f1ad254bb5d67b5f07880afaa2d9096`; pre-existing dirty Prompt05 work preserved |
| Installed package | `com.xrecorder.xrecorder`, version `0.1.0`, versionCode 1, targetSdk 36 |
| Candidate APK | `build/app/outputs/flutter-apk/app-debug.apk`, 192,047,755 bytes (183.2 MiB) |
| `/data` | 6 GiB configured; 559 MiB at preflight and 558 MiB at final read |
| Host free space | C: 18.27 GiB; D: 18.92 GiB |

The earlier normal `adb install -r` attempt failed with `INSTALL_FAILED_INSUFFICIENT_STORAGE`. No install was retried during this recovery pass because capacity was unchanged.

## Storage consumers

- Android Settings reported 7.4 GB used of 8.0 GB: Apps 4.6 GB, Videos 236 MB, Images 105 MB, Documents 1.7 MB.
- Largest visible app entries included Google Play services (537 MB), Gboard (412 MB), Android System WebView (363 MB), Messages (322 MB), Chrome (319 MB), and 3HRecorder (216 MB).
- Read-only `run-as` inspection from the preceding preflight measured about 94 MiB in 3HRecorder private data, including about 89.7 MiB under `app_flutter`; this is retained app/model data, not disposable residue. Existing projects and Trash fixtures were left untouched.
- Existing verified MediaStore baseline remains 20 app-owned videos and 24 app-owned images. Shared user media, drafts, models, and QA fixtures were not modified.
- A virtual removable volume is mounted with about 510 MB free. It was not used as an install workaround; no proof established that it would solve package staging or the requested `/data` reserve.

## AVD image and resize risk

Read-only AVD configuration shows `disk.dataPartition.size=6G`, `userdata.useQcow2=true`, and snapshot boot/save enabled. `userdata-qemu.img.qcow2` has a 6 GiB virtual size and occupies about 8.70 GiB on the host; its backing file is `userdata-qemu.img`. The AVD directory has 77 files and occupies about 11.74 GiB in total. The retained `snapshots/default_boot/ram.img` is about 2 GiB.

Android Studio documents an editable **Internal Storage** property for an existing AVD. The Android Emulator source also contains an ext4 expansion path for a larger data partition without wiping, but that path runs filesystem repair/resize and may delete `userdata-qemu.img.qcow2` after successful resize. Since the live user-data layer is QCOW2-backed and large, deleting or invalidating it could lose installed-app data, preferences, media references, and QA state. The default-boot snapshot could also be incompatible with the changed partition. Therefore neither `config.ini` nor the disk images were changed.

References:

- [Android Studio: edit existing AVDs and Internal Storage](https://developer.android.com/studio/run/managing-avds)
- [Android Emulator source: userdata resize path](https://android.googlesource.com/platform/external/qemu/%2B/emu-master-dev/android-qemu2-glue/main.cpp)
- [Android Emulator source: ext4 resize helper](https://android.googlesource.com/platform/external/qemu/%2B/refs/heads/emu-master-qemu/android/android-emu/android/filesystems/ext4_resize.cpp)
- [Android Emulator data directory and userdata image](https://developer.android.com/studio/run/emulator-commandline)

## Actions and preservation

- Performed read-only ADB, Android Settings, Git, host disk, and AVD file/config inspection.
- Opened Android Settings storage pages only; no clear/cache action was taken.
- `FILES DELETED: None.` No app install, cache trim, AVD resize, or SAF restore smoke test was performed.
- App data, MediaStore items, drafts/projects, existing SAF grants, AVD snapshots, and recovery files were not intentionally changed. The prior failed install did not replace the installed package.
- SAF smoke test: not run; the Prompt05A APK remains uninstalled.

## Approval-gated recovery proposal

The exact AVD image at risk is:

`C:\Users\dangh\.android\avd\Pixel_7.avd\userdata-qemu.img.qcow2` — 9,338,945,536 logical bytes (about 8.70 GiB allocated), backed by `userdata-qemu.img`.

Risk: the emulator's resize path can remove this overlay. If the overlay contains the current persistent state, loss would affect emulator app data and QA state. The existing `snapshots\default_boot` must also remain preserved and may no longer be loadable against a resized disk.

Rollback plan after owner approval: gracefully stop this AVD; use a sparse-preserving copy to back up the userdata overlay, base image, encryption-key images, and `config.ini` to a dedicated D: backup path, and back up `snapshots/default_boot` to C: temp. Current allocated sizes are about 8.70 GiB for the overlay and 2.01 GiB for the snapshot; estimated post-copy reserves are D: about 10.19 GiB and C: about 16.26 GiB. Verify allocated sizes before continuing and stop if either host reserve would be crossed. Retain all backups and original snapshot files. Use Android Studio Device Manager's supported existing-AVD Internal Storage setting to increase to 9 GiB; cold boot without wiping; verify `/data`, package identity, media counts, projects, preferences, SAF grants, and app startup. If any integrity check fails, stop and restore the original config and userdata images from the verified backups, preserving/restoring the saved snapshot, before further use. Only after successful preservation checks would the in-place APK update and one task-fixture SAF smoke test proceed. This pass did not perform the backup or resize.

This pass stops before that resize because the operation may remove a user-data overlay. No deletion or backup copy was performed.

## Required fields

| Field | Result |
|---|---|
| AVD identity | `Pixel_7`, generic API 37 x86_64 system image |
| Android version | Android 17 / API 37 |
| APK size | 192,047,755 bytes / 183.2 MiB |
| Data free before → after | 559 MiB → 558 MiB (no capacity-changing action) |
| Host free space | C: 18.27 GiB; D: 18.92 GiB |
| Storage consumers | Apps 4.6 GB; Videos 236 MB; Images 105 MB; Documents 1.7 MB |
| Actions performed | Read-only diagnostics and Settings inspection |
| Files deleted | None |
| App data preserved | Yes; no install/clear/resize performed |
| Media/drafts preserved | Yes; no media/project operation performed |
| APK install | Blocked; previous in-place install returned `INSTALL_FAILED_INSUFFICIENT_STORAGE` |
| SAF smoke test | Not run; fix APK is not installed |
| Remaining risk | 558 MiB free is insufficient for reliable Prompt06 work; safe resize requires a complete verified backup and owner approval |
