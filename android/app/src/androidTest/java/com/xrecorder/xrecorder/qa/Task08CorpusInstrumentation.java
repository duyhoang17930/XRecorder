package com.xrecorder.xrecorder.qa;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.provider.MediaStore;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Arrays;
import org.json.JSONArray;
import org.json.JSONObject;

/** New, app-owned, byte-verified media on the empty TASK08 AVD only. */
public final class Task08CorpusInstrumentation {
    private static final String MANIFEST = "task08_profile_1794122000000.json";
    public static void run(Instrumentation runner) {
        Bundle output = new Bundle();
        try {
            Context context = runner.getTargetContext();
            if (!"ThreeHRecorder_TASK08_API36".equals(avdName())) {
                throw new AssertionError("TASK08-only AVD required");
            }
            File seed = new File(context.getFilesDir(), MANIFEST);
            if (seed.exists()) throw new AssertionError("Preserve existing corpus manifest");
            Uri collection = MediaStore.Images.Media.EXTERNAL_CONTENT_URI;
            try (Cursor existing = context.getContentResolver().query(collection,
                    new String[]{"_id"}, "owner_package_name=?",
                    new String[]{context.getPackageName()}, null)) {
                if (existing == null || existing.getCount() != 0)
                    throw new AssertionError("Fresh app-owned corpus required; no destructive reset");
            }
            File[] files = new File(context.getFilesDir(), "task08_corpus_source").listFiles(
                    f -> f.isFile() && f.getName().matches("task08_[0-9]{4}\\.(png|jpg|jpeg|gif)"));
            if (files == null || files.length != 1013)
                throw new AssertionError("1013 private source files required; found=" + (files == null ? "unreadable" : files.length));
            Arrays.sort(files, (a, b) -> a.getName().compareTo(b.getName()));
            JSONArray identities = new JSONArray();
            JSONArray evidence = new JSONArray();
            for (int i = 0; i < files.length; i++) {
                File source = files[i];
                ContentValues values = new ContentValues();
                values.put(MediaStore.MediaColumns.DISPLAY_NAME, source.getName());
                String ext = source.getName().substring(source.getName().lastIndexOf('.') + 1);
                values.put(MediaStore.MediaColumns.MIME_TYPE,
                        "image/" + ((ext.equals("jpg") || ext.equals("jpeg")) ? "jpeg" : ext));
                values.put(MediaStore.MediaColumns.RELATIVE_PATH, "Pictures/XRecorder/TASK08/");
                values.put(MediaStore.MediaColumns.DATE_ADDED, 1794110000L - i);
                values.put(MediaStore.MediaColumns.DATE_MODIFIED, 1794110000L - i);
                values.put(MediaStore.MediaColumns.IS_PENDING, 1);
                Uri uri = context.getContentResolver().insert(collection, values);
                if (uri == null) throw new AssertionError("Insert failed; keep partial fixture for inspection");
                MessageDigest digest = MessageDigest.getInstance("SHA-256");
                try (FileInputStream in = new FileInputStream(source);
                     OutputStream out = context.getContentResolver().openOutputStream(uri)) {
                    if (out == null) throw new AssertionError("Output unavailable");
                    byte[] buffer = new byte[65536];
                    int count;
                    while ((count = in.read(buffer)) >= 0) {
                        out.write(buffer, 0, count);
                        digest.update(buffer, 0, count);
                    }
                }
                values.clear(); values.put(MediaStore.MediaColumns.IS_PENDING, 0);
                if (context.getContentResolver().update(uri, values, null, null) != 1)
                    throw new AssertionError("Publication failed");
                MessageDigest readBack = MessageDigest.getInstance("SHA-256");
                try (java.io.InputStream in = context.getContentResolver().openInputStream(uri)) {
                    if (in == null) throw new AssertionError("Readback unavailable");
                    byte[] buffer = new byte[65536]; int count;
                    while ((count = in.read(buffer)) >= 0) readBack.update(buffer, 0, count);
                }
                byte[] original = digest.digest();
                if (!Arrays.equals(original, readBack.digest())) throw new AssertionError("Source parity failure");
                try (Cursor row = context.getContentResolver().query(uri,
                        new String[]{"_size", "generation_modified", "owner_package_name"}, null, null, null)) {
                    if (row == null || !row.moveToFirst() || row.getLong(0) != source.length()
                            || !context.getPackageName().equals(row.getString(2)))
                        throw new AssertionError("Wrong ownership/size");
                    identities.put(uri + ":" + row.getLong(0) + ":" + row.getLong(1));
                }
                StringBuilder sha = new StringBuilder();
                for (byte b : original) sha.append(String.format(java.util.Locale.ROOT, "%02x", b & 255));
                evidence.put(new JSONObject().put("name", source.getName()).put("uri", uri.toString())
                        .put("bytes", source.length()).put("sha256", sha.toString()));
            }
            if (!seed.createNewFile()) throw new AssertionError("Preserve existing manifest");
            try (FileOutputStream out = new FileOutputStream(seed)) {
                out.write(identities.toString().getBytes(StandardCharsets.UTF_8)); out.getFD().sync();
            }
            File evidenceFile = new File(context.getFilesDir(), "task08_owned_corpus_evidence.json");
            if (!evidenceFile.createNewFile()) throw new AssertionError("Preserve evidence");
            try (FileOutputStream out = new FileOutputStream(evidenceFile)) {
                out.write(evidence.toString().getBytes(StandardCharsets.UTF_8)); out.getFD().sync();
            }
            output.putString("stream", "TASK08_OWNED_CORPUS_PASS:1013;source/readback SHA exact;manifest=" + MANIFEST);
            runner.finish(Activity.RESULT_OK, output);
        } catch (Throwable error) {
            output.putString("stream", "TASK08_OWNED_CORPUS_FAIL:" + error);
            runner.finish(Activity.RESULT_CANCELED, output);
        }
    }

    private static String avdName() throws Exception {
        Process process = new ProcessBuilder("getprop", "ro.boot.qemu.avd_name").start();
        java.io.BufferedReader reader = new java.io.BufferedReader(new java.io.InputStreamReader(process.getInputStream()));
        String value = reader.readLine();
        reader.close();
        if (process.waitFor() != 0) throw new AssertionError("Cannot verify AVD");
        return value;
    }
}
