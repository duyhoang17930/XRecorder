# TASK09C repository cleanup audit

2026-11-13; main at `e008fbb095be62db9538f4c598cbff89e6ceb7aa`, upstream `origin/main`.
Overall **PARTIAL**: safe changes implemented; no claim of exhaustive native dead-code proof or full acceptance.

Read repository/local AGENTS, local SKILLS/testing guidance, product specification,
dependency research, UX guidelines, P1 ownership, P2/P3 contracts, TASK09B reports
and UI/UX 06 original/v2 reports and P1 handoff before product edits. No project skill
was applicable; ReuseForge and delegation were not started.

## Inventory

The initial read-only scan preceded all mutation. The persisted [baseline](baseline_inventory.json)
contains 29,288 files and 152,401,172,646 logical bytes; it includes the newly added
inventory tool, before any product refactor. No scan errors or followed reparse points.
External SDK/cache/AVD locations were not traversed. `scripts/` and `tools/` do not
exist; this project uses `tool/`.

| Directory | Files | Logical bytes | Owner/class | Purpose and references / decision |
| --- | ---: | ---: | --- | --- |
| `(root files)` | 9 | 20675 | Shared / D | Pub/analysis/l10n/toolchain configuration; README and local rules. pubspec/lock and analyzer; preserve settings and signing contracts. |
| `.claude-local` | 783 | 238492853 | Local harness / L | Ignored instructions, workflow helpers and local history. AGENTS/SKILLS routing; protected, no workflow started. |
| `.dart_tool` | 2552 | 6812647450 | Flutter tooling / I | Generated package maps, test/compiler caches. Required for --no-pub host checks; retained. |
| `.git` | 2191 | 65523587 | Repository / L | Git objects/index/refs. HEAD/index preserved; no staging/commit. |
| `.github` | 3 | 1309 | Shared tooling / D | Repository automation configuration. Build/test consumers; unchanged. |
| `.vscode` | 1 | 47 | User / L | Local editor settings. User preferences; retained. |
| `android` | 963 | 386303533 | P1/P2/P3 / A/B/D/E/I | Native engines/JNI/vendor sources, resources, tests and Gradle cache. Manifest/channels/CMake/Gradle; P1/native unchanged. |
| `assets` | 26 | 4050924 | UI/P3 / E | Manrope, onboarding, licenses and retained test media. pubspec/LicenseRegistry/fixture consumers; no asset removed. |
| `build` | 20567 | 144218346589 | QA/tooling / H/I/L | Generated builds mixed with evidence, models, recovery and AVDs. Never treat entire directory as disposable; exact-path review only. |
| `docs` | 1725 | 659374789 | P1/P2/P3/QA / F/G/H/L | Contracts, task history, recovery and reproducibility evidence. Current index added; historical paths and verdicts preserved. |
| `image` | 90 | 12039284 | User references / L | Original reference images/video. APP_SPEC/REFERENCE_INDEX; keep duplicate R48/R49. |
| `integration_test` | 47 | 354065 | Feature owners / B | Flutter/native/device QA entry points. Registered test targets; inventoried, not run. |
| `ios` | 50 | 70687 | Scaffold/tooling / D/L | Non-Android scaffold and generated debugger helper. Not evidence of supported runtime; retained. |
| `lib` | 122 | 2565012 | P1/P2/P3/UI / A/D | Application, shared UI, features, localization/generated l10n. Router/state/repositories/bridges; only two rename consumers edited. |
| `linux` | 10 | 16273 | Scaffold / D/L | Flutter platform scaffold. Not certified runtime; retained. |
| `macos` | 34 | 228989 | Scaffold / D/L | Flutter platform scaffold. Not certified runtime; retained. |
| `test` | 59 | 752474 | Feature owners / B/E | Host tests and fonts/media fixtures. Focused P2/P3 suites; no P1 capture tests run. |
| `test_driver` | 2 | 1833 | QA / B | Flutter drive entry points. Integration commands reference them; retained. |
| `tool` | 29 | 269413 | P2/P3/QA / C/I | QA validators/install safety/report scripts and bytecode caches. Shared ASR metric extracted; only two verified caches deleted. |
| `web` | 7 | 43571 | Scaffold / D/L | Web platform scaffold. Not certified runtime; retained. |
| `windows` | 18 | 69289 | Scaffold / D/L | Windows platform scaffold. Not certified runtime; retained. |

[File classification](FILE_CLASSIFICATION.csv) covers every baseline file.
Labels A–L are conservative routing, not deletion authority. Generated/local
scaffolds and historical source snapshots are not evidence of shipped behavior.
J duplicates are identified separately; no K obsolete file was sufficiently proven
safe for wholesale removal. [Large-file inventory](LARGE_FILE_RETENTION.json)
retains 97 files over 100 MB. `build/verification/` alone is 121,648,898,279 bytes;
large AVDs, checkpoints, media/models and backups are protected.

## Git and ownership

Initial status: **56 modified tracked, 7 pre-existing deleted tracked, 824 untracked,
0 staged, 0 added tracked**: 887 entries, not 898 at this checkpoint.
Baseline has 1557 tracked paths and 22576 ignored files.
The persisted baseline's 825 untracked entries include the new inventory tool.

Untracked originals: 808 docs/report files, 6 Dart source files, 7 tests/fixtures,
3 Android source/resource files. The 808 docs items include 259 PNG, 267 JSON,
138 TXT, 79 Python, 36 MP4 and 10 Markdown files, plus reference snapshots and
other formats. These explain most of the VS Code count; they are not automatically junk.
Full original status is retained in the baseline JSON, separately from ignored metadata.

The seven original deletions under `docs/implementation/UI/` remain as found.
Existing UI05/05B/06 source, translations, tests and untracked evidence are active
work of prior workstreams. No live teammate identity is recorded in the repository;
dirty files were treated as owned work, not abandoned code.

P1 recording Dart/native, recording form/screen, original Create sheet, MainActivity,
shared models/repositories/settings controller and router remain unchanged.
[Preservation check](PRESERVATION_CHECK.json): **452 protected/shared file hashes
match**, 2,388 baseline hashed files unchanged, exactly five expected existing
files changed, exactly two allowlisted cache files removed. Build/AVD/model
size+mtime checks show no protected deltas; this is not full disk-content hashing.

## Code and dependency audit

Dart analyzer baseline and final: no diagnostics. Two equivalent controller-owning
name-entry presentations were consolidated; distinct project validation and media
filename submission remain in their callers. Duplicate ASR sequence-distance
algorithms now share one helper. See [changelog](REFACTOR_CHANGELOG.md).

`formatBytes` in `media_repository.dart` has no discovered application consumer;
current UI uses localized `context.fileSize`. It is retained as an existing public
helper: no API removal or unrelated repository edit is needed to achieve the safe
refactors. Compatibility re-export files also stay because consumers, including
protected P1 UI, still use them.

Native inventory includes 72 Kotlin, 13 Java, 43 C++, 18 C and 74 header files
under Android src. Manifest activity/service/provider declarations, MainActivity
channel/platform-view registrations, JNI exported names/WhisperNative externals
and CMake linkage were inspected. Native callbacks/JNI/Gradle entry points were
not pruned based on text-search absence. No Kotlin/native analyzer, build or runtime
was executed; exhaustive native dead-code findings remain unverified.

All declared Dart runtime dependencies have source consumers:
Flutter/widgets, SDK localization delegates, intl in localization, characters in
subtitle handling, go_router in navigation, Lucide through AppIcons.
Flutter test/integration/lints dependencies serve registered checks.
Gradle Media3 transformer/effect/ui stay aligned at 1.11.1; JUnit 4.13.2 remains
test-only. CMake links whisper.cpp, RNNoise, log/android into threeh_whisper;
WhisperNative loads it by name. Vendor pins/notices/local patches are preserved.
No dependency added, removed or upgraded; SDK/Gradle declarations are unchanged.

## Tools, documentation and assets

[Python inventory](ALL_PYTHON_INVENTORY.json) catalogs 902 baseline Python files:
751 under build, 110 under docs, 22 under tool, one generated iOS helper and 18
local-harness files. **884 were parsed/compiled in memory**; local harness scripts
were classified and retained without invocation. Additional new Python
files were also syntax-checked, including the final integrity checker. [Detailed tool audit](PYTHON_TOOL_AUDIT.json)
records repository tool/import/purpose/reference evidence. Historical experiments,
device-mutating runners, recovery validators and QA source media remain retained.
No script was deleted for having no obvious caller. Reference search is bounded
to repository docs/tools and AST imports, not proof against external/dynamic callers.

[Asset/document duplicate audit](ASSET_DOCUMENT_DUPLICATES.json) found the known
reference-image pair and identical Android launch XML in distinct qualifiers;
both are retained. [Historical duplicate audit](HISTORICAL_DOCUMENT_ASSET_DUPLICATES.json)
finds 60 exact duplicate groups among report text/JSON/XML/screenshots. Their task
identity/provenance remains meaningful; none was deleted. Two same-size historical
APK pairs proved **different SHA-256**; see [samples](apk_duplicate_samples.json).
One actual historical APK duplicate is proposed separately, not deleted.

Current documentation now has a subject index at [docs README](../../README.md).
Root README's obsolete English-only statement was corrected from the 12-locale
source catalog. UI/UX 06 v2 is linked as the latest checkpoint, without replacing
v1 or changing TASK09B's PARTIAL/TASK10-not-ready verdict.
44 historical P1 XML dumps are not pure XML documents; all are retained byte-exact.
The localization checker reports 40 baseline findings, detailed in
[L10N baseline findings](L10N_BASELINE_FINDINGS.json); all 14 ARB hashes match
pre-refactor. These are not new maintenance regressions.

Existing .gitignore already covers build/cache output, pyc, generated l10n and
precise private-backup snapshots. No extra ignore rule is justified: adding docs
or image patterns would hide real work. Gitignore and the index are unchanged.

## Risks and remaining work

No full-device, capture, native release/offline packaging or physical usability
acceptance was run. Old P1 recording failures, journal discrepancy, recovery
limitations and native/human gates remain open. Review the exact APK proposal
before any historical deletion; protected AVD/checkpoint/model/media data is
not in that proposal.

