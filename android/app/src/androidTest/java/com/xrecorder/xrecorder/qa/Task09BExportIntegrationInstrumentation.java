package com.xrecorder.xrecorder.qa;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.os.Bundle;
import android.os.SystemClock;
import android.provider.MediaStore;
import com.xrecorder.xrecorder.editor.ExportQueue;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicReference;
import org.json.JSONArray;
import org.json.JSONObject;

/** Runs bounded real exports through the production queue using an unchanged saved project. */
public final class Task09BExportIntegrationInstrumentation {
    private interface Checked<T> { T get() throws Exception; }

    private static <T> T main(Instrumentation runner, Checked<T> work) throws Exception {
        AtomicReference<T> value = new AtomicReference<>();
        AtomicReference<Exception> failure = new AtomicReference<>();
        runner.runOnMainSync(() -> {
            try { value.set(work.get()); }
            catch (Exception error) { failure.set(error); }
        });
        if (failure.get() != null) throw failure.get();
        return value.get();
    }

    private static void writeNew(File file, byte[] bytes) throws Exception {
        if (!file.createNewFile()) throw new AssertionError("Task evidence already exists: " + file);
        try (FileOutputStream out = new FileOutputStream(file)) {
            out.write(bytes);
            out.getFD().sync();
        }
    }

    private static byte[] read(InputStream input) throws Exception {
        try (InputStream in = input; ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[32768];
            int count;
            while ((count = in.read(buffer)) >= 0) out.write(buffer, 0, count);
            return out.toByteArray();
        }
    }

    private static String sha(byte[] bytes) throws Exception {
        byte[] hash = MessageDigest.getInstance("SHA-256").digest(bytes);
        StringBuilder text = new StringBuilder();
        for (byte value : hash) {
            int unsigned = value & 255;
            text.append("0123456789abcdef".charAt(unsigned >>> 4));
            text.append("0123456789abcdef".charAt(unsigned & 15));
        }
        return text.toString();
    }

    private static Object convert(Object value) throws Exception {
        if (value instanceof JSONObject) {
            Map<String, Object> map = new LinkedHashMap<>();
            Iterator<String> keys = ((JSONObject) value).keys();
            while (keys.hasNext()) {
                String key = keys.next();
                map.put(key, convert(((JSONObject) value).get(key)));
            }
            return map;
        }
        if (value instanceof JSONArray) {
            List<Object> list = new ArrayList<>();
            for (int i = 0; i < ((JSONArray) value).length(); i++)
                list.add(convert(((JSONArray) value).get(i)));
            return list;
        }
        return value == JSONObject.NULL ? null : value;
    }

    private static JSONObject clone(JSONObject value) throws Exception {
        return new JSONObject(value.toString());
    }

    private static JSONObject job(Instrumentation runner, ExportQueue queue, String id) throws Exception {
        JSONArray rows = new JSONArray(main(runner, queue::list));
        for (int i = 0; i < rows.length(); i++) {
            JSONObject row = rows.getJSONObject(i);
            if (id.equals(row.optString("id"))) return row;
        }
        throw new AssertionError("Job disappeared from history: " + id);
    }

    private static JSONObject waitTerminal(Instrumentation runner, ExportQueue queue, String id,
                                           long timeoutMs, JSONArray samples) throws Exception {
        long start = SystemClock.elapsedRealtime();
        String previous = "";
        while (SystemClock.elapsedRealtime() - start < timeoutMs) {
            JSONObject current = job(runner, queue, id);
            String state = current.optString("state");
            String sample = state + ":" + current.optInt("progress");
            if (!sample.equals(previous)) samples.put(new JSONObject().put("state", state)
                    .put("progress", current.optInt("progress")));
            previous = sample;
            if ("completed".equals(state) || "failed".equals(state) || "cancelled".equals(state))
                return current;
            SystemClock.sleep(50);
        }
        throw new AssertionError("Export job timed out: " + job(runner, queue, id));
    }

    private static JSONObject savedRow(Context context, Uri uri, String expectedName,
                                       String expectedMime) throws Exception {
        try (android.database.Cursor cursor = context.getContentResolver().query(uri, new String[] {
                MediaStore.MediaColumns.OWNER_PACKAGE_NAME,
                MediaStore.MediaColumns.IS_PENDING,
                MediaStore.MediaColumns.DISPLAY_NAME,
                MediaStore.MediaColumns.SIZE
        }, null, null, null)) {
            if (cursor == null || !cursor.moveToFirst()) throw new AssertionError("Output row is missing: " + uri);
            String owner = cursor.getString(0);
            int pending = cursor.getInt(1);
            String name = cursor.getString(2);
            long size = cursor.getLong(3);
            String mime = context.getContentResolver().getType(uri);
            if (!context.getPackageName().equals(owner) || pending != 0 ||
                    !expectedName.equals(name) || !expectedMime.equals(mime) || size <= 0)
                throw new AssertionError("Unexpected publication metadata: " + owner + "," + pending + "," +
                        name + "," + mime + "," + size);
            return new JSONObject().put("uri", uri.toString()).put("owner", owner)
                    .put("pending", pending).put("name", name).put("mime", mime).put("bytes", size);
        }
    }

    private static int countNamed(Context context, Uri collection, String name) {
        try (android.database.Cursor cursor = context.getContentResolver().query(collection,
                new String[] {MediaStore.MediaColumns._ID},
                MediaStore.MediaColumns.OWNER_PACKAGE_NAME + "=? AND " +
                        MediaStore.MediaColumns.DISPLAY_NAME + "=?",
                new String[] {context.getPackageName(), name}, null)) {
            return cursor == null ? 0 : cursor.getCount();
        }
    }

    /** Decode an entire selected track to codec EOS; AAC PCM is retained for waveform analysis. */
    private static JSONObject decodeTrack(Context context, Uri uri, int trackIndex,
                                           File pcmFile) throws Exception {
        MediaExtractor extractor = new MediaExtractor();
        MediaCodec codec = null;
        FileOutputStream pcm = pcmFile == null ? null : new FileOutputStream(pcmFile, false);
        int decodedBuffers = 0;
        long decodedBytes = 0;
        long started = SystemClock.elapsedRealtime();
        boolean inputDone = false;
        boolean outputDone = false;
        MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
        MediaFormat outputFormat = null;
        String mime = "unknown";
        try {
            extractor.setDataSource(context, uri, null);
            extractor.selectTrack(trackIndex);
            MediaFormat sourceFormat = extractor.getTrackFormat(trackIndex);
            mime = sourceFormat.getString(MediaFormat.KEY_MIME);
            codec = MediaCodec.createDecoderByType(mime);
            codec.configure(sourceFormat, null, null, 0);
            codec.start();
            while (!outputDone && SystemClock.elapsedRealtime() - started < 120000) {
                if (!inputDone) {
                    int inputIndex = codec.dequeueInputBuffer(10000);
                    if (inputIndex >= 0) {
                        ByteBuffer input = codec.getInputBuffer(inputIndex);
                        if (input == null) throw new AssertionError("Decoder input buffer missing");
                        input.clear();
                        int size = extractor.readSampleData(input, 0);
                        if (size < 0) {
                            codec.queueInputBuffer(inputIndex, 0, 0,
                                    Math.max(0, extractor.getSampleTime()), MediaCodec.BUFFER_FLAG_END_OF_STREAM);
                            inputDone = true;
                        } else {
                            long pts = Math.max(0, extractor.getSampleTime());
                            codec.queueInputBuffer(inputIndex, 0, size, pts, extractor.getSampleFlags());
                            extractor.advance();
                        }
                    }
                }
                int outputIndex = codec.dequeueOutputBuffer(info, 10000);
                if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    outputFormat = codec.getOutputFormat();
                } else if (outputIndex >= 0) {
                    if (info.size > 0) {
                        decodedBuffers++;
                        decodedBytes += info.size;
                        if (pcm != null) {
                            ByteBuffer output = codec.getOutputBuffer(outputIndex);
                            if (output == null) throw new AssertionError("Decoder output buffer missing");
                            ByteBuffer slice = output.duplicate();
                            slice.position(info.offset);
                            slice.limit(info.offset + info.size);
                            byte[] bytes = new byte[slice.remaining()];
                            slice.get(bytes);
                            pcm.write(bytes);
                        }
                    }
                    outputDone = (info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0;
                    codec.releaseOutputBuffer(outputIndex, false);
                }
            }
            if (!outputDone) throw new AssertionError("Decoder did not reach EOS for " + mime);
            if (decodedBuffers == 0) throw new AssertionError("Decoder returned no samples for " + mime);
            JSONObject result = new JSONObject().put("mime", mime)
                    .put("durationUs", sourceFormat.containsKey(MediaFormat.KEY_DURATION)
                            ? sourceFormat.getLong(MediaFormat.KEY_DURATION) : -1)
                    .put("decodedBuffers", decodedBuffers).put("decodedBytes", decodedBytes)
                    .put("reachedEos", true);
            if (outputFormat != null) {
                if (outputFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE))
                    result.put("sampleRate", outputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE));
                if (outputFormat.containsKey(MediaFormat.KEY_CHANNEL_COUNT))
                    result.put("channels", outputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT));
                if (outputFormat.containsKey(MediaFormat.KEY_PCM_ENCODING))
                    result.put("pcmEncoding", outputFormat.getInteger(MediaFormat.KEY_PCM_ENCODING));
                if (outputFormat.containsKey(MediaFormat.KEY_WIDTH)) result.put("width", outputFormat.getInteger(MediaFormat.KEY_WIDTH));
                if (outputFormat.containsKey(MediaFormat.KEY_HEIGHT)) result.put("height", outputFormat.getInteger(MediaFormat.KEY_HEIGHT));
            }
            return result;
        } finally {
            if (pcm != null) pcm.close();
            try { if (codec != null) { codec.stop(); codec.release(); } } catch (Exception ignored) {}
            extractor.release();
        }
    }

    private static JSONObject inspectMp4(Context context, Uri uri, File root, String label) throws Exception {
        MediaExtractor extractor = new MediaExtractor();
        JSONArray tracks = new JSONArray();
        int videoTrack = -1;
        int audioTrack = -1;
        try {
            extractor.setDataSource(context, uri, null);
            for (int i = 0; i < extractor.getTrackCount(); i++) {
                MediaFormat format = extractor.getTrackFormat(i);
                String mime = format.getString(MediaFormat.KEY_MIME);
                JSONObject track = new JSONObject().put("index", i).put("mime", mime)
                        .put("durationUs", format.containsKey(MediaFormat.KEY_DURATION)
                                ? format.getLong(MediaFormat.KEY_DURATION) : -1);
                if (format.containsKey(MediaFormat.KEY_WIDTH)) track.put("width", format.getInteger(MediaFormat.KEY_WIDTH));
                if (format.containsKey(MediaFormat.KEY_HEIGHT)) track.put("height", format.getInteger(MediaFormat.KEY_HEIGHT));
                tracks.put(track);
                if (mime.startsWith("video/")) videoTrack = i;
                if (mime.startsWith("audio/")) audioTrack = i;
            }
        } finally { extractor.release(); }
        if (videoTrack < 0) throw new AssertionError("MP4 has no video track");
        JSONObject result = new JSONObject().put("tracks", tracks)
                .put("video", decodeTrack(context, uri, videoTrack, null));
        if (audioTrack >= 0) {
            File pcm = new File(root, label + "_audio.pcm");
            result.put("audio", decodeTrack(context, uri, audioTrack, pcm))
                    .put("decodedAudioFile", pcm.getAbsolutePath()).put("decodedAudioBytes", pcm.length());
        } else result.put("audio", JSONObject.NULL);
        return result;
    }

    private static JSONObject inspectGif(Context context, Uri uri, File file) throws Exception {
        byte[] signature;
        try (InputStream input = context.getContentResolver().openInputStream(uri)) {
            if (input == null) throw new AssertionError("GIF cannot be opened");
            signature = new byte[6];
            if (input.read(signature) != 6) throw new AssertionError("GIF header is truncated");
        }
        String sig = new String(signature, StandardCharsets.US_ASCII);
        if (!"GIF87a".equals(sig) && !"GIF89a".equals(sig)) throw new AssertionError("Invalid GIF signature: " + sig);
        android.graphics.Movie movie;
        try (InputStream input = context.getContentResolver().openInputStream(uri)) {
            movie = android.graphics.Movie.decodeStream(input);
        }
        if (movie == null || movie.width() <= 0 || movie.height() <= 0 || movie.duration() <= 0)
            throw new AssertionError("GIF animation did not decode");
        Bitmap frame = Bitmap.createBitmap(movie.width(), movie.height(), Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(frame);
        Set<Integer> unique = new HashSet<>();
        int step = Math.max(10, movie.duration() / 40);
        for (int ms = 0; ms < movie.duration(); ms += step) {
            movie.setTime(ms);
            frame.eraseColor(android.graphics.Color.TRANSPARENT);
            movie.draw(canvas, 0, 0);
            int hash = 1;
            int dx = Math.max(1, frame.getWidth() / 12);
            int dy = Math.max(1, frame.getHeight() / 12);
            for (int y = 0; y < frame.getHeight(); y += dy)
                for (int x = 0; x < frame.getWidth(); x += dx) hash = 31 * hash + frame.getPixel(x, y);
            unique.add(hash);
        }
        frame.recycle();
        if (unique.size() < 2) throw new AssertionError("GIF has no changing animation frames");
        return new JSONObject().put("signature", sig).put("bytes", file.length())
                .put("width", movie.width()).put("height", movie.height())
                .put("durationMs", movie.duration()).put("sampledUniqueFrames", unique.size());
    }

    private static JSONObject output(Instrumentation runner, Context context, ExportQueue queue,
                                     String id, String extension, String mime, File root) throws Exception {
        JSONObject current = job(runner, queue, id);
        if (!"completed".equals(current.optString("state")) || !current.has("uri"))
            throw new AssertionError("Successful export did not complete: " + current);
        Uri uri = Uri.parse(current.getString("uri"));
        String name = "Edited_" + id + "." + extension;
        JSONObject row = savedRow(context, uri, name, mime);
        File copy = new File(root, id + "." + extension);
        writeNew(copy, read(context.getContentResolver().openInputStream(uri)));
        row.put("sha256", sha(java.nio.file.Files.readAllBytes(copy.toPath())))
                .put("copy", copy.getAbsolutePath())
                .put("elapsedMs", current.optLong("finishedAt") - current.optLong("startedAt"));
        if ("video/mp4".equals(mime)) row.put("decode", inspectMp4(context, uri, root, id));
        else row.put("animation", inspectGif(context, uri, copy));
        return row;
    }

    /** Retry one explicit failed task-owned job and independently inspect its publication. */
    public static void retryFailed(Instrumentation runner, String id) {
        Bundle result = new Bundle();
        ExportQueue queue = null;
        try {
            if (id == null || !id.matches("[a-zA-Z0-9_-]{1,80}"))
                throw new AssertionError("Explicit failed task-owned job ID required");
            Context context = runner.getTargetContext();
            queue = main(runner, () -> ExportQueue.Companion.get(context));
            ExportQueue active = queue;
            JSONObject before = job(runner, active, id);
            String outputName = "Edited_" + id + ".mp4";
            if (!"failed".equals(before.optString("state")) || before.has("uri") ||
                    countNamed(context, MediaStore.Video.Media.EXTERNAL_CONTENT_URI, outputName) != 0)
                throw new AssertionError("Retry fixture is not a failed unpublished job: " + before);
            long freeBefore = new android.os.StatFs(context.getCacheDir().getPath()).getAvailableBytes();
            File root = new File(context.getFilesDir(), "task09b_retry_" + UUID.randomUUID());
            if (!root.mkdir()) throw new AssertionError("Unique retry evidence folder required");
            main(runner, () -> { active.retry(id); return null; });
            JSONArray progress = new JSONArray();
            JSONObject terminal = waitTerminal(runner, active, id, 120000, progress);
            if (!"completed".equals(terminal.optString("state")))
                throw new AssertionError("Failed job did not recover: " + terminal);
            JSONObject published = output(runner, context, active, id, "mp4", "video/mp4", root);
            int rows = countNamed(context, MediaStore.Video.Media.EXTERNAL_CONTENT_URI, outputName);
            if (rows != 1) throw new AssertionError("Retry created duplicate or missing output rows: " + rows);
            JSONObject report = new JSONObject().put("status", "PASS").put("jobId", id)
                    .put("stateBefore", before.getString("state")).put("errorBefore", before.optString("error"))
                    .put("stateAfter", terminal.getString("state")).put("output", published)
                    .put("namedOutputRows", rows).put("freeBytesBefore", freeBefore)
                    .put("progress", progress).put("scope", "same persisted failed job, retry after cache-temp fix, MediaCodec decode to EOS");
            writeNew(new File(root, "report.json"), report.toString().getBytes(StandardCharsets.UTF_8));
            result.putString("stream", "TASK09B_EXPORT_FAILED_RETRY_PASS:" + report);
            runner.finish(Activity.RESULT_OK, result);
        } catch (Throwable error) {
            result.putString("stream", "TASK09B_EXPORT_FAILED_RETRY_FAIL:" + error);
            runner.finish(Activity.RESULT_CANCELED, result);
        }
    }

    private static JSONArray safGrants(Context context) throws Exception {
        List<String> values = new ArrayList<>();
        for (android.content.UriPermission grant : context.getContentResolver().getPersistedUriPermissions())
            values.add(grant.getUri().toString() + "|" + grant.isReadPermission() + "|" + grant.isWritePermission());
        Collections.sort(values);
        JSONArray result = new JSONArray();
        for (String value : values) result.put(value);
        return result;
    }

    private static JSONObject splitReordered(JSONObject saved) throws Exception {
        JSONObject project = clone(saved);
        JSONObject source = project.getJSONArray("clips").getJSONObject(0);
        long in = source.getLong("inMs");
        long end = source.getLong("outMs");
        long split = in + (end - in) / 2;
        JSONObject latter = clone(source).put("inMs", split).put("outMs", end);
        JSONObject former = clone(source).put("inMs", in).put("outMs", split);
        project.put("clips", new JSONArray().put(latter).put(former));
        project.put("title", "PROMPT09B split reorder audio subtitles");
        JSONArray audio = project.getJSONObject("effects").optJSONArray("audioTracks");
        if (audio == null || audio.length() == 0) throw new AssertionError("Saved project audio track is required");
        audio.getJSONObject(0).put("offsetMs", 3500);
        return project;
    }

    private static JSONObject transformSpeed(JSONObject saved) throws Exception {
        JSONObject project = clone(saved);
        JSONObject clip = project.getJSONArray("clips").getJSONObject(0);
        clip.put("cropLeft", 0.1).put("cropRight", 0.9).put("rotation", 90).put("flipH", true);
        JSONObject effects = project.getJSONObject("effects");
        effects.put("speed", 1.25).put("bitrate", 2000000);
        JSONArray cues = effects.optJSONArray("subtitles");
        if (cues != null) for (int i = 0; i < cues.length(); i++) {
            JSONObject cue = cues.getJSONObject(i);
            cue.put("startMs", Math.round(cue.getLong("startMs") / 1.25));
            cue.put("endMs", Math.round(cue.getLong("endMs") / 1.25));
        }
        project.put("title", "PROMPT09B crop rotate speed subtitles");
        return project;
    }

    private static JSONObject longForCancel(JSONObject saved) throws Exception {
        JSONObject project = clone(saved);
        JSONObject clip = project.getJSONArray("clips").getJSONObject(0);
        project.put("clips", new JSONArray().put(clone(clip)).put(clone(clip)));
        project.getJSONObject("effects").put("height", 480).put("fps", 60)
                .put("bitrate", 1000000).put("speed", 1.0);
        project.put("title", "PROMPT09B running cancel retry");
        return project;
    }

    private static String enqueue(Instrumentation runner, ExportQueue queue, JSONObject project) throws Exception {
        @SuppressWarnings("unchecked") Map<String, Object> value = (Map<String, Object>) convert(project);
        return main(runner, () -> queue.enqueue(value));
    }

    public static void run(Instrumentation runner, String projectId) {
        Bundle result = new Bundle();
        try {
            if (projectId == null || !projectId.matches("[A-Za-z0-9_-]{1,80}"))
                throw new AssertionError("An existing task-owned project ID is required");
            Context context = runner.getTargetContext();
            File draft = new File(new File(context.getFilesDir(), "projects"), projectId + ".json");
            byte[] draftBytes = java.nio.file.Files.readAllBytes(draft.toPath());
            JSONObject saved = new JSONObject(new String(draftBytes, StandardCharsets.UTF_8));
            if (!projectId.equals(saved.getString("id"))) throw new AssertionError("Project identity changed");
            File root = new File(context.getFilesDir(), "task09b_export_integration_" + UUID.randomUUID());
            if (!root.mkdir()) throw new AssertionError("Unique evidence folder required");
            writeNew(new File(root, "saved_project.json"), draftBytes);
            JSONObject sourceClip = saved.getJSONArray("clips").getJSONObject(0);
            Uri source = Uri.parse(sourceClip.getString("mediaId"));
            byte[] sourceBytes = read(context.getContentResolver().openInputStream(source));
            String sourceHash = sha(sourceBytes);
            writeNew(new File(root, "source_video.bin"), sourceBytes);
            JSONObject audioTrack = saved.getJSONObject("effects").getJSONArray("audioTracks").getJSONObject(0);
            Uri addedAudio = Uri.parse(audioTrack.getString("uri"));
            byte[] audioBytes = read(context.getContentResolver().openInputStream(addedAudio));
            String audioHash = sha(audioBytes);
            writeNew(new File(root, "source_added_audio.wav"), audioBytes);
            JSONArray grantsBefore = safGrants(context);
            long freeBefore = new android.os.StatFs(context.getCacheDir().getPath()).getAvailableBytes();
            final ExportQueue queue = main(runner, () -> ExportQueue.Companion.get(context));
            int historyBefore = new JSONArray(main(runner, queue::list)).length();
            JSONArray cases = new JSONArray();

            JSONObject reordered = splitReordered(saved);
            JSONObject queuedCancel = clone(saved).put("title", "PROMPT09B queued cancel");
            AtomicReference<String> firstId = new AtomicReference<>();
            AtomicReference<String> queuedId = new AtomicReference<>();
            main(runner, () -> {
                firstId.set(queue.enqueue((Map<String, Object>) convert(reordered)));
                queuedId.set(queue.enqueue((Map<String, Object>) convert(queuedCancel)));
                queue.cancel(queuedId.get());
                return null;
            });
            JSONObject queuedResult = job(runner, queue, queuedId.get());
            if (!"cancelled".equals(queuedResult.optString("state")) || queuedResult.has("uri"))
                throw new AssertionError("Queued cancellation published output: " + queuedResult);
            JSONArray progress = new JSONArray();
            JSONObject multiDone = waitTerminal(runner, queue, firstId.get(), 180000, progress);
            if (!"completed".equals(multiDone.optString("state")))
                throw new AssertionError("Multi-clip export failed: " + multiDone);
            JSONObject multiOutput = output(runner, context, queue, firstId.get(), "mp4", "video/mp4", root);
            multiOutput.put("progressSamples", progress).put("clipOrder", new JSONArray()
                    .put("source second half").put("source first half"))
                    .put("requestedAddedAudioOffsetMs", 3500)
                    .put("savedSubtitleCueCount", saved.getJSONObject("effects").getJSONArray("subtitles").length());
            cases.put(new JSONObject().put("case", "multi_clip_reorder_audio_subtitles")
                    .put("queuedCancel", queuedResult).put("output", multiOutput).put("status", "PASS"));

            JSONObject transformed = transformSpeed(saved);
            String transformedId = enqueue(runner, queue, transformed);
            JSONObject transformedDone = waitTerminal(runner, queue, transformedId, 180000, new JSONArray());
            if (!"completed".equals(transformedDone.optString("state")))
                throw new AssertionError("Transformed export failed: " + transformedDone);
            JSONObject transformedOutput = output(runner, context, queue, transformedId, "mp4", "video/mp4", root);
            transformedOutput.put("expectedDurationMs", Math.round((sourceClip.getLong("outMs") -
                    sourceClip.getLong("inMs")) / 1.25)).put("expectedRotationDegrees", 90)
                    .put("expectedCrop", "left=0.1,right=0.9").put("expectedSpeed", 1.25);
            cases.put(new JSONObject().put("case", "crop_rotate_flip_speed")
                    .put("output", transformedOutput).put("status", "PASS"));

            JSONObject gifProject = clone(saved);
            gifProject.getJSONObject("effects").put("format", "gif").put("gifEdge", 160)
                    .put("gifFps", 5).put("bitrate", 1000000);
            gifProject.put("title", "PROMPT09B bounded GIF");
            String gifId = enqueue(runner, queue, gifProject);
            JSONObject gifDone = waitTerminal(runner, queue, gifId, 180000, new JSONArray());
            if (!"completed".equals(gifDone.optString("state"))) throw new AssertionError("GIF export failed: " + gifDone);
            JSONObject gifOutput = output(runner, context, queue, gifId, "gif", "image/gif", root);
            cases.put(new JSONObject().put("case", "gif_animation").put("output", gifOutput).put("status", "PASS"));

            JSONObject missing = clone(saved);
            missing.getJSONArray("clips").getJSONObject(0)
                    .put("mediaId", "content://media/external/video/media/999999999");
            missing.put("title", "PROMPT09B missing-source retry");
            String missingId = enqueue(runner, queue, missing);
            JSONObject missingFirst = waitTerminal(runner, queue, missingId, 60000, new JSONArray());
            if (!"failed".equals(missingFirst.optString("state")) || missingFirst.has("uri"))
                throw new AssertionError("Missing input did not fail safely: " + missingFirst);
            String firstError = missingFirst.optString("error");
            main(runner, () -> { queue.retry(missingId); return null; });
            JSONObject missingRetry = waitTerminal(runner, queue, missingId, 60000, new JSONArray());
            if (!"failed".equals(missingRetry.optString("state")) || missingRetry.has("uri") ||
                    countNamed(context, MediaStore.Video.Media.EXTERNAL_CONTENT_URI, "Edited_" + missingId + ".mp4") != 0)
                throw new AssertionError("Failed retry exposed output: " + missingRetry);
            cases.put(new JSONObject().put("case", "missing_source_failure_retry")
                    .put("sameIdentity", missingId.equals(missingRetry.optString("id")))
                    .put("firstError", firstError).put("retryError", missingRetry.optString("error"))
                    .put("outputRows", 0).put("status", "PASS"));

            String cancelId = enqueue(runner, queue, longForCancel(saved));
            boolean cancelledRunning = false;
            JSONObject cancelObservation = null;
            long cancelDeadline = SystemClock.elapsedRealtime() + 20000;
            while (SystemClock.elapsedRealtime() < cancelDeadline) {
                JSONObject current = job(runner, queue, cancelId);
                if ("running".equals(current.optString("state"))) {
                    cancelObservation = current;
                    File exportWork = new File(context.getFilesDir(), "export_work");
                    File runningTemp = new File(exportWork, "export_" + cancelId + ".mp4");
                    long tempDeadline = SystemClock.elapsedRealtime() + 3000;
                    while (!runningTemp.isFile() && SystemClock.elapsedRealtime() < tempDeadline)
                        SystemClock.sleep(10);
                    if (!exportWork.isDirectory() || !runningTemp.isFile())
                        throw new AssertionError("Running export temporary output is not in durable app files");
                    cancelObservation.put("temporaryPath", runningTemp.getAbsolutePath())
                            .put("temporaryBytesAtCancel", runningTemp.length())
                            .put("temporarySurvivesCacheTrim", !runningTemp.getAbsolutePath().startsWith(
                                    context.getCacheDir().getAbsolutePath()));
                    try {
                        main(runner, () -> { queue.cancel(cancelId); return null; });
                        cancelledRunning = true;
                    } catch (Exception late) {
                        cancelObservation.put("cancelError", late.getMessage());
                    }
                    break;
                }
                if ("completed".equals(current.optString("state")) ||
                        "finalizing".equals(current.optString("state")) ||
                        "failed".equals(current.optString("state"))) {
                    cancelObservation = current;
                    break;
                }
                SystemClock.sleep(10);
            }
            if (cancelledRunning) {
                JSONObject cancelled = job(runner, queue, cancelId);
                if (!"cancelled".equals(cancelled.optString("state")) || cancelled.has("uri") ||
                        countNamed(context, MediaStore.Video.Media.EXTERNAL_CONTENT_URI, "Edited_" + cancelId + ".mp4") != 0)
                    throw new AssertionError("Running cancellation exposed partial output: " + cancelled);
                main(runner, () -> { queue.retry(cancelId); return null; });
                JSONObject retried = waitTerminal(runner, queue, cancelId, 180000, new JSONArray());
                if (!"completed".equals(retried.optString("state")))
                    throw new AssertionError("Cancelled job retry failed: " + retried);
                JSONObject retryOutput = output(runner, context, queue, cancelId, "mp4", "video/mp4", root);
                if (countNamed(context, MediaStore.Video.Media.EXTERNAL_CONTENT_URI, "Edited_" + cancelId + ".mp4") != 1)
                    throw new AssertionError("Retry created duplicate MediaStore rows");
                cases.put(new JSONObject().put("case", "running_cancel_and_retry")
                        .put("cancelledJob", cancelled).put("retryOutput", retryOutput).put("status", "PASS"));
            } else {
                cases.put(new JSONObject().put("case", "running_cancel_and_retry")
                        .put("status", "PARTIAL").put("observation", cancelObservation == null
                                ? JSONObject.NULL : cancelObservation));
            }

            byte[] sourceAfter = read(context.getContentResolver().openInputStream(source));
            byte[] audioAfter = read(context.getContentResolver().openInputStream(addedAudio));
            byte[] draftAfter = java.nio.file.Files.readAllBytes(draft.toPath());
            JSONArray grantsAfter = safGrants(context);
            if (!sourceHash.equals(sha(sourceAfter)) || !audioHash.equals(sha(audioAfter)) ||
                    !sha(draftBytes).equals(sha(draftAfter)))
                throw new AssertionError("Source, added audio, or saved project changed during export");
            if (!grantsBefore.toString().equals(grantsAfter.toString()))
                throw new AssertionError("Persisted SAF grants changed during export");
            long freeAfter = new android.os.StatFs(context.getCacheDir().getPath()).getAvailableBytes();
            JSONObject report = new JSONObject().put("status", "PASS").put("projectId", projectId)
                    .put("projectSha256Before", sha(draftBytes)).put("projectSha256After", sha(draftAfter))
                    .put("sourceUri", source.toString()).put("sourceSha256Before", sourceHash)
                    .put("sourceSha256After", sha(sourceAfter)).put("addedAudioUri", addedAudio.toString())
                    .put("addedAudioBytes", audioBytes.length).put("addedAudioSha256Before", audioHash)
                    .put("addedAudioSha256After", sha(audioAfter))
                    .put("savedSubtitleCueCount", saved.getJSONObject("effects").getJSONArray("subtitles").length())
                    .put("safGrantsBefore", grantsBefore).put("safGrantsAfter", grantsAfter)
                    .put("freeBytesBefore", freeBefore).put("freeBytesAfter", freeAfter)
                    .put("historyRowsBefore", historyBefore).put("cases", cases)
                    .put("evidenceDirectory", root.getAbsolutePath())
                    .put("scope", "Production ExportQueue, MediaStore and full Android MediaCodec decode");
            writeNew(new File(root, "report.json"), report.toString().getBytes(StandardCharsets.UTF_8));
            result.putString("stream", "TASK09B_EXPORT_INTEGRATION_PASS:" + report);
            runner.finish(Activity.RESULT_OK, result);
        } catch (Throwable error) {
            result.putString("stream", "TASK09B_EXPORT_INTEGRATION_FAIL:" + error + "\n" +
                    android.util.Log.getStackTraceString(error));
            runner.finish(Activity.RESULT_CANCELED, result);
        }
    }
}
