package com.xrecorder.xrecorder.qa;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.ContextWrapper;
import android.os.Bundle;
import com.xrecorder.xrecorder.media.MediaActions;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

/** Four-byte foreign-file fixtures with backups; never visits the real trash. */
public final class Task08TrashInstrumentation {
    public static void run(Instrumentation runner) {
        Bundle output = new Bundle();
        File trash = null;
        String[] foreign = {"qa_imported_model.bin", "qa_imported_document.part", "qa_manifest.json"};
        byte[][] originals = {{1,2,3,4}, {5,6,7,8}, {'[',']'}};
        long modified = System.currentTimeMillis() - 2L * 86400000L;
        int restored = 0;
        boolean passed = false;
        Throwable failure = null;
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
            if (result.size() != 1 || !(result.get(0) instanceof Map)
                    || !managedId.equals(((Map<?, ?>) result.get(0)).get("id"))
                    || !Boolean.TRUE.equals(((Map<?, ?>) result.get(0)).get("unreadable")))
                throw new AssertionError("Foreign JSON shown as trash, or managed corrupt record hidden");
            if (corrupt.length() != 1 || managedPayload.length() != 4)
                throw new AssertionError("Managed damaged record was destroyed");
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
        }
        output.putString("stream", (passed ? "TASK08_TRASH_FOREIGN_PASS:" : "TASK08_TRASH_FOREIGN_FAIL:")
                + (failure == null ? "foreign bin/part/json kept;not listed as trash" : failure)
                + ";restoredRedFixtureInputs=" + restored + ";fixture=" + trash);
        runner.finish(passed ? Activity.RESULT_OK : Activity.RESULT_CANCELED, output);
    }
}
