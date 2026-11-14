package com.xrecorder.xrecorder.qa;

import android.app.Activity;
import android.app.Instrumentation;
import android.app.UiAutomation;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.Rect;
import android.os.Bundle;
import android.os.SystemClock;
import android.view.accessibility.AccessibilityNodeInfo;
import android.accessibilityservice.AccessibilityServiceInfo;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.json.JSONArray;
import org.json.JSONObject;

/** Real framework focus checks without suppressing the installed screen reader. */
public final class Task07AccessibilityInstrumentation extends Instrumentation {
    private Bundle ui05bPlayerArguments;
    private Bundle task10RecordingArguments;
    private Bundle task10RegionArguments;
    private Bundle task10LiveArguments;
    private static final String PACKAGE = "com.xrecorder.xrecorder";
    private boolean task08History;
    private boolean task08Corpus;
    private boolean task08HistoryMatrix;
    private String task08HistoryReopen;
    private boolean task08Trash;
    private String task08MediaInput;
    private boolean task08Media;
    private boolean task08Speech;
    private String task08SpeechUri;
    private int task08SpeechCycles;
    private boolean task08Navigation;
    private String task08SpeechProject;
    private boolean task08SpeechForeground;
    private boolean task08Preview;
    private int task08PreviewCycles;
    private boolean task09SourceRecovery;
    private String task09SourceUri;
    private boolean task09bExportHistory;
    private String task09bExportProcess;
    private String task09bExportRoot;

    @Override public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        if (arguments != null && arguments.getString("task10", "").startsWith("live-"))
            task10LiveArguments = new Bundle(arguments);
        if (arguments != null && arguments.getString("task10", "").startsWith("recording-"))
            task10RecordingArguments = new Bundle(arguments);
        if (arguments != null && arguments.getString("task10", "").startsWith("region-"))
            task10RegionArguments = new Bundle(arguments);
        if (arguments != null && "player".equals(arguments.getString("ui05b")))
            ui05bPlayerArguments = new Bundle(arguments);
        task08History = arguments != null && "history".equals(arguments.getString("task08"));
        task08Corpus = arguments != null && "corpus".equals(arguments.getString("task08"));
        task08HistoryMatrix = arguments != null && "history-matrix".equals(arguments.getString("task08"));
        task08HistoryReopen = arguments == null ? null : arguments.getString("historyReopen");
        task08Trash = arguments != null && "trash".equals(arguments.getString("task08"));
        task08Media = arguments != null && "media".equals(arguments.getString("task08"));
        task08MediaInput = arguments == null ? null : arguments.getString("mediaInput");
        task08Speech = arguments != null && "speech".equals(arguments.getString("task08"));
        task08SpeechUri = arguments == null ? null : arguments.getString("speechUri");
        task08SpeechCycles = arguments == null ? 1 : Integer.parseInt(arguments.getString("speechCycles", "1"));
        task08Navigation = arguments != null && "navigation".equals(arguments.getString("task08"));
        task08SpeechProject = arguments == null ? null : arguments.getString("speechProject");
        task08SpeechForeground = arguments != null && "true".equals(arguments.getString("speechForeground"));
        task08Preview = arguments != null && "preview".equals(arguments.getString("task08"));
        task08PreviewCycles = arguments == null ? 30 : Integer.parseInt(arguments.getString("previewCycles", "30"));
        task09SourceRecovery = arguments != null && "source-recovery".equals(arguments.getString("task09"));
        task09SourceUri = arguments == null ? null : arguments.getString("sourceUri");
        task09bExportHistory = arguments != null && "export-history".equals(arguments.getString("task09b"));
        task09bExportProcess = arguments == null ? null : arguments.getString("task09b");
        task09bExportRoot = arguments == null ? null : arguments.getString("exportRoot");
        start();
    }

    private static String label(AccessibilityNodeInfo node) {
        CharSequence value = node.getContentDescription();
        if (value == null || value.length() == 0) value = node.getText();
        return value == null ? "" : value.toString();
    }

    private static void collect(AccessibilityNodeInfo node, int bottomBand,
                                Map<String, AccessibilityNodeInfo> targets, java.util.Set<String> allowed) {
        Rect bounds = new Rect();
        node.getBoundsInScreen(bounds);
        String text = label(node);
        if (PACKAGE.contentEquals(node.getPackageName() == null ? "" : node.getPackageName())
                && node.isVisibleToUser() && node.isClickable()
                && bounds.top >= bottomBand && !text.isEmpty()
                && (allowed == null || allowed.contains(text))) {
            targets.putIfAbsent(text, node);
        }
        for (int i = 0; i < node.getChildCount(); i++) {
            AccessibilityNodeInfo child = node.getChild(i);
            if (child != null) collect(child, bottomBand, targets, allowed);
        }
    }

    @Override public void onStart() {
        if (task10LiveArguments != null) {
            Task10LiveInstrumentation.run(this, task10LiveArguments);
            return;
        }
        if (task10RegionArguments != null) {
            Task10RegionInstrumentation.run(this, task10RegionArguments);
            return;
        }
        if (task10RecordingArguments != null) {
            Task10RecordingInstrumentation.run(this, task10RecordingArguments);
            return;
        }
        if (ui05bPlayerArguments != null) {
            Ui05BPlayerInstrumentation.run(this, ui05bPlayerArguments);
            return;
        }
        if ("backup-owned-media".equals(task09bExportProcess)) {
            Task09BExportProcessInstrumentation.backupOwnedMedia(this, task09SourceUri);
            return;
        }
        if ("export-process-start".equals(task09bExportProcess) || "export-process-recover".equals(task09bExportProcess)) {
            Task09BExportProcessInstrumentation.run(this, task09bExportProcess, task09bExportRoot);
            return;
        }
        if (task09bExportHistory) {
            Task09BExportHistoryInstrumentation.run(this);
            return;
        }
        if (task09SourceRecovery) {
            Task09PreviewRecoveryInstrumentation.run(this, task09SourceUri);
            return;
        }
        if (task08Preview) {
            Task08PreviewInstrumentation.run(this, task08MediaInput, task08PreviewCycles);
            return;
        }
        if (task08Speech) {
            Task08SpeechInstrumentation.run(this, task08SpeechUri, task08SpeechCycles,
                    task08SpeechProject, task08SpeechForeground);
            return;
        }
        if (task08Media) {
            Task08MediaRegressionInstrumentation.run(this, task08MediaInput);
            return;
        }
        if (task08Trash) {
            Task08TrashInstrumentation.run(this);
            return;
        }
        if (task08HistoryMatrix) {
            Task08HistoryMatrixInstrumentation.run(this, task08HistoryReopen);
            return;
        }
        if (task08Corpus) {
            Task08CorpusInstrumentation.run(this);
            return;
        }
        if (task08History) {
            Task08HistoryInstrumentation.run(this);
            return;
        }
        Bundle result = new Bundle();
        try {
            // Public API24+: default UiAutomation would suppress TalkBack.
            UiAutomation automation = getUiAutomation(
                    UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES);
            AccessibilityServiceInfo info = automation.getServiceInfo();
            info.flags |= AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS;
            automation.setServiceInfo(info);
            startActivitySync(new Intent().setClassName(PACKAGE, PACKAGE + ".MainActivity")
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            Map<String, AccessibilityNodeInfo> targets = new LinkedHashMap<>();
            // TASK08 English fixture: don't mistake a bottom media card for a
            // navigation destination, or omit Settings after finding four nodes.
            java.util.Set<String> allowed = task08Navigation ? new java.util.HashSet<>(
                    java.util.Arrays.asList("Video", "Photo", "Create", "Edit", "Settings")) : null;
            int required = task08Navigation ? 5 : 4;
            for (int retry = 0; retry < 150 && targets.size() < required; retry++) {
                targets.clear();
                AccessibilityNodeInfo root = automation.getRootInActiveWindow();
                if (root != null) {
                    Rect screen = new Rect();
                    root.getBoundsInScreen(screen);
                    collect(root, screen.top + screen.height() * 85 / 100, targets, allowed);
                }
                if (targets.size() < required) SystemClock.sleep(100);
            }
            if (targets.size() < required) throw new AssertionError("Required labeled navigation targets missing");
            File folder = new File(getTargetContext().getFilesDir(),
                    "task07_native_a11y_" + System.currentTimeMillis());
            if (!folder.mkdir()) throw new AssertionError("Unique QA evidence directory required");
            JSONArray samples = new JSONArray();
            List<Map.Entry<String, AccessibilityNodeInfo>> entries = new ArrayList<>(targets.entrySet());
            for (int i = 0; i < required; i++) {
                Map.Entry<String, AccessibilityNodeInfo> entry = entries.get(i);
                if (!entry.getValue().performAction(AccessibilityNodeInfo.ACTION_ACCESSIBILITY_FOCUS)) {
                    throw new AssertionError("Native accessibility-focus action rejected");
                }
                String focused = "";
                for (int retry = 0; retry < 20; retry++) {
                    AccessibilityNodeInfo node = automation.findFocus(AccessibilityNodeInfo.FOCUS_ACCESSIBILITY);
                    focused = node == null ? "" : label(node);
                    if (entry.getKey().equals(focused)) break;
                    SystemClock.sleep(100);
                }
                if (!entry.getKey().equals(focused)) throw new AssertionError("Requested and actual focus differ");
                Bitmap shot = automation.takeScreenshot();
                if (shot == null) throw new AssertionError("Actual screenshot unavailable");
                File png = new File(folder, "focus_" + i + ".png");
                try (FileOutputStream stream = new FileOutputStream(png)) {
                    if (!shot.compress(Bitmap.CompressFormat.PNG, 100, stream)) {
                        throw new AssertionError("Screenshot write failed");
                    }
                } finally { shot.recycle(); }
                samples.put(new JSONObject().put("requested", entry.getKey()).put("actual", focused));
            }
            JSONObject report = new JSONObject().put("passed", true)
                    .put("navigationOnly", task08Navigation)
                    .put("dontSuppressAccessibilityServices", true)
                    .put("focusSamples", samples).put("evidenceDirectory", folder.getAbsolutePath())
                    .put("humanListening", false).put("humanUsability", false);
            try (FileOutputStream stream = new FileOutputStream(new File(folder, "result.json"))) {
                stream.write(report.toString(2).getBytes(StandardCharsets.UTF_8));
            }
            result.putString("stream", "TASK07_NATIVE_ACCESSIBILITY=" + report);
            finish(Activity.RESULT_OK, result);
        } catch (Throwable error) {
            result.putString("stream", "TASK07_NATIVE_ACCESSIBILITY_FAILED=" + error);
            finish(Activity.RESULT_CANCELED, result);
        }
    }
}
