# Local media and privacy

Recording, screenshots, image edits and video exports run on the device. The app requests Android screen-sharing consent per session. Microphone, notification, camera and overlay access are requested when needed. Protected content and apps that disallow audio capture cannot be bypassed.

On Android 10+, published media is stored in MediaStore under Movies/XRecorder or Pictures/XRecorder. On older versions, output uses app-specific external storage. Projects, preferences, session/export journals and trash are private app data. Uninstall can remove private data and legacy output. The app excludes its private data from automatic cloud backup and device transfer; other apps and device gallery services may independently back up published media according to their settings.

Selected folders/music use read-only Android document grants. External sources are not modified. Drafts retain source references. Trash backups become eligible for cleanup after 24 hours when Trash is opened; permanent deletion is explicit and cannot be undone. Export snapshots remain in the local job history; no server receives them.

Sharing grants temporary read access to the app selected in Android's chooser. Support reports contain entered text and only the attachment and diagnostics the user selects. Diagnostics consist of app version, Android API, manufacturer/model and ABI; no logs, account identifiers or media paths are collected. Reports are not uploaded by this app and chooser launch does not prove delivery. GitHub issues are public and require a separate user submission.

No analytics, ad SDK, account login, transcription upload, or livestream integration is enabled. AI/live integrations are deferred under issue #1 and require new consent/retention/security design before enabling. This document describes the current implementation; a production privacy-policy URL and store disclosures remain release-owner work.
