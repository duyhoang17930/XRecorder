# Phase 7 — Media actions and lifecycle

Implemented native aspect-fit video playback with a real playback clock, zoomable photo preview, URI sharing with ClipData/read grants, ownership-checked rename, app-managed trash, restore and confirmed permanent deletion. External folder media stays read-only; its owning app must handle rename/delete. Share-sheet handoff never claims delivery.

Trash writes and syncs a private copy and atomic metadata before deleting the original. SHA-256 protects restore integrity; restored items get unique names. Failure preserves the backup. Interrupted copies and unjournaled backups become eligible for cleanup after 24 hours; published media is not swept. Trash retention is explicitly described as cleanup on opening Trash after 24 hours, not a guaranteed background deletion deadline. Storage includes private backup/metadata bytes separately from visible library and cache.

Validation (2026-11-04):

- `media_actions_test.dart` passed on API 36: successful rename, duplicate-name/path rejection, source removal after backup, trash accounting, restore with identical PNG bytes, metadata dimensions and permanent deletion.
- `media_preview_test.dart` passed: real four-second capture, native player position 1126 ms / duration 4270 ms / playing true, and successful Android share-sheet launch. No recipient was selected and no delivery was asserted.
- Analyzer clean; 14 host tests passed; Android debug/integration builds succeeded. Initial missing ClipData import was fixed before testing.

Outstanding fault/device checks: force-kill between copy/journal/delete/restore stages, API 24 legacy provider files, low-disk writes, revoked external URI sharing, multi-gigabyte files, physical playback/accessibility and receiving-app read grants. A crash immediately after restore publication can leave a duplicate alongside the backup; originals are preserved.
