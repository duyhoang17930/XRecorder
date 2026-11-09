package com.xrecorder.xrecorder.qa;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Context;
import android.content.ContextWrapper;
import android.os.Bundle;
import android.os.SystemClock;
import com.xrecorder.xrecorder.editor.TranscriptionBridge;
import io.flutter.plugin.common.StandardMessageCodec;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.json.JSONArray;
import org.json.JSONObject;

/** Real bridge/AtomicFile tests in separate directories; empty cue metadata only. */
public final class Task08HistoryMatrixInstrumentation {
    private static byte[] read(File file) throws Exception {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        try (FileInputStream in = new FileInputStream(file)) {
            byte[] buffer = new byte[8192]; int n;
            while ((n = in.read(buffer)) >= 0) out.write(buffer, 0, n);
        }
        return out.toByteArray();
    }

    private static void writeNew(File file, byte[] bytes) throws Exception {
        if (!file.createNewFile()) throw new AssertionError("Preserve existing fixture: " + file.getName());
        try (FileOutputStream out = new FileOutputStream(file)) {
            out.write(bytes); out.getFD().sync();
        }
    }

    private static Context context(Instrumentation runner, File root) {
        return new ContextWrapper(runner.getTargetContext()) {
            @Override public File getFilesDir() { return root; }
        };
    }

    private static JSONArray records(int count) throws Exception {
        JSONArray rows = new JSONArray();
        for (int i = 0; i < count; i++) {
            JSONObject job = new JSONObject().put("id", "fixture_" + i)
                .put("type", "speech").put("model", "tiny")
                .put("projectId", "task08_مرحبا_日本語_" + (i % 3))
                .put("sourceSignature", i == 0 ? JSONObject.NULL : "signature_" + (i % 3))
                .put("createdAt", 100000L + i / 2)
                .put("state", i == 1 ? "queued" : i == 2 ? "running" : "completed")
                .put("segments", new JSONArray());
            if (i != 0) job.put("contractVersion", 2)
                .put("language", new String[]{"vi", "en", "auto"}[i % 3])
                .put("modelLoadMs", 2).put("inferenceMs", 3);
            rows.put(job);
        }
        return rows;
    }

    @SuppressWarnings("unchecked")
    private static List<Map<String, Object>> listed(Instrumentation runner, TranscriptionBridge bridge) throws Exception {
        return listed(runner, bridge, null);
    }

    @SuppressWarnings("unchecked")
    private static List<Map<String, Object>> listed(Instrumentation runner, TranscriptionBridge bridge, Object query) throws Exception {
        Task08HistoryInstrumentation.Reply reply = Task08HistoryInstrumentation.call(runner, bridge, "transcriptionJobs", query);
        if (reply.code != null || !(reply.value instanceof List)) throw new AssertionError("History unavailable: " + reply.code);
        return (List<Map<String, Object>>) reply.value;
    }

    private static void verifyPages(Instrumentation runner, TranscriptionBridge bridge, int count) throws Exception {
        Set<String> ids = new HashSet<>();
        Map<String, Object> query = new HashMap<>();
        query.put("limit", 17);
        long previousTime = Long.MAX_VALUE;
        String previousId = null;
        while (true) {
            List<Map<String, Object>> page = listed(runner, bridge, query);
            if (page.size() > 17) throw new AssertionError("Unbounded history page");
            if (page.isEmpty()) break;
            for (Map<String, Object> row : page) {
                long time = ((Number) row.get("createdAt")).longValue();
                String id = (String) row.get("id");
                if (time > previousTime || time == previousTime && previousId != null && id.compareTo(previousId) >= 0)
                    throw new AssertionError("Unstable equal-timestamp cursor");
                if (!ids.add(id)) throw new AssertionError("Repeated paged identity");
                previousTime = time;
                previousId = id;
            }
            query.put("beforeCreatedAt", previousTime);
            query.put("beforeId", previousId);
            if (ids.size() > count) throw new AssertionError("Pagination didn't terminate");
        }
        if (ids.size() != count) throw new AssertionError("Pagination lost history");
        for (int i = 0; i < count; i++) if (!ids.contains("fixture_" + i)) throw new AssertionError("Missing paged identity");
        query.clear();
        query.put("projectId", "task08_مرحبا_日本語_0");
        query.put("sourceSignature", "different_revision");
        query.put("limit", 1);
        List<Map<String, Object>> legacy = listed(runner, bridge, query);
        if (legacy.size() != (count > 0 ? 1 : 0)
                || count > 0 && !"fixture_0".equals(legacy.get(0).get("id")))
            throw new AssertionError("Legacy null signature or changed-source filtering lost");
        for (int invalid : new int[]{0, 101}) {
            query.clear(); query.put("limit", invalid);
            if (Task08HistoryInstrumentation.call(runner, bridge, "transcriptionJobs", query).code == null)
                throw new AssertionError("Invalid page accepted");
        }
        query.clear(); query.put("beforeCreatedAt", 1);
        if (Task08HistoryInstrumentation.call(runner, bridge, "transcriptionJobs", query).code == null)
            throw new AssertionError("Incomplete cursor accepted");
        verify(listed(runner, bridge), count); // Paging must not mutate/prune the journal.
    }

    private static void verify(List<Map<String, Object>> jobs, int count) {
        if (jobs.size() != count) throw new AssertionError("Pruned history: " + count + "->" + jobs.size());
        Set<String> ids = new HashSet<>();
        for (Map<String, Object> job : jobs) {
            String id = (String) job.get("id");
            if (!ids.add(id)) throw new AssertionError("Duplicate snapshot ID");
            int index = Integer.parseInt(id.substring("fixture_".length()));
            String language = index == 0 ? "auto" : new String[]{"vi", "en", "auto"}[index % 3];
            if (!language.equals(job.get("language"))) throw new AssertionError("Legacy/language changed");
            if (!((List<?>) job.get("segments")).isEmpty()) throw new AssertionError("Fake transcript");
            if (!job.get("projectId").equals("task08_مرحبا_日本語_" + (index % 3))) throw new AssertionError("Unicode changed");
            if (((Number) job.get("createdAt")).longValue() != 100000L + index / 2) throw new AssertionError("Timestamp changed");
            if (((Number) job.get("modelLoadMs")).longValue() != (index == 0 ? 0 : 2)
                    || ((Number) job.get("inferenceMs")).longValue() != (index == 0 ? 0 : 3))
                throw new AssertionError("Timing migration changed");
            if (index == 1 || index == 2) {
                if (!"failed".equals(job.get("state")) || !"interrupted".equals(job.get("errorCode")))
                    throw new AssertionError("Interrupted operation shown as saved/running");
            }
        }
        for (int i = 0; i < count; i++) if (!ids.contains("fixture_" + i)) throw new AssertionError("Missing ID");
    }

    public static void run(Instrumentation runner, String reopenIndex) {
        Bundle output = new Bundle();
        try {
            File base = runner.getTargetContext().getFilesDir();
            JSONArray results = new JSONArray();
            String indexName;
            if (reopenIndex != null) {
                if (!reopenIndex.matches("task08_history_matrix_[0-9]+\\.json")) throw new AssertionError("Invalid fixture index");
                indexName = reopenIndex;
                JSONArray entries = new JSONArray(new String(read(new File(base, indexName)), StandardCharsets.UTF_8));
                for (int i = 0; i < entries.length(); i++) {
                    JSONObject entry = entries.getJSONObject(i);
                    String directory = entry.getString("directory");
                    if (!directory.matches("task08_history_[0-9]+_[0-9]+")) throw new AssertionError("Invalid fixture directory");
                    TranscriptionBridge bridge = new TranscriptionBridge(context(runner, new File(base, directory)));
                    try { verify(listed(runner, bridge), entry.getInt("count")); }
                    finally { bridge.dispose(); }
                }
                output.putString("stream", "TASK08_HISTORY_PROCESS_REOPEN_PASS:6counts;metadata/IDs/interruption exact;index=" + indexName);
            } else {
                long stamp = System.currentTimeMillis();
                for (int count : new int[]{0, 20, 21, 77, 100, 1001}) {
                    File root = new File(base, "task08_history_" + stamp + "_" + count);
                    if (!root.mkdir()) throw new AssertionError("New directory required");
                    byte[] source = records(count).toString().getBytes(StandardCharsets.UTF_8);
                    writeNew(new File(root, "transcription_jobs.json"), source);
                    writeNew(new File(root, "source.json"), source);
                    TranscriptionBridge bridge = new TranscriptionBridge(context(runner, root));
                    long start = SystemClock.elapsedRealtimeNanos();
                    try {
                        List<Map<String, Object>> full = listed(runner, bridge);
                        verify(full, count);
                        long restoreMs = (SystemClock.elapsedRealtimeNanos() - start) / 1000000;
                        start = SystemClock.elapsedRealtimeNanos();
                        verifyPages(runner, bridge, count);
                        long pagesMs = (SystemClock.elapsedRealtimeNanos() - start) / 1000000;
                        Map<String, Object> latestQuery = new HashMap<>();
                        latestQuery.put("projectId", "task08_مرحبا_日本語_0");
                        latestQuery.put("sourceSignature", "signature_0");
                        latestQuery.put("limit", 1);
                        List<Map<String, Object>> latest = listed(runner, bridge, latestQuery);
                        int fullBytes = StandardMessageCodec.INSTANCE.encodeMessage(full).position();
                        int latestBytes = StandardMessageCodec.INSTANCE.encodeMessage(latest).position();
                        start = SystemClock.elapsedRealtimeNanos();
                        if (count > 0) {
                            Task08HistoryInstrumentation.Reply saved = Task08HistoryInstrumentation.call(runner, bridge,
                                    "transcriptionSaveHistory", "fixture_0");
                            if (saved.code != null) throw new AssertionError("Checkpoint failed: " + saved.code);
                        }
                        verify(listed(runner, bridge), count);
                        results.put(new JSONObject().put("count", count).put("directory", root.getName())
                                .put("restoreAndListMs", restoreMs)
                                .put("allPagesAndFiltersMs", pagesMs)
                                .put("unfilteredChannelBytes", fullBytes)
                                .put("latestMatchingChannelBytes", latestBytes)
                                .put("checkpointAndVerifyMs", (SystemClock.elapsedRealtimeNanos() - start) / 1000000));
                    } finally { bridge.dispose(); }
                }
                for (String fault : new String[]{"future", "corrupt", "utf8", "write_obstruction"}) {
                    File root = new File(base, "task08_fault_" + stamp + "_" + fault);
                    if (!root.mkdir()) throw new AssertionError("New fault fixture required");
                    byte[] source = fault.equals("future")
                            ? "[{\"contractVersion\":3}]".getBytes(StandardCharsets.UTF_8)
                            : fault.equals("corrupt") ? "[{".getBytes(StandardCharsets.UTF_8)
                            : fault.equals("utf8") ? new byte[]{(byte) 0xc3, 0x28}
                            : records(20).toString().getBytes(StandardCharsets.UTF_8);
                    File journal = new File(root, "transcription_jobs.json");
                    writeNew(journal, source);
                    writeNew(new File(root, "source.bin"), source);
                    TranscriptionBridge bridge = new TranscriptionBridge(context(runner, root));
                    try {
                        if (fault.equals("write_obstruction")) {
                            verify(listed(runner, bridge), 20);
                            // openRead removes stale .new entries during recovery.
                            // Obstruct the next write only after restore has completed.
                            if (!new File(root, "transcription_jobs.json.new").mkdir())
                                throw new AssertionError("Write obstruction fixture unavailable");
                            if (!"history_write_failed".equals(Task08HistoryInstrumentation.call(runner, bridge,
                                    "transcriptionSaveHistory", "fixture_0").code))
                                throw new AssertionError("Write failure falsely saved");
                        } else {
                            if (!"history_unavailable".equals(Task08HistoryInstrumentation.call(runner, bridge,
                                    "transcriptionJobs", null).code)) throw new AssertionError("Unsafe read accepted");
                            if (!"history_unavailable".equals(Task08HistoryInstrumentation.call(runner, bridge,
                                    "transcriptionStart", null).code)) throw new AssertionError("Unsafe write accepted");
                        }
                        if (!Arrays.equals(source, read(journal))) throw new AssertionError("Original fault journal altered");
                    } finally { bridge.dispose(); }
                }
                indexName = "task08_history_matrix_" + stamp + ".json";
                writeNew(new File(base, indexName), results.toString().getBytes(StandardCharsets.UTF_8));
                output.putString("stream", "TASK08_HISTORY_MATRIX_PASS:0/20/21/77/100/1001;bounded pages/stable cursors;checkpoint;legacy;Unicode;future/corrupt/utf8 readonly;write obstruction;index=" + indexName);
            }
            runner.finish(Activity.RESULT_OK, output);
        } catch (Throwable error) {
            output.putString("stream", "TASK08_HISTORY_MATRIX_FAIL:" + error);
            runner.finish(Activity.RESULT_CANCELED, output);
        }
    }
}
