package com.xrecorder.xrecorder.qa;

import android.app.Activity;
import android.app.Dialog;
import android.app.Instrumentation;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.os.SystemClock;
import android.view.ViewGroup;
import com.xrecorder.xrecorder.editor.EditorPreview;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import org.json.JSONObject;

/** Actual missing-source error, same-view recovery and SurfaceView lifecycle. */
public final class Task09PreviewRecoveryInstrumentation {
    private static Task08HistoryInstrumentation.Reply call(
            Instrumentation runner, EditorPreview preview, String method, Object arguments) throws Exception {
        Task08HistoryInstrumentation.Reply reply = new Task08HistoryInstrumentation.Reply();
        runner.runOnMainSync(() -> preview.onMethodCall(new MethodCall(method, arguments), reply));
        if (!reply.ready.await(20, TimeUnit.SECONDS)) throw new AssertionError("Lost " + method + " callback");
        return reply;
    }

    private static Map<String, Object> project(String uri) {
        boolean image = uri.endsWith(".jpg") || uri.endsWith(".png");
        return Map.of("id", "task09_source_probe", "title", "TASK09 source recovery",
                "clips", List.of(Map.of("mediaId", uri, "inMs", 0L, "outMs", 1000L,
                        "sourceDurationMs", 4000L, "isImage", image)), "effects", Map.of());
    }

    @SuppressWarnings("unchecked")
    public static void run(Instrumentation runner, String validUri) {
        EditorPreview[] preview = new EditorPreview[1];
        Dialog[] dialog = new Dialog[1];
        JSONObject report = new JSONObject();
        String failure = null;
        try {
            if (validUri == null || !validUri.matches(
                    "content://com[.]xrecorder[.]xrecorder[.]files/trash/task09_[A-Za-z0-9_]+[.](mp4|jpg|png)"))
                throw new AssertionError("Only a unique TASK09 private fixture is permitted");
            File source = new File(runner.getTargetContext().getFilesDir(), "trash/" + Uri.parse(validUri).getLastPathSegment());
            if (!source.isFile()) throw new AssertionError("Prepared fixture missing");
            long sourceBytes = source.length();
            int extension = validUri.lastIndexOf('.');
            String missing = validUri.substring(0, extension) + "_never_created" + validUri.substring(extension);
            if (new File(source.getParentFile(), Uri.parse(missing).getLastPathSegment()).exists())
                throw new AssertionError("Missing source unexpectedly exists; no data changed");
            Activity activity = runner.startActivitySync(new Intent().setClassName(
                    "com.xrecorder.xrecorder", "com.xrecorder.xrecorder.MainActivity")
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            runner.runOnMainSync(() -> {
                preview[0] = new EditorPreview(activity, 909, new BinaryMessenger() {
                    public void send(String channel, ByteBuffer message) { }
                    public void send(String channel, ByteBuffer message, BinaryReply reply) {
                        if (reply != null) reply.reply(null);
                    }
                    public void setMessageHandler(String channel, BinaryMessageHandler handler) { }
                });
                dialog[0] = new Dialog(activity);
                dialog[0].setContentView(preview[0].getView());
                dialog[0].show();
                dialog[0].getWindow().setLayout(ViewGroup.LayoutParams.MATCH_PARENT, 640);
            });
            long began = SystemClock.elapsedRealtime();
            report.put("isImage", !validUri.endsWith(".mp4"));
            Task08HistoryInstrumentation.Reply missingLoad = call(runner, preview[0], "load", project(missing));
            boolean visibleError = missingLoad.code != null;
            for (int i = 0; i < 200 && !visibleError; i++) {
                Task08HistoryInstrumentation.Reply state = call(runner, preview[0], "state", null);
                visibleError = ((Map<?, ?>) state.value).get("error") != null;
                if (!visibleError) SystemClock.sleep(50);
            }
            report.put("missingErrorObserved", visibleError).put("missingErrorMs", SystemClock.elapsedRealtime() - began);
            if (!visibleError) throw new AssertionError("Missing URI left a black preview without an error");
            began = SystemClock.elapsedRealtime();
            Task08HistoryInstrumentation.Reply reload = call(runner, preview[0], "load", project(validUri));
            if (reload.code != null) throw new AssertionError("Valid-source recovery failed:" + reload.message);
            call(runner, preview[0], "play", null);
            boolean rendered = false;
            for (int i = 0; i < 300 && !rendered; i++) {
                Map<String, Object> state = (Map<String, Object>) call(runner, preview[0], "state", null).value;
                if (state.get("error") != null) throw new AssertionError(state.get("error"));
                rendered = Boolean.TRUE.equals(state.get("renderedFirstFrame")) && Boolean.TRUE.equals(state.get("surfaceShown"));
                if (!rendered) SystemClock.sleep(50);
            }
            report.put("recoveredRealSurfaceFrame", rendered).put("recoveryMs", SystemClock.elapsedRealtime() - began);
            if (!rendered) throw new AssertionError("Valid-source recovery remained black");
            report.put("sourceBytesUnchanged", source.isFile() && source.length() == sourceBytes);
        } catch (Throwable error) {
            failure = error.toString();
        } finally {
            runner.runOnMainSync(() -> {
                if (preview[0] != null) preview[0].dispose();
                if (dialog[0] != null) dialog[0].dismiss();
            });
        }
        int[] active = {1};
        int[] releaseFailures = {0};
        for (int i = 0; i < 150; i++) {
            runner.runOnMainSync(() -> {
                active[0] = EditorPreview.Companion.activeCount();
                releaseFailures[0] = EditorPreview.Companion.releaseFailureCount();
            });
            if (active[0] == 0) break;
            SystemClock.sleep(100);
        }
        if (failure == null && (active[0] != 0 || releaseFailures[0] != 0))
            failure = "Preview resources did not drain";
        Bundle result = new Bundle();
        try {
            report.put("failure", failure == null ? JSONObject.NULL : failure)
                    .put("activeAfter", active[0]).put("releaseFailures", releaseFailures[0]);
            File file = new File(runner.getTargetContext().getFilesDir(),
                    "task09_source_probe_" + System.nanoTime() + ".json");
            if (!file.createNewFile()) throw new AssertionError("Evidence collision");
            try (FileOutputStream stream = new FileOutputStream(file)) {
                stream.write(report.toString().getBytes(StandardCharsets.UTF_8));
                stream.getFD().sync();
            }
            result.putString("stream", "TASK09_SOURCE_" + (failure == null ? "PASS" : "FAIL") + ":report=" + file.getName());
        } catch (Throwable error) {
            failure = error.toString();
            result.putString("stream", "TASK09_SOURCE_FAIL:" + failure);
        }
        runner.finish(failure == null ? Activity.RESULT_OK : Activity.RESULT_CANCELED, result);
    }
}
