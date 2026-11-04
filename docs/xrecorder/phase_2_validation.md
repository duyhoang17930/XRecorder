# P2 — real media catalog

Implemented app-owned MediaStore queries (Android 10+), app-specific FileProvider media on older Android, persisted SAF folder access, direct-child video/photo catalog, metadata, URI thumbnails, date groups, search, sort, refresh, lifecycle refresh, empty/error/revoked-access states, and app-only storage totals with separate device free space.

No broad media/storage permissions are requested. Folder grants are read-only. Missing media does not fall back to sample files. Detail view performs an actual URI readability check. Playback/actions remain P7.

Validation: analyzer clean; 10 unit/widget tests passed; Android debug APK builds. Android adapter integration checks are recorded below once complete. Full device matrix, cloud document-provider behavior, and reinstallation/revocation on physical devices remain release tests.

Sources informing the native adapter:
- https://developer.android.com/training/data-storage/shared/media
- https://developer.android.com/training/data-storage/shared/documents-files

References: R09, R44, R60–R62, R83, R85–R86. Routes: /videos, /photos, /media/:id. Permissions: persisted user-selected SAF read grants only; app-owned MediaStore queries require no broad permission on Android 10+.

Native verification: `flutter test integration_test/android_foundation_test.dart -d emulator-5554` passed both tests on Pixel_8, Android API 37. This verifies actual preference commit/reload and MediaStore/storage channel behavior without broad permissions. Controller recreation is verified; full Android process-death, populated external SAF folders and revoked grants still require the acceptance/device matrix.
