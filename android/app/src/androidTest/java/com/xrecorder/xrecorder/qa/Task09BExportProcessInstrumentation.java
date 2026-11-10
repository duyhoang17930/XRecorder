package com.xrecorder.xrecorder.qa;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Context;
import android.content.ContextWrapper;
import android.net.Uri;
import android.os.Bundle;
import android.os.SystemClock;
import android.provider.MediaStore;
import com.xrecorder.xrecorder.editor.EditorBridge;
import com.xrecorder.xrecorder.editor.ExportQueue;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.security.MessageDigest;
import java.util.*;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import org.json.*;

/** Actual encoder interruption in an isolated queue; live histories stay intact. */
public final class Task09BExportProcessInstrumentation {
    private interface Checked<T> { T get() throws Exception; }
    private static <T> T main(Instrumentation runner, Checked<T> work) throws Exception {
        AtomicReference<T> value = new AtomicReference<>();
        AtomicReference<Exception> failure = new AtomicReference<>();
        runner.runOnMainSync(() -> { try { value.set(work.get()); } catch (Exception e) { failure.set(e); } });
        if (failure.get() != null) throw failure.get();
        return value.get();
    }
    private static void writeNew(File file, byte[] bytes) throws Exception {
        if (!file.createNewFile()) throw new AssertionError("Evidence already exists: " + file);
        try (FileOutputStream stream = new FileOutputStream(file)) { stream.write(bytes); stream.getFD().sync(); }
    }
    private static byte[] read(InputStream input) throws Exception {
        try (InputStream in = input; ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[16384]; int count;
            while ((count = in.read(buffer)) >= 0) out.write(buffer, 0, count);
            return out.toByteArray();
        }
    }
    private static String sha(byte[] bytes) throws Exception {
        byte[] hash = MessageDigest.getInstance("SHA-256").digest(bytes);
        StringBuilder out = new StringBuilder();
        for (byte b : hash) out.append("0123456789abcdef".charAt((b & 255) >>> 4)).append("0123456789abcdef".charAt(b & 15));
        return out.toString();
    }
    private static Object convert(Object value) throws Exception {
        if (value instanceof JSONObject) {
            Map<String, Object> map = new LinkedHashMap<>();
            Iterator<String> keys = ((JSONObject) value).keys();
            while (keys.hasNext()) { String key = keys.next(); map.put(key, convert(((JSONObject) value).get(key))); }
            return map;
        }
        if (value instanceof JSONArray) {
            List<Object> list = new ArrayList<>();
            for (int i = 0; i < ((JSONArray) value).length(); i++) list.add(convert(((JSONArray) value).get(i)));
            return list;
        }
        return value == JSONObject.NULL ? null : value;
    }
    private static Context isolated(Context base, File root) {
        return new ContextWrapper(base) {
            @Override public File getFilesDir() { return root; }
            @Override public File getCacheDir() { return new File(root, "cache"); }
        };
    }
    private static JSONObject job(Instrumentation runner, ExportQueue queue) throws Exception {
        return new JSONArray(main(runner, queue::list)).getJSONObject(0);
    }
    private static JSONObject retainedCopy(Context context) throws Exception {
        JSONObject record = new JSONObject(new String(Files.readAllBytes(new File(context.getFilesDir(), "media_transfer.json").toPath()), StandardCharsets.UTF_8));
        if (!record.optString("name").matches("3H_[a-f0-9]{8}_TASK09B_.*") || !"completed".equals(record.optString("state")) || record.optBoolean("move"))
            throw new AssertionError("Completed controlled QA copy required");
        Uri destination = Uri.parse(record.getString("destination"));
        if (!"primary:Documents/Task09B_SAF_20261109_f64203".equals(android.provider.DocumentsContract.getTreeDocumentId(destination)))
            throw new AssertionError("Controlled QA tree required");
        Uri tree = android.provider.DocumentsContract.buildTreeDocumentUri(destination.getAuthority(), android.provider.DocumentsContract.getTreeDocumentId(destination));
        boolean retained = false;
        for (android.content.UriPermission permission : context.getContentResolver().getPersistedUriPermissions())
            if (permission.getUri().equals(tree) && permission.isReadPermission() && permission.isWritePermission()) retained = true;
        if (!retained) throw new AssertionError("Real persisted tree grant did not survive restart");
        byte[] bytes = read(context.getContentResolver().openInputStream(destination));
        if (!sha(bytes).equals(record.getString("sha256"))) throw new AssertionError("Copied document bytes changed");
        return new JSONObject().put("tree", tree.toString()).put("destination", destination.toString())
                .put("sha256", sha(bytes)).put("bytes", bytes.length).put("persistedReadWrite", true);
    }
    public static void backupOwnedMedia(Instrumentation runner, String value) {
        Bundle result = new Bundle();
        try {
            Context context = runner.getTargetContext(); Uri uri = Uri.parse(value);
            if (!"content".equals(uri.getScheme()) || !"media".equals(uri.getAuthority())) throw new AssertionError("Owned MediaStore output required");
            try (android.database.Cursor cursor = context.getContentResolver().query(uri,
                    new String[]{MediaStore.MediaColumns.OWNER_PACKAGE_NAME}, null, null, null)) {
                if (cursor == null || !cursor.moveToFirst() || !context.getPackageName().equals(cursor.getString(0)))
                    throw new AssertionError("Not app-owned");
            }
            byte[] bytes = read(context.getContentResolver().openInputStream(uri));
            if (bytes.length == 0 || bytes.length > 32 * 1024 * 1024) throw new AssertionError("Unexpected output size");
            File root = new File(context.getFilesDir(), "task09b_owned_media_backup_" + UUID.randomUUID());
            if (!root.mkdir()) throw new AssertionError("Fresh evidence directory required");
            File file = new File(root, "output.bin"); writeNew(file, bytes);
            JSONObject report = new JSONObject().put("status", "PASS").put("uri", value)
                    .put("mime", context.getContentResolver().getType(uri)).put("file", file.getAbsolutePath())
                    .put("bytes", bytes.length).put("sha256", sha(bytes)).put("retainedCopy", retainedCopy(context));
            writeNew(new File(root, "report.json"), report.toString().getBytes(StandardCharsets.UTF_8));
            result.putString("stream", "TASK09B_OWNED_MEDIA_BACKUP_PASS:" + report);
            runner.finish(Activity.RESULT_OK, result);
        } catch (Throwable error) {
            result.putString("stream", "TASK09B_OWNED_MEDIA_BACKUP_FAIL:" + error);
            runner.finish(Activity.RESULT_CANCELED, result);
        }
    }
    public static void run(Instrumentation runner, String action, String name) {
        Bundle result = new Bundle(); ExportQueue queue = null;
        try {
            Context context = runner.getTargetContext();
            if ("export-process-start".equals(action)) {
                name = "task09b_export_process_" + UUID.randomUUID();
                File root = new File(context.getFilesDir(), name);
                if (!root.mkdir() || !new File(root, "cache").mkdir()) throw new AssertionError("Fresh context required");
                String projectId = "task09b_process_" + UUID.randomUUID();
                Uri source = Uri.parse("content://media/external/images/media/28");
                byte[] sourceBytes = read(context.getContentResolver().openInputStream(source));
                writeNew(new File(root, "source.png"), sourceBytes);
                JSONObject clip = new JSONObject().put("mediaId", source.toString()).put("title", "QA still")
                        .put("isImage", true).put("inMs", 0).put("outMs", 60000).put("sourceDurationMs", 60000);
                JSONObject project = new JSONObject().put("version", 1).put("id", projectId)
                        .put("title", "TASK09B interrupted encoder").put("updatedAt", System.currentTimeMillis())
                        .put("clips", new JSONArray().put(clip)).put("effects", new JSONObject()
                                .put("height", 480).put("aspect", 4.0 / 3.0).put("bitrate", 1000000));
                byte[] draftBytes = project.toString().getBytes(StandardCharsets.UTF_8);
                writeNew(new File(root, "project.json"), draftBytes);
                File draft = new File(new File(context.getFilesDir(), "projects"), projectId + ".json");
                if (draft.exists()) throw new AssertionError("Never replace an existing draft");
                CountDownLatch saved = new CountDownLatch(1);
                AtomicReference<String> error = new AtomicReference<>();
                new EditorBridge(context).onMethodCall(new MethodCall("save", project.toString()), new MethodChannel.Result() {
                    @Override public void success(Object value) { saved.countDown(); }
                    @Override public void error(String code, String message, Object details) { error.set(code + ": " + message); saved.countDown(); }
                    @Override public void notImplemented() { error.set("save not implemented"); saved.countDown(); }
                });
                if (!saved.await(30, TimeUnit.SECONDS) || error.get() != null) throw new AssertionError(error.get());
                if (!Arrays.equals(draftBytes, Files.readAllBytes(draft.toPath()))) throw new AssertionError("Draft save mismatch");
                queue = main(runner, () -> new ExportQueue(isolated(context, root)));
                ExportQueue active = queue;
                @SuppressWarnings("unchecked") Map<String, Object> input = (Map<String, Object>) convert(project);
                String id = main(runner, () -> active.enqueue(input));
                JSONObject metadata = new JSONObject().put("root", name).put("jobId", id).put("projectId", projectId)
                        .put("sourceUri", source.toString()).put("sourceSha256", sha(sourceBytes)).put("draftSha256", sha(draftBytes));
                writeNew(new File(root, "metadata.json"), metadata.toString().getBytes(StandardCharsets.UTF_8));
                long deadline = SystemClock.elapsedRealtime() + 60000;
                while (SystemClock.elapsedRealtime() < deadline) {
                    JSONObject current = job(runner, active);
                    if ("failed".equals(current.getString("state"))) throw new AssertionError(current.toString());
                    int progress = current.optInt("progress");
                    File partial = new File(new File(root, "cache"), "export_" + id + ".mp4");
                    if ("running".equals(current.getString("state")) && progress > 0 && progress < 100 && partial.length() > 32) {
                        JSONObject ready = new JSONObject().put("metadata", metadata).put("job", current)
                                .put("pid", android.os.Process.myPid()).put("uid", android.os.Process.myUid()).put("partialBytes", partial.length());
                        writeNew(new File(root, "ready.json"), ready.toString().getBytes(StandardCharsets.UTF_8));
                        Bundle status = new Bundle(); status.putString("stream", "TASK09B_EXPORT_PROCESS_READY:" + ready); runner.sendStatus(0, status);
                        SystemClock.sleep(60000);
                        throw new AssertionError("Host did not interrupt within the controlled window");
                    }
                    SystemClock.sleep(100);
                }
                throw new AssertionError("No real running encoder progress before deadline");
            }
            if (!"export-process-recover".equals(action) || name == null || !name.matches("task09b_export_process_[a-f0-9-]{36}"))
                throw new AssertionError("Explicit retained context required");
            File root = new File(context.getFilesDir(), name);
            JSONObject metadata = new JSONObject(new String(Files.readAllBytes(new File(root, "metadata.json").toPath()), StandardCharsets.UTF_8));
            File draft = new File(new File(context.getFilesDir(), "projects"), metadata.getString("projectId") + ".json");
            if (!sha(Files.readAllBytes(draft.toPath())).equals(metadata.getString("draftSha256"))) throw new AssertionError("Draft changed across process death");
            Uri source = Uri.parse(metadata.getString("sourceUri"));
            if (!sha(read(context.getContentResolver().openInputStream(source))).equals(metadata.getString("sourceSha256"))) throw new AssertionError("Source changed across process death");
            queue = main(runner, () -> new ExportQueue(isolated(context, root)));
            ExportQueue active = queue;
            JSONObject interrupted = job(runner, active);
            if (!"failed".equals(interrupted.getString("state")) || interrupted.has("uri")) throw new AssertionError("Interrupted job falsely Saved: " + interrupted);
            writeNew(new File(root, "interrupted.json"), interrupted.toString().getBytes(StandardCharsets.UTF_8));
            main(runner, () -> { active.retry(metadata.getString("jobId")); return null; });
            long started = SystemClock.elapsedRealtime(); JSONArray samples = new JSONArray(); JSONObject completed = null;
            while (SystemClock.elapsedRealtime() - started < 240000) {
                JSONObject current = job(runner, active);
                samples.put(new JSONObject().put("state", current.getString("state")).put("progress", current.optInt("progress")));
                if ("completed".equals(current.getString("state"))) { completed = current; break; }
                if ("failed".equals(current.getString("state"))) throw new AssertionError(current.toString());
                SystemClock.sleep(300);
            }
            if (completed == null) throw new AssertionError("Retry deadline");
            Uri uri = Uri.parse(completed.getString("uri"));
            byte[] bytes = read(context.getContentResolver().openInputStream(uri));
            if (bytes.length <= 0) throw new AssertionError("Empty retry output");
            writeNew(new File(root, "retry_output.mp4"), bytes);
            int publications;
            try (android.database.Cursor cursor = context.getContentResolver().query(MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                    new String[]{MediaStore.MediaColumns._ID}, "owner_package_name=? AND _display_name=?",
                    new String[]{context.getPackageName(), "Edited_" + metadata.getString("jobId") + ".mp4"}, null)) {
                publications = cursor == null ? 0 : cursor.getCount();
            }
            if (publications != 1) throw new AssertionError("Duplicate or missing publication: " + publications);
            if (!sha(read(context.getContentResolver().openInputStream(source))).equals(metadata.getString("sourceSha256"))
                    || !sha(Files.readAllBytes(draft.toPath())).equals(metadata.getString("draftSha256")))
                throw new AssertionError("Retry modified source or draft");
            JSONObject report = new JSONObject().put("status", "PASS").put("root", name).put("metadata", metadata)
                    .put("interrupted", interrupted).put("completed", completed).put("samples", samples)
                    .put("retryMs", SystemClock.elapsedRealtime() - started).put("outputBytes", bytes.length)
                    .put("outputSha256", sha(bytes)).put("publications", publications)
                    .put("sourceAndProductionDraftByteExact", true).put("retainedCopy", retainedCopy(context))
                    .put("scope", "Real process death, isolated production ExportQueue, explicit retry; no partial MP4 repair claim");
            writeNew(new File(root, "report.json"), report.toString().getBytes(StandardCharsets.UTF_8));
            result.putString("stream", "TASK09B_EXPORT_PROCESS_PASS:" + report);
            runner.finish(Activity.RESULT_OK, result);
        } catch (Throwable error) {
            result.putString("stream", "TASK09B_EXPORT_PROCESS_FAIL:" + error);
            runner.finish(Activity.RESULT_CANCELED, result);
        } finally {
            if (queue != null) { ExportQueue closing = queue; try { main(runner, () -> { closing.close(); return null; }); } catch (Exception ignored) {} }
        }
    }
}
