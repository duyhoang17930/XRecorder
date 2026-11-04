# Repository audit and Phase 1 decisions

Audited 2026-11-04. Phase numbering follows `docs/IMPLEMENTATION_PHASES.md`, which adapts the master plan to the existing repository.

## Verified baseline

- Flutter 3.47.8, Dart 3.13.7; `go_router` is the sole runtime package. Existing ChangeNotifier/InheritedNotifier state management, shared tokens, Manrope, cards, fields, sheets, and dialogs are retained.
- Android application ID/namespace `com.xrecorder.xrecorder`; label XRecorder. Product spec names 3HRecorder. Release branding remains deferred; no application ID migration is performed.
- Flutter SDK defaults resolve to min SDK 24, compile/target SDK 36. AGP 9.1.0, Kotlin plugin declaration 2.4.0, Gradle 9.3.1, JVM target 17. Release still uses debug signing and is not release-ready.
- Main manifest has a FlutterActivity and no capture service or capture permissions. No permission is added for preferences.
- Media libraries and completion pages are explicitly sample UI. No media query, recording, playback, editing, sharing, live, subtitle backend, or durable jobs exist yet.
- Initial analyzer exposed unsupported `DropdownButtonThemeData` in the baseline. Removed it; shared `StudioDropdownField` already supplies dropdown colors and typography.

## Foundation decisions

- Retain dark charcoal/coral/cyan tokens as the implementation baseline, pending product palette confirmation. English is the only shipped locale; dark is the only shipped theme. Do not offer unimplemented language/theme choices. `AppConfiguration` is the declaration point for future supported resources.
- Keep four existing tab paths (`/videos`, `/photos`, `/editor`, `/settings`) and legacy links. Use `StatefulShellRoute.indexedStack` to retain filter, favorite, search, and scroll state. Recording is a center action. Preview and recording settings remain outside the shell. Add picker/editor/live/help/trash routes when their corresponding phases ship.
- Persist one versioned JSON preferences document through a replaceable `SettingsStore`. The Android adapter uses private SharedPreferences, one serial worker, and off-main-thread synchronous commit so failures can be acknowledged. No new runtime dependency or license is needed. This small preferences-only adapter is not intended for jobs, catalog data, or secrets; use a transactional database in those phases.
- Restore before mounting the production app. Version 0 migrates recognized flat values to version 1. Invalid values fall back/clamp; corrupt and newer documents are preserved until explicit reset. Failed reads/writes are surfaced in Settings with retry/reset controls.
- Domain contracts use typed enums, opaque URIs, immutable session settings, immutable project clip lists, typed failures, trash ownership, and background job states. Sample UI models are explicitly named `SampleMediaItem`. Repositories/native recording implementation belong to subsequent phases.
- Remove the speculative Pro upsell while entitlement policy is undecided. Capture options remain preferences explicitly labelled as pending native implementation.

## Platform work still required

| Capability | Current state | Implementation gate |
| --- | --- | --- |
| Private preferences | Android adapter implemented, no permission | P1 build/restart checks |
| Media catalog and selected folders | No adapter | P2 scoped MediaStore/SAF and version-specific grants |
| Screen recording | No service or permission declarations | P3 current projection/foreground-service consent rules |
| Mic/internal/mixed audio | Preferences only | P4 permission/capability checks; internal capture Android 10+ |
| Notifications/overlay | No controls | P3/P5 foreground notification and optional overlay access |
| Camera, screenshot, annotation | No implementation | P6 permissions and real saved output |
| OAuth, stream keys, uploads | No implementation | Provider decisions and secure storage; never plain preferences |

Supported release device range is not yet certified; SDK 24 is the current build minimum, not proof every planned feature works there. Hardware capture, OEM behavior, codec/license evaluation, privacy policy, signing, monetization, live credentials, and subtitle backend/retention remain gates.

## References used for adapter decisions

- [go_router stateful shell](https://pub.dev/documentation/go_router/latest/go_router/StatefulShellRoute-class.html)
- [Android preferences and background commit guidance](https://developer.android.com/training/data-storage/shared-preferences)

No recording/editor library has been selected. Candidate licensing and device proofs remain required before adding those dependencies.
