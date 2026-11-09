package com.xrecorder.xrecorder.qa;

import android.app.Activity;
import android.app.Dialog;
import android.app.Instrumentation;
import android.content.Intent;
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
import java.util.Map;
import java.util.concurrent.TimeUnit;
import org.json.JSONArray;
import org.json.JSONObject;

/** Real production preview, SurfaceView, seek and reload; only transport is local. */
public final class Task08PreviewInstrumentation {
    private static Object call(Instrumentation runner, EditorPreview preview, String method, Object arguments) throws Exception {
        Task08HistoryInstrumentation.Reply reply = new Task08HistoryInstrumentation.Reply();
        runner.runOnMainSync(() -> preview.onMethodCall(new MethodCall(method, arguments), reply));
        if (!reply.ready.await(20, TimeUnit.SECONDS)) throw new AssertionError("Preview callback timed out");
        if (reply.code != null) throw new AssertionError("Preview " + method + ":" + reply.code + ":" + reply.message);
        return reply.value;
    }

    @SuppressWarnings("unchecked")
    public static void run(Instrumentation runner, String manifest, int cycles) {
        Bundle result = new Bundle();
        EditorPreview[] preview = new EditorPreview[1];
        Dialog[] dialog = new Dialog[1];
        Activity[] activity = new Activity[1];
        JSONArray timings = new JSONArray();
        String failure = null;
        boolean overlapRejected = false, disposedLoadRejected = false;
        try {
            if (cycles < 1 || cycles > 30) throw new AssertionError("Invalid preview cycle count");
            if (manifest == null || !manifest.matches("task08_media_input_[0-9]+\\.json")) throw new AssertionError("Explicit QA manifest required");
            File base = runner.getTargetContext().getFilesDir();
            JSONObject inputs = new JSONObject(new String(Task08MediaRegressionInstrumentation.read(new File(base, manifest)), StandardCharsets.UTF_8));
            String id = inputs.getString("eightTrackMix");
            if (!id.matches("audio_[0-9]+_eightTrackMix")) throw new AssertionError("Only QA eight-track draft allowed");
            Object project = Task08MediaRegressionInstrumentation.nativeValue(new JSONObject(new String(
                    Task08MediaRegressionInstrumentation.read(new File(base, "projects/" + id + ".json")), StandardCharsets.UTF_8)));
            activity[0] = runner.startActivitySync(new Intent().setClassName("com.xrecorder.xrecorder",
                    "com.xrecorder.xrecorder.MainActivity").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            runner.runOnMainSync(() -> {
                preview[0] = new EditorPreview(activity[0], 808, new BinaryMessenger() {
                    public void send(String channel, ByteBuffer message) { }
                    public void send(String channel, ByteBuffer message, BinaryReply reply) { if (reply != null) reply.reply(null); }
                    public void setMessageHandler(String channel, BinaryMessageHandler handler) { }
                });
                dialog[0] = new Dialog(activity[0]);
                dialog[0].setContentView(preview[0].getView());
                dialog[0].show();
                dialog[0].getWindow().setLayout(ViewGroup.LayoutParams.MATCH_PARENT, 640);
            });
            for (int i = 0; i < cycles; i++) {
                long began = SystemClock.elapsedRealtime();
                call(runner, preview[0], "load", project);
                call(runner, preview[0], "play", null);
                boolean frame = false;
                for (int n = 0; n < 150; n++) {
                    Map<String, Object> state = (Map<String, Object>) call(runner, preview[0], "state", null);
                    if (state.get("error") != null) throw new AssertionError("Native preview error:" + state.get("error"));
                    if (Boolean.TRUE.equals(state.get("renderedFirstFrame")) && Boolean.TRUE.equals(state.get("surfaceShown"))) {
                        if (((Number) state.get("durationMs")).longValue() != 4000)
                            throw new AssertionError("Preview timeline changed duration");
                        frame = true; break;
                    }
                    SystemClock.sleep(50);
                }
                if (!frame) throw new AssertionError("Actual preview never rendered");
                call(runner, preview[0], "seek", 1000L);
                timings.put(SystemClock.elapsedRealtime() - began);
            }
            Task08HistoryInstrumentation.Reply pending = new Task08HistoryInstrumentation.Reply();
            Task08HistoryInstrumentation.Reply overlap = new Task08HistoryInstrumentation.Reply();
            runner.runOnMainSync(() -> {
                preview[0].onMethodCall(new MethodCall("load", project), pending);
                preview[0].onMethodCall(new MethodCall("load", project), overlap);
                preview[0].dispose();
                dialog[0].dismiss();
            });
            if (!pending.ready.await(20, TimeUnit.SECONDS) || !overlap.ready.await(20, TimeUnit.SECONDS))
                throw new AssertionError("Pending preview callback lost on disposal");
            overlapRejected = "editor_preview".equals(overlap.code);
            disposedLoadRejected = "editor_preview".equals(pending.code);
            if (!overlapRejected || !disposedLoadRejected) throw new AssertionError("Disposed/overlapping load resurrected a preview");
        } catch (Throwable error) {
            failure = error.toString();
        } finally {
            runner.runOnMainSync(() -> {
                if (preview[0] != null) preview[0].dispose();
                if (dialog[0] != null) dialog[0].dismiss();
            });
        }
        int[] active = {1}; int[] failures = {0};
        for (int i = 0; i < 150; i++) {
            runner.runOnMainSync(() -> {
                active[0] = EditorPreview.Companion.activeCount();
                failures[0] = EditorPreview.Companion.releaseFailureCount();
            });
            if (active[0] == 0) break;
            SystemClock.sleep(100);
        }
        if (failure == null && (active[0] != 0 || failures[0] != 0)) failure = "Native resources/releases did not drain";
        try {
            JSONObject report = new JSONObject().put("reloadsCompleted", timings.length()).put("loadToFrameAndSeekMs", timings)
                    .put("activeAfter", active[0]).put("releaseFailures", failures[0]).put("failure", failure == null ? JSONObject.NULL : failure)
                    .put("realSurfaceFrames", true).put("audioTracks", 8);
            report.put("overlappingLoadRejected", overlapRejected).put("disposedPendingLoadRejected", disposedLoadRejected);
            String name = "task08_preview_" + System.currentTimeMillis() + ".json";
            File path = new File(runner.getTargetContext().getFilesDir(), name);
            if (!path.createNewFile()) throw new AssertionError("Earlier evidence kept");
            try (FileOutputStream stream = new FileOutputStream(path)) {
                stream.write(report.toString().getBytes(StandardCharsets.UTF_8)); stream.getFD().sync();
            }
            result.putString("stream", "TASK08_PREVIEW_" + (failure == null ? "PASS" : "FAIL") + ":report=" + name + ";" + failure);
        } catch (Throwable error) { failure = error.toString(); result.putString("stream", "TASK08_PREVIEW_FAIL:" + failure); }
        runner.finish(failure == null ? Activity.RESULT_OK : Activity.RESULT_CANCELED, result);
    }
}
