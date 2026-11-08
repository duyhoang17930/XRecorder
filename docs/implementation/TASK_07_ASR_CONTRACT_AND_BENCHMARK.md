# TASK 07 — ASR contract and benchmark

Status: **G2 functional native gates PASS; population/language accuracy NOT CERTIFIED**.
Analyzer clean; latest full Flutter run164 PASS, followed by30 targeted tests PASS
including the new retry UI;5 JVM tests PASS. G6 will rerun the whole final source.

## Actual engine/model language boundary

The vendored whisper.cpp v1.9.5 `g_lang` table has IDs 0–99. The checksum-pinned
multilingual Tiny/Base/Small-q5_1 models have vocabulary 51865. The engine's own
`whisper_vocab::num_languages()` formula is
`n_vocab - 51765 - (is_multilingual ? 1 : 0)`, yielding **99 languages**, IDs 0–98.
Cantonese (`yue`, ID99) exists in the engine but is unavailable in these models.
It is shown disabled with an explanation and rejected by Dart/Kotlin/JNI.

`tool/generate_speech_languages.py` derives the typed Dart catalog from that table;
localized names come from Babel2.17/CLDR with attribution bundled in the app.
`WhisperNative.languages()` returns identifiers from the actual engine. Native QA
compares code/native ID/availability with Dart. JNI additionally checks the loaded
model vocabulary before inference, rather than relying solely on the UI catalog.

## Additive contract

- Request adds `contractVersion:2`; `language`, model IDs, duration/URI/job-ID
  validation remain machine identifiers. Existing `vi/en/auto` remain supported.
- New-job UI defaults to **Auto Detect**; Base remains the balanced initial choice
  and falls back to an installed model. Restored jobs keep their saved model and
  language; missing legacy language keeps the existing native `auto` fallback.
- Preferences v2 adds independent `speechLanguage`, separate from `appLocale`.
  Capture values/defaults/migrations/mapping are untouched. Search matches code,
  English name, native name and the current localized display name.
- Job snapshots add `resultLanguage`, `detectedLanguage`, `errorCode` and
  `contractVersion`. `detectedLanguage` is only populated for Auto jobs after
  actual engine detection. Silence/cancellation do not invent a language.
- `translate=false` remains explicit in JNI. This is source-language transcription,
  without an online endpoint or a subtitle translation toggle.
- Stable error codes localize speech errors; legacy/native diagnostic text is not
  shown as a raw exception. Legacy phase strings remain compatible and map to ARB.
- Job-list snapshots no longer wait behind an active inference after journal
  restoration. QA measures that latency while a worker is busy. The existing
  model store, checksums, cancellation/CPU abort, 10-minute bound and RAM guard stay.

## Corpus and reproducibility

[Google FLEURS](https://huggingface.co/datasets/google/fleurs), CC-BY-4.0, pinned
revision `70bb2e84b976b7e960aa89f1c648e09c59f894dd`. Public real recordings and paired
references for en_us, vi_vn, es_419, pt_br, fr_fr, de_de, id_id, ja_jp, ko_kr,
cmn_hans_cn, hi_in and ar_eg. One utterance per language, duration8.16–17.94s;
**insufficient for general quality certification**.

The rows API returned HTTP500. The parquet metadata API worked but whole test
shards were hundreds of MB. `tool/fetch_task07_corpus.py` instead streams the first
archive member having a matching TSV reference and duration2–30s, without choosing
based on recognition output or downloading a full corpus. Each language consumed
roughly0.4–0.95MB of archive data. WAVs were float PCM, unsupported by Python's wave
reader; FFprobe reads them and FFmpeg produces mono16kHz PCM16 for Android, retaining
the original WAV and both SHA256 values.

All source/reference/provenance/conversion metadata are in
`build/verification/task07/corpus/*_source.json`. Public corpus and models are not
APK assets. Synthetic silence/noise/chord controls are clearly distinguished from
real speech. A repeated public Vietnamese clip is used only to interrupt a real
60s inference; no transcript is fabricated for that control.

Native run: API36 x86_64 `emulator-5560` / `ThreeHRecorder_Task021`, Flutter profile.
Existing three verified private model files are reused without deleting/importing
or replacing them. `--keep-app-running` preserves app data. Corpus manifest:
`task07_asr_manifest.json`, 41 benchmark jobs: Base fixed/Auto for all12 languages,
Tiny/Small on en/vi/zh/ar, and three non-speech controls for each model. Extra
inference cancellation and next-job drain are measured separately.

Artifacts: `g2_native_asr.log`, `g2_native_asr/emulator_verification.json`,
`g2_memory.jsonl`. PSS is sampled read-only every2s, with sampling query duration
recorded. Timing/RTF, script-specific CER/WER, detection accuracy, empty outputs and
control false positives are analyzed in `g2_asr_metrics*.json`. Preserve raw
outputs and report failures; do not turn a completed job into an accuracy PASS.

## Measured problems, implementation and repeated native evidence

Initial41 jobs completed, but4/9 synthetic non-speech controls produced text.
Base's Hindi result used Urdu script, despite engine language metadata `hi`.
These are quality failures, not UTF8 conversion errors: original strings remain
retained in raw evidence. Tiny used romanized Hindi; Small used Devanagari on the
same utterance, with CER0.258 / whitespace-WER0.625. This is not Hindi certification.
The UI now warns about the observed writing-system mismatch and permits model
selection/manual review; it never silently transliterates or replaces the output.

Before adding a filter, actual RNNoise probes ran on12 new speech utterances plus
the12 legacy VI/EN/noisy/silence/music fixtures, deduplicated with the new controls
to27 input files (`g2_activity_hi`). All tested speech, including added5dB noise,
had speech-positive frames. New noise/chord controls had no speech-positive frames.
An older vocal-like music/tone fixture had high activity: **RNNoise is not a music
classifier and this does not guarantee rejection of every non-speech recording**.

The implementation reuses RNNoise's existing built-in model and thread-safe
initializer. An interpolated copy of mono16kHz input feeds its48kHz analysis;
recognized PCM is unchanged. Input >=1s is skipped only when every observed frame
is below0.5 speech probability. Short/uncertain input is retained. The actual check
is cancellable every10ms; state/timings/handle ownership remain on the speech worker.
`allowUncertainSpeech` is an additive per-job field with an actual **Recognize
anyway** action, so quiet voices can bypass the filter. No new weights are bundled.
The score is not presented as transcription accuracy.

| Same41 scenarios, same API36 AVD/profile mode | Before | After |
|---|---:|---:|
| Completed benchmark jobs |41|41|
| Real speech/Auto outputs nonempty |32|32|
| Real transcripts unchanged byte-for-byte |Baseline|32/32|
| Controls with text |4/9|0/9|
| Completed actual inference runs |38|32|
| Inference cancel + next silent job drain |580ms|517ms|
| Maximum job-list latency |13ms|11ms|

The after run also verified that explicit override reaches real inference
(`uncertainSpeechBypassVerified:true`,6600ms inference for the override control).
Runtime41-case duration fell from12m01s to8m16s because non-speech inference was
skipped; **speech inference itself was not sped up**. Shared fixed-language
en/vi/zh/ar subset:

| Model | Median RTF before→after | Sampled peak PSS KiB before→after |
|---|---|---|
| Tiny |0.414→0.456|271944→273914|
| Base |0.914→0.950|377533→381235|
| Small-q5_1 |2.033→2.074|491537→492634|

G2 after evidence: `g2_native_asr_after.log`,
`g2_native_asr_after/emulator_verification.json`, `g2_asr_metrics_after.json`,
`g2_vad_after_memory.jsonl`. Auto language matched all12 references in these
single-utterance observations; that is not a general auto-detection guarantee.
Host/device clock calibration was within1s for sampled memory windows.

## G6 persistence and RAM regression

Speech history no longer silently keeps only its last20 jobs. Atomic writes,
strict UTF8/version reads, visible write warnings and retry-save preserve actual
recognition results without rerunning inference. Primary QA verified20+21 jobs
through restart; an independent API34 clone verified11 genuine pre-TASK07 jobs,
including6 archived Tiny/Base EN/VI/Auto payload matches. Jobs already pruned on
primary QA before this fix cannot be claimed recovered.

A real2GiB/16KB emulator low-memory process kill exposed insufficient admission
headroom. The new budget includes model working set,128MiB safety, Android's
system reserve (at least128MiB), and duration-dependent PCM buffers. Optional
`memoryPreflight` journal metadata records available/required/threshold/total RAM
and page size; old records need no migration. Both admission and pre-JNI rejection
were observed as RAM changed. On3GiB/16KB, Tiny English inference, intentional
write failure, exact retry-save, Unicode export and restart all pass. These are
measured emulator results, not universal RAM guarantees or ARM certification.
Raw failed attempts and successful retests are indexed in
[test evidence](TASK_07_TEST_EVIDENCE.md).
