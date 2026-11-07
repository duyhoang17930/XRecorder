# whisper.cpp

Source: https://github.com/ggml-org/whisper.cpp
Release v1.9.5, commit d1be6fde11ac6e0407606b4e42fe72d34add8037.
Downloaded 2026-11-07. MIT license is retained in whisper.cpp/LICENSE.
Vendored build inputs: CMakeLists.txt, cmake/, include/, src/, ggml/.
Remaining source files are unmodified. Only Android CPU build inputs are retained
(145 files after pruning); unused GPU/server backends and CoreML/OpenVINO/VitisAI
directories are excluded, as are examples, models, CI and Git metadata. Root app
CMake explicitly disables excluded backends. All three Android ABI builds are required.
Android uses CPU only, no OpenMP, no downloads at build time. The JNI wrapper is
application code. No recording/capture source is included or changed.

Multilingual model distribution follows upstream models/README.md:
https://huggingface.co/ggerganov/whisper.cpp
tiny: 77,691,713 bytes; SHA256 be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21
base: 147,951,465 bytes; SHA256 60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe
small-q5_1: 190,085,487 bytes; SHA256 ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb
Models are optional user downloads and are never bundled in the APK.

# RNNoise

Source https://github.com/xiph/rnnoise, tag v0.1, commit
cdf196b1e9de2f8ff1003328ebf9a4316477429d. BSD-3-Clause notices retained in
rnnoise/COPYING and source headers. Only18 C/header/license files are vendored;
training and example scripts are excluded. Six upstream C sources and their
small embedded RNN coefficients are statically linked into the editor JNI
library. The model accepts480-sample48kHz frames; JNI is app-owned. No runtime
network download or capture pipeline changes. Actual exported speech/noise
quality and sample-duration checks are required before reporting this feature verified.
