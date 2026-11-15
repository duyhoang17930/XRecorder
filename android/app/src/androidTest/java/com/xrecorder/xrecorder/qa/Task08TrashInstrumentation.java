package com.xrecorder.xrecorder.qa;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.ContextWrapper;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.net.Uri;
import android.os.Environment;
import android.os.Bundle;
import android.provider.MediaStore;
import com.xrecorder.xrecorder.media.MediaActions;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.json.JSONObject;

/** Isolated damaged-Trash fixtures plus one task-owned MediaStore Trash/Restore round trip. */
public final class Task08TrashInstrumentation {
    public static void run(Instrumentation runner) {
        Bundle output = new Bundle();
        File trash = null;
        String[] foreign = {"qa_imported_model.bin", "qa_imported_document.part", "qa_manifest.json"};
        byte[][] originals = {{1,2,3,4}, {5,6,7,8}, {'[',']'}};
        File[] managedFixtures = null;
        byte[][] managedOriginals = null;
        long modified = System.currentTimeMillis() - 2L * 86400000L;
        int restored = 0;
        boolean passed = false;
        Throwable failure = null;
        String mediaStoreTransaction = "mediaStoreTrashRestore=NOT_RUN";
        try {
            File root = new File(runner.getTargetContext().getFilesDir(), "task08_trash_" + System.currentTimeMillis());
            if (!root.mkdir()) throw new AssertionError("Fresh fixture directory required");
            trash = new File(root, "trash");
            File backups = new File(root, "source_backup");
            if (!trash.mkdir() || !backups.mkdir()) throw new AssertionError("Fresh backup/trash required");
            for (int i = 0; i < foreign.length; i++) {
                for (File file : new File[]{new File(trash, foreign[i]), new File(backups, foreign[i])}) {
                    if (!file.createNewFile()) throw new AssertionError("Preserve existing fixture");
                    try (FileOutputStream out = new FileOutputStream(file)) { out.write(originals[i]); out.getFD().sync(); }
                }
                if (!new File(trash, foreign[i]).setLastModified(modified)) throw new AssertionError("mtime fixture unavailable");
            }
            String managedId = "00000000-0000-0000-0000-000000000008";
            File corrupt = new File(trash, managedId + ".json");
            File managedPayload = new File(trash, managedId + ".bin");
            if (!corrupt.createNewFile() || !managedPayload.createNewFile()) throw new AssertionError("New managed fixtures required");
            try (FileOutputStream out = new FileOutputStream(corrupt)) { out.write('{'); }
            try (FileOutputStream out = new FileOutputStream(managedPayload)) { out.write(new byte[]{9,10,11,12}); }

            String expiredId = "00000000-0000-0000-0000-000000000009";
            String orphanBinId = "00000000-0000-0000-0000-000000000010";
            String orphanPartId = "00000000-0000-0000-0000-000000000011";
            byte[] expiredPayloadBytes = {21,22,23,24};
            byte[] orphanBinBytes = {31,32,33,34};
            byte[] orphanPartBytes = {41,42,43,44};
            long deletedAt = System.currentTimeMillis() - 2L * 86400000L;
            String payloadHash = hex(MessageDigest.getInstance("SHA-256").digest(expiredPayloadBytes));
            JSONObject original = new JSONObject()
                    .put("id", "content://media/external/images/media/999999")
                    .put("uri", "content://media/external/images/media/999999")
                    .put("name", "prompt05_expired_fixture.png")
                    .put("mime", "image/png")
                    .put("size", expiredPayloadBytes.length)
                    .put("created", deletedAt)
                    .put("modified", deletedAt)
                    .put("source", "recording")
                    .put("owned", true);
            byte[] expiredMetadataBytes = new JSONObject()
                    .put("id", expiredId)
                    .put("originalMetadata", original)
                    .put("deletedAt", deletedAt)
                    .put("expiresAt", deletedAt + 86400000L)
                    .put("sha256", payloadHash)
                    .toString().getBytes(StandardCharsets.UTF_8);
            managedFixtures = new File[]{
                    new File(trash, expiredId + ".json"),
                    new File(trash, expiredId + ".bin"),
                    new File(trash, orphanBinId + ".bin"),
                    new File(trash, orphanPartId + ".part"),
            };
            managedOriginals = new byte[][]{
                    expiredMetadataBytes,
                    expiredPayloadBytes,
                    orphanBinBytes,
                    orphanPartBytes,
            };
            for (int i = 0; i < managedFixtures.length; i++) {
                if (!managedFixtures[i].createNewFile()) throw new AssertionError("New isolated Trash fixture required");
                try (FileOutputStream out = new FileOutputStream(managedFixtures[i])) {
                    out.write(managedOriginals[i]);
                    out.getFD().sync();
                }
                if (!managedFixtures[i].setLastModified(modified)) throw new AssertionError("Trash fixture mtime unavailable");
            }

            MediaActions actions = new MediaActions(new ContextWrapper(runner.getTargetContext()) {
                @Override public File getFilesDir() { return root; }
            });
            List<?> result = actions.listTrash();
            for (int i = 0; i < foreign.length; i++) {
                File file = new File(trash, foreign[i]);
                if (!file.isFile()) throw new AssertionError("Foreign file deleted by listTrash: " + foreign[i]);
                byte[] bytes = new byte[originals[i].length];
                try (FileInputStream in = new FileInputStream(file)) {
                    if (in.read(bytes) != bytes.length || !Arrays.equals(bytes, originals[i])) throw new AssertionError("Foreign bytes changed");
                }
            }
            StringBuilder purged = new StringBuilder();
            for (int i = 0; i < managedFixtures.length; i++) {
                File file = managedFixtures[i];
                if (!file.isFile()) purged.append(file.getName()).append(" missing; ");
                else {
                    byte[] actual = new byte[managedOriginals[i].length];
                    try (FileInputStream in = new FileInputStream(file)) {
                        if (in.read(actual) != actual.length || !Arrays.equals(actual, managedOriginals[i]))
                            purged.append(file.getName()).append(" bytes changed; ");
                    }
                }
            }
            if (purged.length() > 0) throw new AssertionError("Opening Trash purged retained task fixtures: " + purged);
            boolean expiredVisible = false;
            boolean corruptVisible = false;
            for (Object value : result) if (value instanceof Map) {
                Map<?, ?> entry = (Map<?, ?>) value;
                expiredVisible |= expiredId.equals(entry.get("id")) && !Boolean.TRUE.equals(entry.get("unreadable"));
                corruptVisible |= managedId.equals(entry.get("id")) && Boolean.TRUE.equals(entry.get("unreadable"));
            }
            if (!expiredVisible || !corruptVisible)
                throw new AssertionError("Expired entry must remain restorable and damaged entry must remain visible");
            if (corrupt.length() != 1 || managedPayload.length() != 4)
                throw new AssertionError("Managed damaged record was destroyed");
            mediaStoreTransaction = mediaStoreTrashRestore(runner, root, backups);
            passed = true;
        } catch (Throwable error) {
            failure = error;
        } finally {
            // Red reproduction may remove only these tiny, freshly generated
            // fixtures. Restore absent inputs from the retained source bytes;
            // never replace an existing file or delete a retained artifact.
            if (trash != null) for (int i = 0; i < foreign.length; i++) {
                File file = new File(trash, foreign[i]);
                if (!file.exists()) try {
                    if (!file.createNewFile()) throw new AssertionError("Restore collision");
                    try (FileOutputStream out = new FileOutputStream(file)) { out.write(originals[i]); out.getFD().sync(); }
                    if (!file.setLastModified(modified)) throw new AssertionError("Restore mtime failed");
                    restored++;
                } catch (Throwable restoreError) { failure = restoreError; passed = false; }
            }
            if (managedFixtures != null && managedOriginals != null) for (int i = 0; i < managedFixtures.length; i++) {
                File file = managedFixtures[i];
                if (!file.exists()) try {
                    if (!file.createNewFile()) throw new AssertionError("Restore collision");
                    try (FileOutputStream out = new FileOutputStream(file)) {
                        out.write(managedOriginals[i]);
                        out.getFD().sync();
                    }
                    if (!file.setLastModified(modified)) throw new AssertionError("Restore task fixture mtime failed");
                    restored++;
                } catch (Throwable restoreError) { failure = restoreError; passed = false; }
            }
        }
        output.putString("stream", (passed ? "TASK08_TRASH_FOREIGN_PASS:" : "TASK08_TRASH_FOREIGN_FAIL:")
                + (failure == null ? "foreign bytes kept;expired and orphan Trash bytes retained;corrupt entry visible" : failure)
                + ";restoredRedFixtureInputs=" + restored + ";" + mediaStoreTransaction + ";fixture=" + trash);
        runner.finish(passed ? Activity.RESULT_OK : Activity.RESULT_CANCELED, output);
    }

    /** Exercises native Trash/Restore on one task-created MediaStore row; the restored output is kept. */
    private static String mediaStoreTrashRestore(Instrumentation runner, File root, File backups) throws Exception {
        android.content.Context context = runner.getTargetContext();
        ContentResolver resolver = context.getContentResolver();
        Bitmap fixtureBitmap = Bitmap.createBitmap(64, 64, Bitmap.Config.ARGB_8888);
        fixtureBitmap.eraseColor(Color.rgb(255, 121, 72));
        ByteArrayOutputStream encoded = new ByteArrayOutputStream();
        boolean encodedPng = fixtureBitmap.compress(Bitmap.CompressFormat.PNG, 100, encoded);
        fixtureBitmap.recycle();
        if (!encodedPng) throw new AssertionError("Could not encode synthetic PNG fixture");
        byte[] sourceBytes = encoded.toByteArray();
        Bitmap decoded = BitmapFactory.decodeByteArray(sourceBytes, 0, sourceBytes.length);
        if (decoded == null || decoded.getWidth() != 64 || decoded.getHeight() != 64)
            throw new AssertionError("Generated PNG fixture did not fully decode as 64x64");
        decoded.recycle();

        long now = System.currentTimeMillis();
        String name = "Prompt05_TrashRestore_" + now + ".png";
        File sourceBackup = new File(backups, name + ".source");
        if (!sourceBackup.createNewFile()) throw new AssertionError("Fresh source backup required");
        try (FileOutputStream out = new FileOutputStream(sourceBackup)) {
            out.write(sourceBytes);
            out.getFD().sync();
        }
        String expectedHash = hex(MessageDigest.getInstance("SHA-256").digest(sourceBytes));

        ContentValues values = new ContentValues();
        values.put(MediaStore.MediaColumns.DISPLAY_NAME, name);
        values.put(MediaStore.MediaColumns.MIME_TYPE, "image/png");
        values.put(MediaStore.MediaColumns.RELATIVE_PATH,
                Environment.DIRECTORY_PICTURES + "/Prompt05QA");
        values.put(MediaStore.MediaColumns.IS_PENDING, 1);
        Uri source = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values);
        if (source == null) throw new AssertionError("Could not create task-owned MediaStore source");

        String trashId = null;
        String restored = null;
        MediaActions actions = new MediaActions(context);
        try {
            try (OutputStream out = resolver.openOutputStream(source, "w")) {
                if (out == null) throw new AssertionError("Could not write task-owned source");
                out.write(sourceBytes);
                out.flush();
            }
            ContentValues publish = new ContentValues();
            publish.put(MediaStore.MediaColumns.IS_PENDING, 0);
            if (resolver.update(source, publish, null, null) != 1)
                throw new AssertionError("Could not publish task-owned source");

            Map<String, Object> original = new HashMap<>();
            original.put("id", source.toString());
            original.put("uri", source.toString());
            original.put("name", name);
            original.put("mime", "image/png");
            original.put("size", (long) sourceBytes.length);
            original.put("created", now);
            original.put("modified", now);
            original.put("source", "imported");
            original.put("owned", true);

            Map<?, ?> entry = actions.trash(source, original);
            trashId = (String) entry.get("id");
            boolean sourceStillPresent;
            try (Cursor cursor = resolver.query(source,
                    new String[]{MediaStore.MediaColumns._ID}, null, null, null)) {
                sourceStillPresent = cursor != null && cursor.moveToFirst();
            }
            if (sourceStillPresent) throw new AssertionError("Trash left the original MediaStore row visible");

            File payload = new File(new File(context.getFilesDir(), "trash"), trashId + ".bin");
            byte[] trashedBytes = read(payload);
            if (!expectedHash.equals(hex(MessageDigest.getInstance("SHA-256").digest(trashedBytes))))
                throw new AssertionError("Trash copy bytes did not match the generated source");
            boolean listed = false;
            for (Object value : actions.listTrash()) if (value instanceof Map) {
                Map<?, ?> row = (Map<?, ?>) value;
                listed |= trashId.equals(row.get("id")) && !Boolean.TRUE.equals(row.get("unreadable"));
            }
            if (!listed) throw new AssertionError("Task-owned source was not visible in Trash");

            restored = actions.restore(trashId);
            Uri restoredUri = Uri.parse(restored);
            byte[] restoredBytes;
            try (InputStream input = resolver.openInputStream(restoredUri)) {
                if (input == null) throw new AssertionError("Restored MediaStore URI could not be opened");
                restoredBytes = read(input);
            }
            String restoredHash = hex(MessageDigest.getInstance("SHA-256").digest(restoredBytes));
            if (!expectedHash.equals(restoredHash)) throw new AssertionError("Restored bytes differ from the source SHA-256");
            if (!"image/png".equals(resolver.getType(restoredUri)))
                throw new AssertionError("Restored MIME type changed");
            try (Cursor cursor = resolver.query(restoredUri, new String[]{
                    MediaStore.MediaColumns.DISPLAY_NAME,
                    MediaStore.MediaColumns.OWNER_PACKAGE_NAME,
                    MediaStore.MediaColumns.IS_PENDING,
                    MediaStore.MediaColumns.SIZE}, null, null, null)) {
                if (cursor == null || !cursor.moveToFirst()) throw new AssertionError("Restored MediaStore row missing");
                String restoredName = cursor.getString(0);
                String owner = cursor.getString(1);
                int pending = cursor.getInt(2);
                long size = cursor.getLong(3);
                if (!restoredName.startsWith("Restored_") || !restoredName.contains(name)
                        || !context.getPackageName().equals(owner) || pending != 0
                        || size != sourceBytes.length)
                    throw new AssertionError("Restored MediaStore metadata is incorrect");
            }
            for (Object value : actions.listTrash()) if (value instanceof Map) {
                if (trashId.equals(((Map<?, ?>) value).get("id")))
                    throw new AssertionError("Successfully restored item remained in Trash");
            }

            JSONObject evidence = new JSONObject()
                    .put("operation", "task-created MediaStore trash then restore")
                    .put("sourceUri", source.toString())
                    .put("sourceName", name)
                    .put("sourceBytes", sourceBytes.length)
                    .put("restoredUri", restored)
                    .put("restoredName", "Restored output; see MediaStore")
                    .put("mime", "image/png")
                    .put("sha256", expectedHash)
                    .put("isPending", 0)
                    .put("trashId", trashId);
            File report = new File(root, "media_store_trash_restore.json");
            try (FileOutputStream out = new FileOutputStream(report)) {
                out.write(evidence.toString(2).getBytes(StandardCharsets.UTF_8));
                out.getFD().sync();
            }
            return "mediaStoreTrashRestore=PASS;source=" + source + ";restored=" + restored + ";sha256=" + expectedHash;
        } finally {
            // If an assertion fails after moving the source, make one safe restore attempt.
            // If restoration still fails, leave the generated backup in private Trash.
            if (trashId != null && restored == null) try {
                restored = actions.restore(trashId);
            } catch (Exception ignored) { /* Keep the synthetic recovery input in Trash. */ }
        }
    }

    private static byte[] read(File file) throws Exception {
        try (FileInputStream input = new FileInputStream(file)) { return read(input); }
    }

    private static byte[] read(InputStream input) throws Exception {
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        byte[] buffer = new byte[4096];
        int count;
        while ((count = input.read(buffer)) >= 0) output.write(buffer, 0, count);
        return output.toByteArray();
    }

    private static String hex(byte[] bytes) {
        StringBuilder result = new StringBuilder(bytes.length * 2);
        for (byte value : bytes) result.append(String.format("%02x", value & 0xff));
        return result.toString();
    }
}
