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
    private static final String PACKAGE = "com.xrecorder.xrecorder";
    private boolean task08History;
    private boolean task08Corpus;
    private boolean task08HistoryMatrix;
    private String task08HistoryReopen;
    private boolean task08Trash;

    @Override public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        task08History = arguments != null && "history".equals(arguments.getString("task08"));
        task08Corpus = arguments != null && "corpus".equals(arguments.getString("task08"));
        task08HistoryMatrix = arguments != null && "history-matrix".equals(arguments.getString("task08"));
        task08HistoryReopen = arguments == null ? null : arguments.getString("historyReopen");
        task08Trash = arguments != null && "trash".equals(arguments.getString("task08"));
        start();
    }

    private static String label(AccessibilityNodeInfo node) {
        CharSequence value = node.getContentDescription();
        if (value == null || value.length() == 0) value = node.getText();
        return value == null ? "" : value.toString();
    }

    private static void collect(AccessibilityNodeInfo node, int bottomBand,
                                Map<String, AccessibilityNodeInfo> targets) {
        Rect bounds = new Rect();
        node.getBoundsInScreen(bounds);
        String text = label(node);
        if (PACKAGE.contentEquals(node.getPackageName() == null ? "" : node.getPackageName())
                && node.isVisibleToUser() && node.isClickable()
                && bounds.top >= bottomBand && !text.isEmpty()) {
            targets.putIfAbsent(text, node);
        }
        for (int i = 0; i < node.getChildCount(); i++) {
            AccessibilityNodeInfo child = node.getChild(i);
            if (child != null) collect(child, bottomBand, targets);
        }
    }

    @Override public void onStart() {
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
            for (int retry = 0; retry < 150 && targets.size() < 4; retry++) {
                targets.clear();
                AccessibilityNodeInfo root = automation.getRootInActiveWindow();
                if (root != null) {
                    Rect screen = new Rect();
                    root.getBoundsInScreen(screen);
                    collect(root, screen.top + screen.height() * 85 / 100, targets);
                }
                if (targets.size() < 4) SystemClock.sleep(100);
            }
            if (targets.size() < 4) throw new AssertionError("Four labeled navigation targets required");
            File folder = new File(getTargetContext().getFilesDir(),
                    "task07_native_a11y_" + System.currentTimeMillis());
            if (!folder.mkdir()) throw new AssertionError("Unique QA evidence directory required");
            JSONArray samples = new JSONArray();
            List<Map.Entry<String, AccessibilityNodeInfo>> entries = new ArrayList<>(targets.entrySet());
            for (int i = 0; i < 4; i++) {
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
