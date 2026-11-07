# Reuse register — P2/P3

Updated 07/11/2026. Runtime source, optional models and QA tools are distinguished.

| Source | Pin/license | Actual use |
|---|---|---|
| [AndroidX Media3](https://github.com/androidx/media/tree/1.11.1) |1.11.1, Apache2 via existing Gradle dependency | Transformer/CompositionPlayer, sequences/gaps, ChannelMixing, Sonic, GainProcessor seek metadata and CanvasOverlay. Shared preview/export graph. |
| [whisper.cpp](https://github.com/ggml-org/whisper.cpp/tree/v1.9.5) |v1.9.5, `d1be6fde11ac6e0407606b4e42fe72d34add8037`, MIT |145 Android CPU build inputs; C++/JNI on-device speech. Unused GPU/server/CoreML/OpenVINO/VitisAI code omitted. Source/license intact. |
| [RNNoise](https://github.com/xiph/rnnoise/tree/v0.1) |v0.1, `cdf196b1e9de2f8ff1003328ebf9a4316477429d`, BSD3 |18 C/header/license inputs; six C compilation units plus embedded weights.480-frame48kHz denoising in the same editor JNI library. No capture changes. |
| [Whisper models](https://huggingface.co/ggerganov/whisper.cpp) |tiny/base/small-q5_1 multilingual, upstream Whisper MIT | Optional user download/import, exact size and SHA256 before installation. No weights in APK. Hashes in cpp/third_party/UPSTREAM.md. |
| [Google FLEURS](https://huggingface.co/datasets/google/fleurs) |vi_vn/test, CC-BY4.0 | Genuine Vietnamese QA speech/reference. Filename/attribution/SHA retained in build/verification/p2_p3/models/fleurs_vi_fixture.json. Reference never substituted for inference. |
| whisper.cpp samples/jfk.wav | Public-domain JFK speech fixture | Genuine English recognition benchmark; actual recognized segments retained. |
| [Compact ICC Profiles](https://github.com/saucecontrol/Compact-ICC-Profiles) |DisplayP3-v4, CC0 | Host/device color-conversion reference only; profile/license retained under build/verification/p2_p3/photo. |
| [ktfmt](https://github.com/Kotlin/ktfmt/releases/tag/v0.65) |0.65, Apache2 | Host-only formatter under ignored build/qa_tools. |
| JUnit |4.13.2, EPL1.0 | Native testImplementation only; storage reserve/boundary/overflow assertions. |

MIT/BSD3 runtime notices are packaged in EDITOR_NATIVE_LICENSES.txt and registered
with Flutter LicenseRegistry. Existing Flutter/go_router/Lucide/offline Manrope
remain. FFmpeg/Pillow are host QA tools, not app dependencies. No paid API, remote
speech service, new UI/font/icon package or FFmpeg runtime. P1 MediaOutput is used
through its public contract; its implementation stays unchanged. ReuseForge was
not selected by the user.
