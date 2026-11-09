package com.xrecorder.xrecorder.qa;

import android.app.Activity;
import android.app.Instrumentation;
import android.os.Bundle;
import com.xrecorder.xrecorder.editor.EditorBridge;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import org.json.JSONArray;
import org.json.JSONObject;

/** Re-export only explicitly selected, backed-up TASK08 fixture drafts. */
public final class Task08MediaRegressionInstrumentation {
    static byte[] read(File path) throws Exception {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        try (FileInputStream in = new FileInputStream(path)) {
            byte[] buffer = new byte[8192]; int n;
            while ((n = in.read(buffer)) >= 0) out.write(buffer, 0, n);
        }
        return out.toByteArray();
    }

    static Object nativeValue(Object value) throws Exception {
        if (value instanceof JSONObject) {
            JSONObject object = (JSONObject) value;
            Map<String, Object> result = new HashMap<>();
            for (Iterator<String> keys = object.keys(); keys.hasNext();) {
                String key = keys.next(); result.put(key, nativeValue(object.get(key)));
            }
            return result;
        }
        if (value instanceof JSONArray) {
            List<Object> result = new ArrayList<>();
            JSONArray array = (JSONArray) value;
            for (int i = 0; i < array.length(); i++) result.add(nativeValue(array.get(i)));
            return result;
        }
        return value == JSONObject.NULL ? null : value;
    }

    public static void run(Instrumentation runner, String manifestName) {
        Bundle output = new Bundle();
        EditorBridge bridge = new EditorBridge(runner.getTargetContext());
        try {
            if (manifestName == null || !manifestName.matches("task08_media_input_[0-9]+\\.json"))
                throw new AssertionError("Explicit fixture manifest required");
            File base = runner.getTargetContext().getFilesDir();
            JSONObject input = new JSONObject(new String(read(new File(base, manifestName)), StandardCharsets.UTF_8));
            JSONObject outputs = new JSONObject();
            for (Iterator<String> names = input.keys(); names.hasNext();) {
                String name = names.next();
                String id = input.getString(name);
                if (!name.matches("[a-zA-Z0-9]+") || !id.matches("audio_[0-9]+_" + name))
                    throw new AssertionError("Only TASK08 audio fixture drafts may run");
                File draft = new File(base, "projects/" + id + ".json");
                byte[] before = read(draft);
                JSONObject project = new JSONObject(new String(before, StandardCharsets.UTF_8));
                CountDownLatch done = new CountDownLatch(1);
                Object[] result = new Object[2];
                MethodChannel.Result reply = new MethodChannel.Result() {
                    public void success(Object value) { result[0] = value; done.countDown(); }
                    public void error(String code, String message, Object details) { result[1] = code + ":" + message; done.countDown(); }
                    public void notImplemented() { result[1] = "notImplemented"; done.countDown(); }
                };
                Object arguments = nativeValue(project);
                runner.runOnMainSync(() -> bridge.onMethodCall(new MethodCall("engineProbe", arguments), reply));
                if (!done.await(180, TimeUnit.SECONDS)) throw new AssertionError("Export timeout: " + name);
                if (result[1] != null || !(result[0] instanceof String)) throw new AssertionError(name + ":" + result[1]);
                if (!Arrays.equals(before, read(draft))) throw new AssertionError("Draft changed: " + name);
                outputs.put(name, result[0]);
                Bundle progress = new Bundle();
                progress.putString("stream", "TASK08_EXPORT:" + name + "=" + result[0] + "\n");
                runner.sendStatus(0, progress);
            }
            JSONObject report = new JSONObject().put("outputs", outputs).put("fixturesRetained", true)
                    .put("sourceDraftBytesExact", true).put("kind", "native_engine_probe_reexport");
            String reportName = "task08_media_output_" + System.currentTimeMillis() + ".json";
            File path = new File(base, reportName);
            if (!path.createNewFile()) throw new AssertionError("Existing evidence kept");
            try (FileOutputStream stream = new FileOutputStream(path)) {
                stream.write(report.toString().getBytes(StandardCharsets.UTF_8)); stream.getFD().sync();
            }
            runner.runOnMainSync(bridge::dispose);
            output.putString("stream", "TASK08_MEDIA_REGRESSION_PASS:outputs=" + outputs.length() + ";report=" + reportName);
            runner.finish(Activity.RESULT_OK, output);
        } catch (Throwable error) {
            runner.runOnMainSync(bridge::dispose);
            output.putString("stream", "TASK08_MEDIA_REGRESSION_FAIL:" + error);
            runner.finish(Activity.RESULT_CANCELED, output);
        }
    }
}
