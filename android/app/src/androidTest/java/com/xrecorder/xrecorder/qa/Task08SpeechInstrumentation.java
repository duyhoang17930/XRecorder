package com.xrecorder.xrecorder.qa;

import android.app.Activity;
import android.app.ActivityManager;
import android.app.Instrumentation;
import android.app.UiAutomation;
import android.content.Context;
import android.content.ContextWrapper;
import android.content.Intent;
import android.os.Bundle;
import android.os.Debug;
import android.os.SystemClock;
import android.system.Os;
import android.system.OsConstants;
import com.xrecorder.xrecorder.editor.TranscriptionBridge;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.json.JSONArray;
import org.json.JSONObject;

/** Actual JNI cycles or explicit pre-JNI low-memory rejection, isolated history. */
public final class Task08SpeechInstrumentation {
    private static boolean hasRenderedBrand(android.view.accessibility.AccessibilityNodeInfo node) {
        CharSequence value = node.getContentDescription();
        if (value == null) value = node.getText();
        if (value != null && value.toString().contains("3HRECORDER")) return true;
        for (int i = 0; i < node.getChildCount(); i++) {
            android.view.accessibility.AccessibilityNodeInfo child = node.getChild(i);
            if (child != null && hasRenderedBrand(child)) return true;
        }
        return false;
    }

    @SuppressWarnings("unchecked")
    public static void run(Instrumentation runner, String uri, int repetitions, String projectId, boolean foreground) {
        Bundle output = new Bundle();
        TranscriptionBridge bridge = null;
        try {
            if (uri == null || !uri.matches("content://com\\.xrecorder\\.xrecorder\\.files/trash/(p2_p3_jfk|task08_smoke_jfk_[0-9]+)\\.wav")
                    || repetitions < 1 || repetitions > 10) throw new AssertionError("Explicit QA speech fixture required");
            if (foreground) {
                runner.startActivitySync(new Intent().setClassName("com.xrecorder.xrecorder",
                        "com.xrecorder.xrecorder.MainActivity").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
                // Become a real foreground Activity before binding UiAutomation;
                // cold-boot LMK can kill a cached instrumentation process first.
                UiAutomation automation = runner.getUiAutomation(UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES);
                boolean rendered = false;
                for (int i = 0; i < 100; i++) {
                    android.view.accessibility.AccessibilityNodeInfo node = automation.getRootInActiveWindow();
                    if (node != null && hasRenderedBrand(node)) {
                        rendered = true; break;
                    }
                    SystemClock.sleep(100);
                }
                if (!rendered) throw new AssertionError("Actual foreground Flutter content not ready");
                SystemClock.sleep(1000); // Allow the first library thumbnails to finish.
            }
            File root = new File(runner.getTargetContext().getFilesDir(), "task08_speech_" + System.currentTimeMillis());
            if (!root.mkdir()) throw new AssertionError("New fixture directory required");
            bridge = new TranscriptionBridge(new ContextWrapper(runner.getTargetContext()) {
                @Override public File getFilesDir() { return root; }
            });
            File draft = null;
            byte[] draftBefore = null;
            Object project = null;
            if (projectId != null) {
                if (!projectId.matches("speech_composition_[0-9]+")) throw new AssertionError("Only the edited-speech QA fixture may run");
                draft = new File(runner.getTargetContext().getFilesDir(), "projects/" + projectId + ".json");
                draftBefore = Task08MediaRegressionInstrumentation.read(draft);
                project = Task08MediaRegressionInstrumentation.nativeValue(
                        new JSONObject(new String(draftBefore, StandardCharsets.UTF_8)));
            }
            JSONArray rows = new JSONArray();
            for (int i = 0; i < repetitions; i++) {
                Map<String, Object> request = new HashMap<>();
                request.put("model", "tiny"); request.put("language", "en");
                request.put("durationMs", 11000); request.put("audioUri", uri);
                request.put("operationId", "task08_cycle_" + i + "_" + System.currentTimeMillis());
                if (project != null) request.put("project", project);
                Task08HistoryInstrumentation.Reply start = Task08HistoryInstrumentation.call(runner, bridge, "transcriptionStart", request);
                if (start.code != null) throw new AssertionError("Start failed: " + start.code);
                Map<String, Object> job = null;
                for (int n = 0; n < 600; n++) {
                    Task08HistoryInstrumentation.Reply poll = Task08HistoryInstrumentation.call(runner, bridge, "transcriptionPoll", start.value);
                    if (poll.code != null) throw new AssertionError("Poll failed: " + poll.code);
                    job = (Map<String, Object>) poll.value;
                    if (!"queued".equals(job.get("state")) && !"running".equals(job.get("state"))) break;
                    SystemClock.sleep(200);
                }
                if (job == null) throw new AssertionError("No native result");
                if ("completed".equals(job.get("state"))) {
                    if (((Number) job.get("inferenceMs")).longValue() <= 0
                            || ((List<?>) job.get("segments")).isEmpty()
                            || !job.get("segments").toString().toLowerCase(java.util.Locale.ROOT).contains("country"))
                        throw new AssertionError("Actual speech was not recognized");
                } else if (!"failed".equals(job.get("state")) || !"low_memory".equals(job.get("errorCode"))
                        || ((Number) job.get("modelLoadMs")).longValue() != 0
                        || ((Number) job.get("inferenceMs")).longValue() != 0
                        || job.get("memoryPreflight") == null) {
                    throw new AssertionError("Neither genuine completion nor safe pre-JNI rejection: " + job.get("errorCode"));
                }
                SystemClock.sleep(100);
                Debug.MemoryInfo memory = new Debug.MemoryInfo(); Debug.getMemoryInfo(memory);
                rows.put(new JSONObject(job).put("sampledPssKiB", memory.getTotalPss())
                        .put("nativeHeapAllocatedBytes", Debug.getNativeHeapAllocatedSize()));
            }
            ActivityManager.MemoryInfo system = new ActivityManager.MemoryInfo();
            runner.getTargetContext().getSystemService(ActivityManager.class).getMemoryInfo(system);
            JSONObject report = new JSONObject().put("jobs", rows).put("pageSize", Os.sysconf(OsConstants._SC_PAGESIZE))
                    .put("foregroundFlutterContentVerified", foreground)
                    .put("totalRamBytes", system.totalMem).put("availableRamBytes", system.availMem)
                    .put("sourcePreserved", true).put("historyDirectory", root.getName());
            if (draft != null) {
                if (!java.util.Arrays.equals(draftBefore, Task08MediaRegressionInstrumentation.read(draft)))
                    throw new AssertionError("Edited speech draft changed");
                report.put("editedComposition", true).put("sourceDraftBytesExact", true);
            }
            File path = new File(root, "result.json");
            if (!path.createNewFile()) throw new AssertionError("Earlier evidence kept");
            try (FileOutputStream stream = new FileOutputStream(path)) {
                stream.write(report.toString().getBytes(StandardCharsets.UTF_8)); stream.getFD().sync();
            }
            bridge.dispose(); bridge = null;
            output.putString("stream", "TASK08_SPEECH_PASS:cycles=" + rows.length() + ";report=" + root.getName() + "/result.json");
            runner.finish(Activity.RESULT_OK, output);
        } catch (Throwable error) {
            if (bridge != null) bridge.dispose();
            output.putString("stream", "TASK08_SPEECH_FAIL:" + error);
            runner.finish(Activity.RESULT_CANCELED, output);
        }
    }
}
