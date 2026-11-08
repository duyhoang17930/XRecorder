#include <jni.h>
#include <whisper.h>
#include <atomic>
#include <memory>
#include <string>
#include <vector>
#include <algorithm>
#include <mutex>
#include <chrono>
#include <cmath>
extern "C" {
#include <rnnoise.h>
}

struct NoiseOperation {
    using State = std::unique_ptr<DenoiseState,decltype(&rnnoise_destroy)>;
    std::vector<State> states;
    std::vector<float> interleaved;
    float input[480]{},output[480]{};
    explicit NoiseOperation(int channels):interleaved(480*channels) {
        for(int c=0;c<channels;c++) {
            auto *state=rnnoise_create();if(!state)throw std::bad_alloc();
            states.emplace_back(state,rnnoise_destroy);
        }
    }
};

static jlong monotonicMs() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
}
struct Operation {
    std::atomic<bool> cancelled{false};
    std::atomic<int> progress{0}, stage{0};
    std::atomic<int> languageId{-1};
    std::atomic<jlong> loadStart{0}, loadEnd{0}, inferStart{0}, inferEnd{0};
};
static Operation *op(jlong handle) { return reinterpret_cast<Operation *>(handle); }
static void fail(JNIEnv *env, const char *message) { env->ThrowNew(env->FindClass("java/io/IOException"), message); }
extern "C" JNIEXPORT jlong JNICALL Java_com_xrecorder_xrecorder_editor_NativeDenoiser_create(JNIEnv *env,jobject,jint channels) {
    if(channels<1 || channels>6){fail(env,"Unsupported noise-reduction channel count");return 0;}
    try{
        // Upstream v0.1 lazily initializes shared FFT tables without locking.
        // Preview/export may start concurrently; initialize before exposing a state.
        static std::once_flag initialized;
        std::call_once(initialized,[]{
            std::unique_ptr<DenoiseState,decltype(&rnnoise_destroy)> state(rnnoise_create(),rnnoise_destroy);
            if(!state)throw std::bad_alloc();
            float silence[480]{};rnnoise_process_frame(state.get(),silence,silence);
        });
        return reinterpret_cast<jlong>(new NoiseOperation(channels));
    }
    catch(const std::bad_alloc &){fail(env,"Not enough memory for noise reduction");return 0;}
}
extern "C" JNIEXPORT void JNICALL Java_com_xrecorder_xrecorder_editor_NativeDenoiser_process(JNIEnv *env,jobject,jlong handle,jfloatArray samples) {
    auto *state=reinterpret_cast<NoiseOperation *>(handle);
    if(!state || env->GetArrayLength(samples)!=jsize(state->interleaved.size())){fail(env,"Invalid noise-reduction frame");return;}
    env->GetFloatArrayRegion(samples,0,jsize(state->interleaved.size()),state->interleaved.data());
    if(env->ExceptionCheck())return;
    const auto channels=state->states.size();
    for(size_t c=0;c<channels;c++) {
        for(size_t i=0;i<480;i++)state->input[i]=state->interleaved[i*channels+c]*32768.0f;
        rnnoise_process_frame(state->states[c].get(),state->output,state->input);
        for(size_t i=0;i<480;i++)state->interleaved[i*channels+c]=state->output[i]/32768.0f;
    }
    env->SetFloatArrayRegion(samples,0,jsize(state->interleaved.size()),state->interleaved.data());
}
extern "C" JNIEXPORT void JNICALL Java_com_xrecorder_xrecorder_editor_NativeDenoiser_destroy(JNIEnv *,jobject,jlong handle) {
    delete reinterpret_cast<NoiseOperation *>(handle);
}
static std::string escaped(const char *text) {
    std::string out="\"";
    for (const unsigned char *p=reinterpret_cast<const unsigned char *>(text); *p; ++p) {
        if (*p=='"' || *p=='\\') { out+='\\'; out+=char(*p); }
        else if (*p=='\n') out+="\\n";
        else if (*p=='\r') out+="\\r";
        else if (*p=='\t') out+="\\t";
        else if (*p>=32) out+=char(*p);
    }
    return out+'"';
}
extern "C" JNIEXPORT jlong JNICALL Java_com_xrecorder_xrecorder_editor_WhisperNative_create(JNIEnv *,jobject) { return reinterpret_cast<jlong>(new Operation()); }
extern "C" JNIEXPORT void JNICALL Java_com_xrecorder_xrecorder_editor_WhisperNative_cancel(JNIEnv *,jobject,jlong h) { op(h)->cancelled=true; }
extern "C" JNIEXPORT jint JNICALL Java_com_xrecorder_xrecorder_editor_WhisperNative_progress(JNIEnv *,jobject,jlong h) { return op(h)->progress.load(); }
extern "C" JNIEXPORT jint JNICALL Java_com_xrecorder_xrecorder_editor_WhisperNative_languageId(JNIEnv *,jobject,jlong h) { return op(h)->languageId.load(); }
extern "C" JNIEXPORT jfloatArray JNICALL Java_com_xrecorder_xrecorder_editor_WhisperNative_activity(JNIEnv *env,jobject receiver,jlong handle,jfloatArray audio) {
    try {
        // Reuse the existing thread-safe RNNoise initializer and its built-in model.
        const auto raw=Java_com_xrecorder_xrecorder_editor_NativeDenoiser_create(env,receiver,1);
        if(!raw)return nullptr;
        std::unique_ptr<NoiseOperation> noise(reinterpret_cast<NoiseOperation *>(raw));
        const int count=env->GetArrayLength(audio);
        std::vector<float> samples(count);
        env->GetFloatArrayRegion(audio,0,count,samples.data());
        if(env->ExceptionCheck())return nullptr;
        float sum=0,maximum=0;int observed=0,voiced=0,run=0,longest=0;
        for(int frame=0;frame<count/160;++frame) {
            if(op(handle)->cancelled) {fail(env,"Transcription cancelled");return nullptr;}
            // RNNoise expects mono 48kHz / 480 samples, scaled like PCM16.
            // Only analyze an interpolated copy; never modify recognized audio.
            for(int i=0;i<480;++i) {
                const int base=frame*160+i/3;
                const float fraction=float(i%3)/3;
                const float value=samples[base]*(1-fraction)+samples[std::min(base+1,count-1)]*fraction;
                noise->input[i]=(std::isfinite(value)?std::clamp(value,-1.f,1.f):0)*32768;
            }
            const float probability=rnnoise_process_frame(noise->states.front().get(),noise->output,noise->input);
            if(frame<10)continue; // State warm-up, 100ms.
            sum+=probability;maximum=std::max(maximum,probability);++observed;
            if(probability>=.5f) {++voiced;++run;longest=std::max(longest,run);} else run=0;
        }
        const float denominator=float(std::max(observed,1));
        const jfloat values[]={sum/denominator,maximum,float(voiced)/denominator,float(longest*10),float(observed)};
        auto out=env->NewFloatArray(5);if(out)env->SetFloatArrayRegion(out,0,5,values);return out;
    } catch(const std::bad_alloc &) {fail(env,"Not enough memory for speech detection");return nullptr;}
}
extern "C" JNIEXPORT jbyteArray JNICALL Java_com_xrecorder_xrecorder_editor_WhisperNative_languages(JNIEnv *env,jobject) {
    // These three checksum-pinned multilingual models have n_vocab=51865 (99 languages).
    // The engine also knows Cantonese, whose token is absent from those models.
    std::string json="[";
    for(int id=0;id<=whisper_lang_max_id();++id) {
        if(id)json+=",";
        json+="{\"code\":"+escaped(whisper_lang_str(id))+",\"nativeCode\":"+std::to_string(id)+",\"englishName\":"+escaped(whisper_lang_str_full(id))+",\"available\":"+(id<99?"true":"false")+"}";
    }
    json+="]";
    auto out=env->NewByteArray(jsize(json.size()));
    if(out)env->SetByteArrayRegion(out,0,jsize(json.size()),reinterpret_cast<const jbyte *>(json.data()));
    return out;
}
extern "C" JNIEXPORT jlongArray JNICALL Java_com_xrecorder_xrecorder_editor_WhisperNative_timings(JNIEnv *env,jobject,jlong h) {
    auto *job=op(h);const auto now=monotonicMs();
    auto duration=[now](jlong start,jlong end){return start?std::max(jlong(0),(end?end:now)-start):jlong(0);};
    jlong values[]={job->stage.load(),duration(job->loadStart.load(),job->loadEnd.load()),duration(job->inferStart.load(),job->inferEnd.load())};
    auto out=env->NewLongArray(3);if(out)env->SetLongArrayRegion(out,0,3,values);return out;
}
extern "C" JNIEXPORT void JNICALL Java_com_xrecorder_xrecorder_editor_WhisperNative_destroy(JNIEnv *,jobject,jlong h) { delete op(h); }
extern "C" JNIEXPORT jbyteArray JNICALL Java_com_xrecorder_xrecorder_editor_WhisperNative_run(JNIEnv *env,jobject,jlong handle,jstring model,jfloatArray audio,jstring language,jint threads) {
    try {
    auto *job=op(handle);
    job->loadStart=monotonicMs();job->stage=1;
    const char *path=env->GetStringUTFChars(model,nullptr);
    if(!path)return nullptr;
    auto cp=whisper_context_default_params();cp.use_gpu=false;cp.flash_attn=true;
    std::unique_ptr<whisper_context,decltype(&whisper_free)> context(whisper_init_from_file_with_params(path,cp),whisper_free);
    env->ReleaseStringUTFChars(model,path);
    job->loadEnd=monotonicMs();
    if(!context) { fail(env,"The installed speech model could not be loaded.");return nullptr; }
    if(job->cancelled) { fail(env,"Transcription cancelled");return nullptr; }
    const auto count=env->GetArrayLength(audio);
    std::vector<float> samples(count);env->GetFloatArrayRegion(audio,0,count,samples.data());
    if(env->ExceptionCheck())return nullptr;
    const char *lang=env->GetStringUTFChars(language,nullptr);
    if(!lang)return nullptr;
    const std::string requestedLanguage(lang);
    env->ReleaseStringUTFChars(language,lang);
    const int modelLanguages=whisper_model_n_vocab(context.get())-51765-(whisper_is_multilingual(context.get())?1:0);
    const int requestedId=requestedLanguage=="auto"?-1:whisper_lang_id(requestedLanguage.c_str());
    if(!whisper_is_multilingual(context.get()) || (requestedLanguage!="auto" && (requestedId<0 || requestedId>=modelLanguages))) {
        fail(env,"The selected language is not supported by this speech model.");return nullptr;
    }
    auto params=whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.n_threads=std::clamp(int(threads),1,4);params.language=requestedLanguage.c_str();
    params.translate=false;params.no_context=true;params.print_progress=false;
    params.print_realtime=false;params.print_timestamps=false;params.print_special=false;
    params.token_timestamps=true;params.max_len=120;params.split_on_word=true;
    params.abort_callback=[](void *data){return static_cast<Operation *>(data)->cancelled.load();};
    params.abort_callback_user_data=job;
    params.progress_callback=[](whisper_context *,whisper_state *,int progress,void *data){static_cast<Operation *>(data)->progress=progress;};
    params.progress_callback_user_data=job;
    job->inferStart=monotonicMs();job->stage=2;
    const int result=whisper_full(context.get(),params,samples.data(),count);
    job->inferEnd=monotonicMs();job->stage=3;
    if(job->cancelled) { fail(env,"Transcription cancelled");return nullptr; }
    if(result!=0) { fail(env,"On-device speech recognition failed.");return nullptr; }
    job->languageId=whisper_full_lang_id(context.get());
    std::string json="[";
    for(int i=0;i<whisper_full_n_segments(context.get());i++) {
        if(i)json+=",";
        json+="{\"startMs\":"+std::to_string(whisper_full_get_segment_t0(context.get(),i)*10)+",\"endMs\":"+std::to_string(whisper_full_get_segment_t1(context.get(),i)*10)+",\"text\":"+escaped(whisper_full_get_segment_text(context.get(),i))+"}";
    }
    json+="]";job->progress=100;
    auto out=env->NewByteArray(jsize(json.size()));
    if(out)env->SetByteArrayRegion(out,0,jsize(json.size()),reinterpret_cast<const jbyte *>(json.data()));
    return out;
    } catch(const std::bad_alloc &) { fail(env,"Not enough memory for this speech model. Try tiny or a shorter video.");return nullptr; }
      catch(const std::exception &) { fail(env,"The offline speech engine could not finish this operation.");return nullptr; }
}
