# TASK09C refactor changelog

## Existing files changed

| Exact repository path | Change and preserved behavior |
| --- | --- |
| `lib/features/editor/editor_screen.dart` | Replace private project-name dialog with StudioNameDialog. Keep maxLength 80, localized labels, whitespace trim, reject blank names, caller-owned project change/autosave. |
| `lib/features/media/video_details_screen.dart` | Replace private media-rename dialog with StudioNameDialog. Keep maxLength 120 and raw filename submission to existing native validation; rename/refresh/route semantics unchanged. |
| `tool/evaluate_task07_asr.py` | Import shared distance; retain NFKC/casefold, letters/marks/numbers, tokenization and report schema. |
| `tool/analyze_whisper_benchmark.py` | Import shared distance; retain older NFC/lowercase alphabetic CER and independent word normalization. CLI/network/device code otherwise unchanged and not run. |
| `README.md` | Correct English-only statement to source-backed 12 languages; link current documentation index. |

## New implementation files

| Exact path | Purpose |
| --- | --- |
| `lib/core/ui/components/dialogs/studio_name_dialog.dart` | Shared controller lifecycle, field/Clear, Cancel and submit presentation. Callers retain validation/persistence. Uses existing StudioDialog and StudioClearTextButton. |
| `tool/asr_metrics.py` | One unit-cost sequence edit-distance implementation for characters or word tokens. No normalization or I/O. |
| `tool/tests/test_asr_metrics.py` | Four host tests for known Unicode/token errors, metric properties and retained script-aware normalization. |
| `tool/repository_inventory.py` | Reusable read-only metadata/hash inventory. No deletion API, no junction following or AVD hashing; exclusive new report output. |
| `docs/README.md` | Current guidance/ownership/historical report index without moving existing evidence. |

Task-owned report artifacts live only in this directory. `audit_metadata.py`
reproduces file/tool/config classification and writes new reports exclusively;
`final_checks.py` verifies preservation, local links, imports and whitespace.
The [final Git snapshot](final_git_status.json) enumerates every path, including
all report artifacts, separately from the initial user-owned work.

Removed duplicated implementations: `_ProjectNameDialog`/State and
`_RenameMediaDialog`/State (81 lines excluding trailing separators), plus two local distance functions (16 lines).
The replacement has explicit caller semantics; fewer lines alone was not the goal.
No public contract, theme/token/icon/font/localization key, data format, permission,
capture, editing or export algorithm changed. No native source changed.

## Preservation and verification

[TASK09C-only patch](TASK09C_ONLY.patch) isolates existing Dart/README changes
from prior dirty work; [tool-only patch](TASK09C_TOOLS_ONLY.patch) does the same
for Python. The new files are listed above. These patches were produced by
reversing only our known edits **in memory** and matching the original whole-file
baseline SHA-256, never by writing HEAD versions over working files.
[First proof](refactor_delta_verification.json) verifies both dirty Dart files and
README; [corrected Python proof](tool_delta_verification_v2.json) verifies both
tools. The first Python whitespace reconstruction attempt failed and is retained.

Baseline two rename tests PASS; final two rename tests PASS. Broader affected
editor/layout/localization/onboarding suites: 123 PASS. Analyzer and formatter
PASS. Four Python tests, 16 baseline metric comparisons and entire 41-row
preserved-report evaluation comparison PASS. Both direct-script and package
`--help` entry points work. See [validation](VALIDATION_REPORT.md).

Existing user changes outside the scoped edits, all seven prior deletions and
untracked work remain intact. [Preservation](PRESERVATION_CHECK.json) lists the
five changed existing files and two removed bytecode caches. No staging/commit.

