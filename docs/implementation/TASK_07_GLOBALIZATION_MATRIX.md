# TASK 07 — Globalization matrix

Status: **G1/G2/G3 functional evidence recorded; G4 automated layout/native
matrix PASS with human review pending; G5/G6 packaging/native regression verified;
performance non-regression OPEN, physical/human/P1 integration gates separate**.
Historical P2/P3 passes do not certify this source.

| Locale | Resources / human review | Layout matrix | Subtitle preview/SRT/MP4 | Real Base ASR |
|---|---|---|---|---|
| en | Source ARB; coding review only | PASS4 sizes/orientations | PASS manual +generated | Fixed +Auto functional PASS |
| vi | TRANSLATION REVIEW PENDING | PASS4 | PASS manual +generated | Fixed +Auto functional PASS |
| es | TRANSLATION REVIEW PENDING | PASS4 after header fix | PASS manual +generated | Fixed +Auto functional PASS |
| pt_BR | TRANSLATION REVIEW PENDING | PASS4 | PASS manual +generated | Portuguese fixed +Auto functional PASS |
| fr | TRANSLATION REVIEW PENDING | PASS4 after header fix | PASS manual +generated | Fixed +Auto functional PASS |
| de | TRANSLATION REVIEW PENDING | PASS4 after header fix | PASS manual +generated | Fixed +Auto functional PASS |
| id | TRANSLATION REVIEW PENDING | PASS4 | PASS manual +generated | Fixed +Auto functional PASS |
| ja | TRANSLATION REVIEW PENDING | PASS4 | PASS no-space CJK +generated | Fixed +Auto functional PASS; CER reported |
| ko | TRANSLATION REVIEW PENDING | PASS4 | PASS manual +generated | Fixed +Auto functional PASS |
| zh_Hans | TRANSLATION REVIEW PENDING | PASS4 | PASS no-space CJK +generated | Fixed +Auto functional PASS; model may output Traditional Chinese |
| hi | TRANSLATION REVIEW PENDING | PASS4 | PASS Devanagari manual +verbatim model output | Fixed/Auto run; Base's wrong-script output is an accuracy failure, not translated/faked; warning +Small alternative available |
| ar | TRANSLATION REVIEW PENDING | PASS4 +RTL check | PASS shaping, mixed RTL/LTR/numerals/emoji | Fixed +Auto functional PASS |

Each layout row covers320dp/dark/200%,360dp/light/150%,411dp/light/200%,
840×411 landscape/light/200%, including libraries, photo tools, drafts, exports,
mocked trash, Settings, Help and six editing dialogs.49 checks pass in
`build/verification/task07/g4_layout_final.log`. Native G1 switching already
preserves router/library state and1013 image IDs; the expanded native run is
PASS in `g4_native_final/` (108 actual Android screenshots). Existing editor
state/playhead/native load count,89 drafts and20 current job payloads are
preserved. Primary API36 pre-TASK07 jobs were outside the old20-job disk window;
those missing jobs are not claimed recovered. G6 subsequently verifies11 genuine
pre-TASK07 live jobs on an independent API34 clone, with no fixture replay.
P1 hero/capture copy stays English pending
its owner's handoff. TalkBack service activation/restoration was real, but its
notification permission dialog interrupted app-focus samples. G6's separate
native framework test verifies4 actual Arabic navigation focus targets while
TalkBack stays bound, using the public non-suppression flag;4 focus PNGs and
exact state restoration. Human/gesture usability remains unverified. G6 also passes108 actual captures,115 draft
documents and57 prior current jobs. Final ASR regression retains those57 among77
jobs; Tiny/Base/Small EN/VI and Base Auto pass. Runtime16KB verifies Tiny English,
13 glyph probes, Unicode Media3 burn-in, storage retry and five-job restart.
Human usability/listening remain NOT RUN.

G3 evidence:12 decoded MP4s,24 actual Android preview captures and24 export/oracle
comparisons. Minimum glyph coverage99.618% (export/oracle),97.836%
(preview/export), with documented2px codec/antialiasing tolerance. SRT3494 bytes,
Unicode filename and original cue content read back exactly through SAF. Paths:
`build/verification/task07/g3_outputs/` and `g3_pixel_validation.log`.

ASR uses one first-matched licensed FLEURS utterance per language, not a broad
accuracy certification. All12 Auto requests detected the expected language on
that corpus. See [contract and limitations](TASK_07_ASR_CONTRACT_AND_BENCHMARK.md)
for CER/WER, model selection, false-positive controls and timing/memory evidence.

Flutter uses `flutter_localizations`, `intl` and `gen_l10n`; the source is
`lib/l10n/app_en.arb`, with descriptions for every key and typed placeholders.
Generated Dart is disposable build output, ignored in Git. Run `flutter gen-l10n`
and `python tool/check_l10n.py` after changing ARBs.

App language defaults to **Follow system**. The additive `appLocale` field stays
inside preferences v2. Unknown stored tags return to system selection; unsupported
device languages resolve to English. The router and editor state retain their
identity during changes. Speech language has a separate contract in G2.

UI navigation follows Flutter's locale direction. Media pixels, timeline order,
crop/drawing coordinates and native video layout explicitly retain LTR. Technical
SRT timestamps remain ASCII; displayed numbers use locale formatting. Editing
times additionally accept decimal commas and Arabic/Indic digits without changing
the stored millisecond representation.

## Translation provenance and glossary

Drafting runs locally on the development host using CTranslate2 4.8.5 with
M2M100-418M (`gn64/M2M100_418M_CTranslate2`, pinned revision
`18e406c615ef2991fa74d53734bf66b0a6b10cb4`, MIT model provenance).
The engine, its weights and Python packages are under ignored verification output,
not application dependencies or bundled assets. No user media or transcripts are
submitted for translation. This tooling does not add subtitle translation.

| English term | Meaning / reviewer guidance |
|---|---|
| Draft | Editable project referencing original media; not an exported video |
| Export | Create a new output file; do not imply modification of the source |
| Trash / Restore | Private recoverable media backup / restore a verified copy |
| Speech language | Language spoken in the input; independent of app language |
| Auto Detect | Model detection; accuracy is not guaranteed |
| Review subtitles | Check recognition before burn-in or sharing |
| Tiny / Base / Small, Whisper, Media3 | Model/product identifiers: retain spelling |
| URI, SRT, MP4, PNG, JPEG, GIF, MiB | Technical formats/units; keep unambiguous |

Reviewers must check grammar around placeholders, terminology, truncation, RTL,
regional Portuguese wording and script shaping. Automated key parity and widget
checks do not substitute for a native speaker or TalkBack testing by a person.
