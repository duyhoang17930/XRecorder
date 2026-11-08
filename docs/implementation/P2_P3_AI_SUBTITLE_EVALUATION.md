# Offline AI subtitles — đánh giá 07/11/2026

Engine thật: whisper.cpp v1.9.5 CPU/JNI, multilingual tiny/base/small-q5_1.
Audio không upload. Model do người dùng download/import, SHA256/size check,
atomic install vào private no-backup; không bundle weights trong APK.

## Corpus và phương pháp

Nguồn [Google FLEURS](https://huggingface.co/datasets/google/fleurs), CC-BY4.0;
original WAV, reference, URL, SHA256 và conversion PCM16mono16k được giữ tại
`build/verification/final_p2_p3/asr/corpus/manifest.json`. Sáu utterance Việt
(ba test MALE, ba train FEMALE),65,58s; hai English male/female22,02s;
hai bản noise20/5dB SNR từ cùng một câu Việt22,68s; silence4s và two-tone
synthetic music4s. Tổng12 stimulus,118,28s, không phải12 người nói độc lập.

Danh tính/vùng Bắc–Trung–Nam không được annotate; không gán vùng bằng phỏng đoán.
Train/test ở đây là split FLEURS, không chứng minh độc lập training data Whisper.
Noise seed42; cùng noise/source cho mọi model. Không tuning engine theo fixture.

Ba model×12 stimulus và hai Tiny repeat =38 native jobs;3 digital-silence jobs
skip engine đúng thiết kế, còn35 JNI inference. Raw harness đầu tiên gọi nhầm
counter38 là inference; evaluator tính lại từ native inferenceMs, không đếm
repeat thành accuracy sample mới. Cả38 job native PASS state/timing assertions;
PASS pipeline **không có nghĩa transcript đúng hoàn toàn**.

CER: NFC lowercase, chỉ ký tự alphabetic, bỏ spaces/punctuation, giữ dấu Việt.
WER: NFC lowercase, alphanumeric words; punctuation thành separator, giữ số.
Levenshtein/reference length, mean theo utterance, không duration-weighted.
RTF = elapsed wall processing/audio duration; bao gồm decode/load/inference.
p95 là nearest-rank trên n rất nhỏ, không có confidence interval quần thể.

## Kết quả clean speech

| Model | VI n | VI CER | VI WER | VI median RTF | VI median/p95 ms | EN CER/WER (n=2) |
|---|---:|---:|---:|---:|---:|---:|
| tiny |6|32,67%|54,63%|0,614|6856/7503|3,90%/11,72%|
| base |6|17,35%|34,09%|1,646|17024/18830|3,57%/8,69%|
| small-q5_1 |6|7,70%|16,15%|3,405|34444/39407|2,60%/8,69%|

Trên hai noise variant cùng câu, mean CER/WER Tiny47,66%/60,87%;
Base45,31%/52,17%; Small1,56%/4,35%. Đây là **một nội dung ở hai mức nhiễu**,
không suy thành độ chính xác chung trong môi trường ồn.

Đọc thủ công transcript phát hiện lỗi tên riêng Springboks (tách thành
“Spring Book”), dấu và các từ ngắn; Small vẫn có lỗi. Câu về bánh xe có
CER18,26/13,91/3,48% theo Tiny/Base/Small. WER phạt cả khác biệt số5/“năm”.
Không thay reference vào kết quả native hoặc công bố “accuracy92,3%”.

Tiny/Base trả empty cho silence và music control. Small trả empty cho silence
nhưng tạo **“(Bell)”** trên two-tone music. Đây là non-speech caption không mong
muốn, phải review; không giấu sample hay đánh dấu mọi non-speech đều sạch.
Không thêm energy heuristic mù để xóa lời nói nhỏ chỉ nhằm làm đẹp benchmark.

## Default và chi phí trên AVD

Default mới **Base/Balanced**, ngôn ngữ Việt: cải thiện CER trên corpus này so
Tiny, nhanh hơn Small. Nếu chỉ Tiny đã cài, dialog dùng model đó để tránh buộc
download. Khôi phục job dùng đúng model/language, không reset lựa chọn thủ công.
Tiny/Fast74MiB; Base141MiB; Small-q5_1181MiB, chậm hơn và cần thêm RAM.
Không cam kết model nào luôn tốt hơn trên mọi giọng/thiết bị.

Median load173/320/424ms; median inference5967/16526/33290ms trên các sample
có inference, warmed file cache. Phase sampled peak PSS421845/494785/610099KiB,
222 samples tổng; không phải riêng weights, không thay exact peak/leak proof.
AVD API36 x86_64,3GiB,4vCPU, SwiftShader; lúc corpus có thêm AVD người dùng
API37 chạy trên host, không tác động nó. Không so thời gian này như ARM thật.

## Sửa lỗi pipeline

- Validate content URI trước khi đưa Job vào queue: invalid file:// trước đây
  để queued vĩnh viễn, chặn ASR sau. Native regression tái hiện FAIL trước, PASS sau.
- Dart/native giữ100..600000ms, supported model/language/operation ID bounds.
- Native timing/stage thật, terminal completed chỉ publish sau elapsed/timings
  đã hoàn tất; job checkpoint giữ model/language/load/inference metrics.
- Cancel regression phát hiện worker còn bận9616ms dù UI phản hồi2ms. Local
  whisper.cpp scheduler patch truyền abort callback vào CPU nodes; đo lại8ms
  request,518ms gồm drain và decode silence kế tiếp. Chín inference vi/en/auto
  trên Tiny/Base/Small sau patch PASS. Không thay model/math/decoding parameters;
  corpus metrics ở trên là trước patch cancellation, không giả thành benchmark mới.
- Import file model lỗi bị từ chối; hủy import sau byte progress thật vẫn giữ model
  cũ đã verified; từ chối Remove khi đang inference; kết quả cancelled không bị
  callback muộn thay thế. Native fault reports `asr/faults/`, `asr/faults_after/`.
- Subtitle Editor, SRT và burn-in vẫn tiêu thụ timed segments thật từ cùng edited
  audio composition; không thêm paid API hoặc transcript placeholder.

## Reproduce và bằng chứng

```powershell
python tool/analyze_whisper_benchmark.py --prepare-corpus build/verification/final_p2_p3/asr/corpus
# Copy only prepared QA fixtures + manifest into QA app-owned media directory.
flutter drive --no-dds --keep-app-running --driver=test_driver/design_system_driver.dart --target=integration_test/p2_p3_whisper_test.dart -d emulator-5560 --dart-define=ASR_CORPUS=true
python tool/analyze_whisper_benchmark.py --evaluate-corpus build/verification/final_p2_p3/asr/corpus --native-report build/verification/final_p2_p3/asr/corpus_native/emulator_verification.json --output build/verification/final_p2_p3/asr/evaluation.json
```

Native log `asr/corpus_native.log`; raw reports `asr/corpus_native/`,
`asr/memory.json`; evaluator `asr/evaluation.json`. Source fixture generation,
sampling/evaluation ở cùng tool, không cần legacy benchmark artifacts cho mode mới.

- **Implemented and verified now:** real multilingual JNI inference/cues/progress,
  corpus metrics/default decision, queue rejection regression.
- **Implemented but not independently verified:** mọi người nói/vùng miền,
  mọi ngữ cảnh music/speech, ARM/OEM latency; old model-download proof được index
  riêng trong TEST_EVIDENCE, không trình bày là vừa download lại toàn bộ weights.
- **Not implemented:** accent classifier, production WER guarantee, server fallback.
  Những mục này không được giả làm feature đã chạy.
- **External gates:** corpus Việt có accent/speaker annotation và quyền sử dụng;
  máy ARM thật,10-minute speech/thermal/battery, human subtitle quality/listening.
  Cần cung cấp thiết bị và người thử; AVD không đóng các gate này.
