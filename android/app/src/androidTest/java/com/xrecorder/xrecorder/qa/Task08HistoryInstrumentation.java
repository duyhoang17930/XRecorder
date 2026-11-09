package com.xrecorder.xrecorder.qa;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.ContextWrapper;
import android.os.Bundle;
import com.xrecorder.xrecorder.editor.TranscriptionBridge;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileInputStream;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import org.json.JSONArray;
import org.json.JSONObject;

/** Isolated history fixtures: never replace the application's real journal. */
public final class Task08HistoryInstrumentation {
    static final class Reply implements MethodChannel.Result {
        final CountDownLatch ready = new CountDownLatch(1);
        Object value;
        String code;
        String message;
        @Override public void success(Object data) { value = data; ready.countDown(); }
        @Override public void error(String error, String message, Object details) {
            code = error; this.message = message; ready.countDown();
        }
        @Override public void notImplemented() { code = "not_implemented"; ready.countDown(); }
    }

    private static Reply call(Instrumentation runner, TranscriptionBridge bridge, String method) throws Exception {
        return call(runner, bridge, method, null);
    }

    static Reply call(Instrumentation runner, TranscriptionBridge bridge, String method, Object arguments) throws Exception {
        Reply reply = new Reply();
        runner.runOnMainSync(() -> bridge.handle(new MethodCall(method, arguments), reply));
        if (!reply.ready.await(10, TimeUnit.SECONDS)) throw new AssertionError("Bridge timeout");
        return reply;
    }

    public static void run(Instrumentation runner) {
        Bundle output = new Bundle();
        TranscriptionBridge bridge = null;
        try {
            File root = new File(runner.getTargetContext().getFilesDir(),
                    "task08_duplicate_" + System.currentTimeMillis());
            if (!root.mkdir()) throw new AssertionError("New fixture directory required");
            JSONArray rows = new JSONArray();
            for (String language : new String[]{"en", "vi"}) {
                rows.put(new JSONObject().put("id", "duplicate_fixture_id")
                        .put("type", "speech").put("model", "tiny")
                        .put("language", language).put("state", "completed")
                        .put("segments", new JSONArray()).put("contractVersion", 2));
            }
            byte[] before = rows.toString().getBytes(StandardCharsets.UTF_8);
            File journal = new File(root, "transcription_jobs.json");
            try (FileOutputStream stream = new FileOutputStream(journal)) { stream.write(before); }
            bridge = new TranscriptionBridge(new ContextWrapper(runner.getTargetContext()) {
                @Override public File getFilesDir() { return root; }
            });
            Reply listed = call(runner, bridge, "transcriptionJobs");
            if (!"history_unavailable".equals(listed.code)) {
                int count = listed.value instanceof List ? ((List<?>) listed.value).size() : -1;
                throw new AssertionError("Duplicate history silently collapsed: input=2/listed=" + count);
            }
            if (!"history_unavailable".equals(call(runner, bridge, "transcriptionStart").code)) {
                throw new AssertionError("Read-only duplicate journal accepted a write");
            }
            ByteArrayOutputStream readBack = new ByteArrayOutputStream();
            try (FileInputStream stream = new FileInputStream(journal)) {
                byte[] buffer = new byte[4096];
                int count;
                while ((count = stream.read(buffer)) >= 0) readBack.write(buffer, 0, count);
            }
            if (!Arrays.equals(before, readBack.toByteArray())) {
                throw new AssertionError("Fixture bytes changed");
            }
            output.putString("stream", "TASK08_HISTORY_DUPLICATE_PASS:readonly;write rejected;bytes exact;fixture=" + root);
            runner.finish(Activity.RESULT_OK, output);
        } catch (Throwable error) {
            output.putString("stream", "TASK08_HISTORY_DUPLICATE_FAIL:" + error);
            runner.finish(Activity.RESULT_CANCELED, output);
        } finally {
            if (bridge != null) bridge.dispose();
        }
    }
}
