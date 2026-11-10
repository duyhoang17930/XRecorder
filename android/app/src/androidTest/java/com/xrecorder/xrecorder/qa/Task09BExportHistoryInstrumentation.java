package com.xrecorder.xrecorder.qa;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.ContextWrapper;
import android.content.ContentValues;
import android.content.ContentUris;
import android.net.Uri;
import android.provider.MediaStore;
import android.os.Bundle;
import android.os.SystemClock;
import com.xrecorder.xrecorder.editor.ExportQueue;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;
import org.json.JSONArray;
import org.json.JSONObject;

/** History and interrupted publication faults in fresh contexts, never live jobs. */
public final class Task09BExportHistoryInstrumentation {
    private static void writeNew(File path, byte[] data) throws Exception {
        if (!path.createNewFile()) throw new AssertionError("Existing fixture must be retained");
        try (FileOutputStream output = new FileOutputStream(path)) {
            output.write(data);
            output.getFD().sync();
        }
    }

    private static void verify(ExportQueue queue, int count) throws Exception {
        JSONArray rows = new JSONArray(queue.list());
        if (rows.length() != count) throw new AssertionError("Pruned export history");
        Set<String> ids = new HashSet<>();
        for (int i = 0; i < rows.length(); i++) {
            JSONObject row = rows.getJSONObject(i);
            if (!ids.add(row.getString("id"))) throw new AssertionError("Duplicate identity");
            if (!"cancelled".equals(row.getString("state")) || row.has("uri"))
                throw new AssertionError("Simulation became a false saved export");
            if (!row.getJSONObject("project").getString("title").equals("QA cancelled " + i))
                throw new AssertionError("Project metadata changed");
        }
        for (int i = 0; i < count; i++) {
            if (!ids.contains("task09b_export_" + i)) throw new AssertionError("Lost identity");
        }
    }

    private static JSONObject recover(Instrumentation runner, File group, String name, String uri) throws Exception {
        File root = new File(group, name);
        if (!root.mkdir()) throw new AssertionError("Fresh recovery fixture required");
        File cache = new File(root, "cache");
        if (!cache.mkdir()) throw new AssertionError("Fresh fixture cache required");
        JSONObject row = new JSONObject().put("id", "task09b_recovery_" + UUID.randomUUID())
                .put("state", "finalizing").put("progress", 99).put("pending", uri)
                .put("project", new JSONObject().put("clips", new JSONArray()));
        byte[] source = new JSONArray().put(row).toString().getBytes(StandardCharsets.UTF_8);
        writeNew(new File(root, "source.json"), source);
        writeNew(new File(root, "export_jobs.json"), source);
        ContextWrapper isolated = new ContextWrapper(runner.getTargetContext()) {
            @Override public File getFilesDir() { return root; }
            @Override public File getCacheDir() { return cache; }
        };
        ExportQueue queue = new ExportQueue(isolated);
        try {
            JSONObject actual = new JSONArray(queue.list()).getJSONObject(0);
            writeNew(new File(root, "actual.json"), actual.toString().getBytes(StandardCharsets.UTF_8));
            return actual;
        } finally { queue.close(); }
    }

    public static void run(Instrumentation runner) {
        Bundle result = new Bundle();
        JSONArray cases = new JSONArray();
        try {
            File group = new File(runner.getTargetContext().getFilesDir(),
                    "task09b_export_history_" + UUID.randomUUID());
            if (!group.mkdir()) throw new AssertionError("Fresh fixture directory required");
            for (int count : new int[]{0, 20, 21, 77, 100, 1001}) {
                File root = new File(group, "count_" + count);
                if (!root.mkdir()) throw new AssertionError("Fresh isolated context required");
                JSONArray rows = new JSONArray();
                for (int i = 0; i < count; i++) {
                    rows.put(new JSONObject().put("id", "task09b_export_" + i)
                            .put("state", "cancelled").put("progress", 0)
                            .put("project", new JSONObject().put("id", "qa_project_" + i)
                                    .put("title", "QA cancelled " + i).put("clips", new JSONArray())));
                }
                byte[] source = rows.toString().getBytes(StandardCharsets.UTF_8);
                writeNew(new File(root, "source.json"), source);
                writeNew(new File(root, "export_jobs.json"), source);
                ContextWrapper context = new ContextWrapper(runner.getTargetContext()) {
                    @Override public File getFilesDir() { return root; }
                };
                long start = SystemClock.elapsedRealtime();
                ExportQueue first = new ExportQueue(context);
                try { verify(first, count); }
                finally { first.close(); }
                ExportQueue reopened = new ExportQueue(context);
                try { verify(reopened, count); }
                finally { reopened.close(); }
                cases.put(new JSONObject().put("count", count)
                        .put("restoreListAndReopenMs", SystemClock.elapsedRealtime() - start)
                        .put("journalBytes", source.length).put("status", "PASS"));
            }
            JSONObject invalidUri = recover(runner, group, "invalid_uri",
                    "content://media/external/video/media/not_a_number");
            if (!"failed".equals(invalidUri.getString("state")) || invalidUri.has("uri"))
                throw new AssertionError("Invalid output URI was not safely rejected");
            cases.put(new JSONObject().put("case", "invalid_output_uri").put("status", "PASS"));
            // Fault input: a published owner row whose file is empty must not
            // turn an interrupted export into Saved. Keep the synthetic row
            // and its source journal; never alter the live export journal.
            File invalid = new File(group, "invalid_publication");
            if (!invalid.mkdir()) throw new AssertionError("Fresh fault context required");
            File cache = new File(invalid, "cache");
            if (!cache.mkdir()) throw new AssertionError("Fresh fault cache required");
            ContentValues values = new ContentValues();
            values.put(MediaStore.MediaColumns.DISPLAY_NAME, "TASK09B_EMPTY_EXPECT_ERROR_" + UUID.randomUUID() + ".mp4");
            values.put(MediaStore.MediaColumns.MIME_TYPE, "video/mp4");
            values.put(MediaStore.MediaColumns.RELATIVE_PATH, "Movies/XRecorder/");
            values.put(MediaStore.MediaColumns.IS_PENDING, 1);
            Uri publication = runner.getTargetContext().getContentResolver().insert(
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values);
            if (publication == null) throw new AssertionError("Fault row unavailable");
            try (java.io.OutputStream stream = runner.getTargetContext().getContentResolver().openOutputStream(publication)) {
                if (stream == null) throw new AssertionError("Fault file unavailable");
            }
            ContentValues publish = new ContentValues();
            publish.put(MediaStore.MediaColumns.IS_PENDING, 0);
            if (runner.getTargetContext().getContentResolver().update(publication, publish, null, null) != 1)
                throw new AssertionError("Could not publish controlled empty fixture");
            JSONObject job = new JSONObject().put("id", "task09b_empty_" + UUID.randomUUID())
                    .put("state", "finalizing").put("progress", 99).put("pending", publication.toString())
                    .put("project", new JSONObject().put("clips", new JSONArray()));
            byte[] faulty = new JSONArray().put(job).toString().getBytes(StandardCharsets.UTF_8);
            writeNew(new File(invalid, "source.json"), faulty);
            writeNew(new File(invalid, "export_jobs.json"), faulty);
            ContextWrapper isolated = new ContextWrapper(runner.getTargetContext()) {
                @Override public File getFilesDir() { return invalid; }
                @Override public File getCacheDir() { return cache; }
            };
            ExportQueue recovery = new ExportQueue(isolated);
            try {
                JSONObject actual = new JSONArray(recovery.list()).getJSONObject(0);
                writeNew(new File(invalid, "actual.json"), actual.toString().getBytes(StandardCharsets.UTF_8));
                if (!"failed".equals(actual.getString("state")) || actual.has("uri"))
                    throw new AssertionError("Empty publication falsely recovered as Saved: " + actual);
                cases.put(new JSONObject().put("case", "empty_published_uri")
                        .put("uri", publication.toString()).put("status", "PASS"));
            } finally { recovery.close(); }
            Uri valid = null;
            try (android.database.Cursor cursor = runner.getTargetContext().getContentResolver().query(
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                    new String[]{MediaStore.MediaColumns._ID},
                    MediaStore.MediaColumns.OWNER_PACKAGE_NAME + "=? AND " + MediaStore.MediaColumns.SIZE + ">0",
                    new String[]{runner.getTargetContext().getPackageName()},
                    MediaStore.MediaColumns._ID + " ASC")) {
                if (cursor != null && cursor.moveToFirst()) valid = ContentUris.withAppendedId(
                        MediaStore.Video.Media.EXTERNAL_CONTENT_URI, cursor.getLong(0));
            }
            if (valid == null) throw new AssertionError("Existing nonempty controlled QA video required");
            JSONObject good = recover(runner, group, "valid_publication", valid.toString());
            if (!"completed".equals(good.getString("state")) || !valid.toString().equals(good.optString("uri")))
                throw new AssertionError("Valid published output was not recovered");
            cases.put(new JSONObject().put("case", "nonempty_published_uri").put("uri", valid.toString()).put("status", "PASS"));
            File damaged = new File(group, "damaged_journal");
            if (!damaged.mkdir()) throw new AssertionError("Fresh damaged context required");
            byte[] damagedBytes = "{invalid journal".getBytes(StandardCharsets.UTF_8);
            writeNew(new File(damaged, "export_jobs.json"), damagedBytes);
            ContextWrapper damagedContext = new ContextWrapper(runner.getTargetContext()) {
                @Override public File getFilesDir() { return damaged; }
            };
            ExportQueue damagedQueue = new ExportQueue(damagedContext);
            try {
                JSONArray displayed = new JSONArray(damagedQueue.list());
                if (displayed.length() != 1 || !"notice".equals(displayed.getJSONObject(0).optString("type"))
                        || damagedQueue.diagnostics().get("warning") == null)
                    throw new AssertionError("Damaged journal must expose recovery warning");
                File[] backups = damaged.listFiles((dir, name) -> name.startsWith("export_jobs_recovery_"));
                if (backups == null || backups.length != 1 || !java.util.Arrays.equals(
                        java.nio.file.Files.readAllBytes(backups[0].toPath()), damagedBytes))
                    throw new AssertionError("Damaged source must be retained byte-exact");
            } finally { damagedQueue.close(); }
            cases.put(new JSONObject().put("case", "damaged_journal_backup").put("status", "PASS"));

            File blocked = new File(group, "write_obstruction");
            if (!blocked.mkdir()) throw new AssertionError("Fresh write fault context required");
            byte[] original = new JSONArray().put(new JSONObject().put("id", "qa_keep")
                    .put("state", "cancelled").put("project", new JSONObject().put("clips", new JSONArray())))
                    .toString().getBytes(StandardCharsets.UTF_8);
            writeNew(new File(blocked, "export_jobs.json"), original);
            // Directory obstruction simulates failed AtomicFile startWrite;
            // no disk fill, permission change or live file mutation.
            if (!new File(blocked, "export_jobs.json.new").mkdir()) throw new AssertionError("Fresh obstruction required");
            writeNew(new File(blocked, "export_jobs.json.new/retained_fault_fixture.txt"), original);
            ContextWrapper blockedContext = new ContextWrapper(runner.getTargetContext()) {
                @Override public File getFilesDir() { return blocked; }
            };
            boolean rejected = false;
            try {
                ExportQueue unexpected = new ExportQueue(blockedContext);
                unexpected.close();
            } catch (Exception expected) {
                if (!(expected instanceof java.io.IOException)) throw expected;
                rejected = true;
            }
            if (!rejected || !java.util.Arrays.equals(original,
                    java.nio.file.Files.readAllBytes(new File(blocked, "export_jobs.json").toPath())))
                throw new AssertionError("Failed write must preserve original journal");
            cases.put(new JSONObject().put("case", "write_obstruction_preserves_source").put("status", "PASS"));
            JSONObject report = new JSONObject().put("cases", cases)
                    .put("scope", "Synthetic cancelled history and isolated native recovery faults; not 1001 real encodes or UI pagination")
                    .put("liveJournalUntouched", true).put("fixtureDirectory", group.getAbsolutePath());
            writeNew(new File(group, "report.json"), report.toString().getBytes(StandardCharsets.UTF_8));
            result.putString("stream", "TASK09B_EXPORT_HISTORY_PASS:" + report);
            runner.finish(Activity.RESULT_OK, result);
        } catch (Throwable error) {
            result.putString("stream", "TASK09B_EXPORT_HISTORY_FAIL:" + error);
            runner.finish(Activity.RESULT_CANCELED, result);
        }
    }
}
