#include <jni.h>
#include <whisper.h>
#include <atomic>
#include <memory>
#include <string>
#include <vector>
#include <algorithm>
#include <mutex>
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

struct Operation { std::atomic<bool> cancelled{false}; std::atomic<int> progress{0}; };
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
extern "C" JNIEXPORT void JNICALL Java_com_xrecorder_xrecorder_editor_WhisperNative_destroy(JNIEnv *,jobject,jlong h) { delete op(h); }
extern "C" JNIEXPORT jbyteArray JNICALL Java_com_xrecorder_xrecorder_editor_WhisperNative_run(JNIEnv *env,jobject,jlong handle,jstring model,jfloatArray audio,jstring language,jint threads) {
    try {
    auto *job=op(handle);
    const char *path=env->GetStringUTFChars(model,nullptr);
    auto cp=whisper_context_default_params();cp.use_gpu=false;cp.flash_attn=true;
    std::unique_ptr<whisper_context,decltype(&whisper_free)> context(whisper_init_from_file_with_params(path,cp),whisper_free);
    env->ReleaseStringUTFChars(model,path);
    if(!context) { fail(env,"The installed speech model could not be loaded.");return nullptr; }
    if(job->cancelled) { fail(env,"Transcription cancelled");return nullptr; }
    const auto count=env->GetArrayLength(audio);
    std::vector<float> samples(count);env->GetFloatArrayRegion(audio,0,count,samples.data());
    if(env->ExceptionCheck())return nullptr;
    const char *lang=env->GetStringUTFChars(language,nullptr);
    auto params=whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.n_threads=std::clamp(int(threads),1,4);params.language=lang;
    params.translate=false;params.no_context=true;params.print_progress=false;
    params.print_realtime=false;params.print_timestamps=false;params.print_special=false;
    params.token_timestamps=true;params.max_len=120;params.split_on_word=true;
    params.abort_callback=[](void *data){return static_cast<Operation *>(data)->cancelled.load();};
    params.abort_callback_user_data=job;
    params.progress_callback=[](whisper_context *,whisper_state *,int progress,void *data){static_cast<Operation *>(data)->progress=progress;};
    params.progress_callback_user_data=job;
    const int result=whisper_full(context.get(),params,samples.data(),count);
    env->ReleaseStringUTFChars(language,lang);
    if(job->cancelled) { fail(env,"Transcription cancelled");return nullptr; }
    if(result!=0) { fail(env,"On-device speech recognition failed.");return nullptr; }
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
