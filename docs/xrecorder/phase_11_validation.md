# Phase 11 — Settings, help and support

Removed mock preferences, fake storage paths and livestream controls from Settings. Recording options link to the capability-aware shared form; storage, Trash and export links describe implemented behavior. English and the existing dark theme remain the only offered resources. Release display-name reconciliation remains open.

Added searchable structured guides for recording, protected content/audio, timers, facecam/touch guidance, editing, export, GIF/audio limits, storage, URI access and privacy. Support reports are composed locally with optional image/video attachment (known size up to 25 MB, MIME checked again before handoff). Device diagnostics require explicit consent and preview: version, API, manufacturer/model and ABI only. No logs, identifiers, URI paths, credentials or hidden diagnostics are collected. User-entered text/attachments must be reviewed by the user. Cancellation in the system picker keeps the previous selection. Backing out of this screen discards its unsent draft.

Sharing opens Android's chooser and explicitly does not claim delivery. GitHub opens in the browser without posting report content. No upload service, account or new network permission was introduced.

Validation (2026-11-04): analyzer clean; existing 16 host tests passed plus two support/help tests. Tests verify default diagnostics exclusion, opt-in inclusion, truthful handoff wording and FAQ filtering. API 36 native integration verified bounded diagnostics, empty-report rejection and successful share-sheet launch without choosing a recipient. Physical attachment-provider interoperability, TalkBack and translated layouts remain release checks; no unimplemented language is offered.
