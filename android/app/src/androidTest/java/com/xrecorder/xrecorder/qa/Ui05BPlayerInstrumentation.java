package com.xrecorder.xrecorder.qa;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.os.SystemClock;
import android.provider.OpenableColumns;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.VideoView;
import com.xrecorder.xrecorder.R;
import com.xrecorder.xrecorder.media.VideoPreviewActivity;
import com.xrecorder.xrecorder.recording.CaptureConfig;
import java.security.MessageDigest;
import org.json.JSONArray;
import org.json.JSONObject;

/** UI05B read-only playback fixture regression. No recording or file writes. */
public final class Ui05BPlayerInstrumentation {
    private final Instrumentation runner;
    private Uri uri;
    private String expectedHash;
    private final boolean includeGestureBack;

    private Ui05BPlayerInstrumentation(Instrumentation runner, Bundle args) {
        this.runner = runner;
        uri = Uri.parse(args.getString("uri", ""));
        expectedHash = args.getString("sha256", "");
        includeGestureBack = "true".equals(args.getString("gestureBack"));
    }
    public static void run(Instrumentation runner, Bundle args) {
        new Ui05BPlayerInstrumentation(runner, args).execute();
    }

    private String hash() throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        try (var input = runner.getTargetContext().getContentResolver().openInputStream(uri)) {
            if (input == null) throw new AssertionError("Missing fixture");
            byte[] buffer = new byte[65536];
            int n;
            while ((n = input.read(buffer)) != -1) digest.update(buffer, 0, n);
        }
        StringBuilder result = new StringBuilder();
        for (byte b : digest.digest()) result.append(String.format("%02x", b & 255));
        return result.toString();
    }

    private static VideoView video(View view) {
        if (view instanceof VideoView) return (VideoView) view;
        if (view instanceof ViewGroup) {
            for (int i=0;i<((ViewGroup)view).getChildCount();i++) {
                VideoView found = video(((ViewGroup)view).getChildAt(i));
                if (found != null) return found;
            }
        }
        return null;
    }

    private void execute() {
        Bundle result = new Bundle();
        JSONArray cases = new JSONArray();
        String currentMode = "setup";
        try {
            if (!"content".equals(uri.getScheme()) || !expectedHash.matches("[0-9a-f]{64}"))
                throw new AssertionError("Explicit content URI and fixture SHA required");
            try (Cursor row = runner.getTargetContext().getContentResolver().query(uri,
                    new String[]{OpenableColumns.DISPLAY_NAME}, null, null, null)) {
                if (row == null || !row.moveToFirst() ||
                    (!"Edited_ca13829a-b90f-4ac0-96f1-8723256517db.mp4".equals(row.getString(0)) &&
                     !("content://media/external/video/media/115".equals(uri.toString()) &&
                       "8925ac2f0764e8bcdbcf1b70f5f28b373b4653f7a7aa0c8b163ebfa00001c34f".equals(expectedHash))))
                    throw new AssertionError("Only the retained UI04 QA video is permitted");
            }
            if (!hash().equals(expectedHash)) throw new AssertionError("Fixture mismatch before run");
            String[] modes = includeGestureBack
                ? new String[]{"visible-back", "system-back", "landscape-back", "reopen-back", "gesture-back"}
                : new String[]{"visible-back", "system-back", "landscape-back", "reopen-back"};
            for (String mode : modes) {
                currentMode = mode;
                Activity activity = runner.startActivitySync(new Intent(runner.getTargetContext(), VideoPreviewActivity.class)
                    .setData(uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
                if ("landscape-back".equals(mode)) {
                    runner.runOnMainSync(() -> activity.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE));
                    for (int i=0;i<100;i++) {
                        SystemClock.sleep(50);
                        VideoPreviewActivity current = VideoPreviewActivity.Companion.getInstance();
                        if (current != null && current.getResources().getConfiguration().orientation == 2) break;
                    }
                }
                runner.waitForIdleSync();
                VideoPreviewActivity current = VideoPreviewActivity.Companion.getInstance();
                if (current == null) throw new AssertionError("Player unexpectedly closed");
                if ("visible-back".equals(mode))
                    result.putString("readOnlyCaptureConfigCapabilities",
                        new JSONObject(CaptureConfig.Companion.capabilities(current)).toString());
                View button = current.findViewById(R.id.p2_player_back);
                if (button == null) throw new AssertionError("Missing visible Back");
                float density = current.getResources().getDisplayMetrics().density;
                if (button.getWidth()/density < 48 || button.getHeight()/density < 48 ||
                    button.getContentDescription() == null || !button.isShown())
                    throw new AssertionError("Back target/label/visibility invalid");
                VideoView player = video(current.getWindow().getDecorView());
                if (player == null) throw new AssertionError("Missing native player");
                runner.runOnMainSync(player::pause);
                long exitStarted = SystemClock.elapsedRealtime();
                if ("system-back".equals(mode)) runner.sendKeyDownUpSync(KeyEvent.KEYCODE_BACK);
                else if ("gesture-back".equals(mode)) {
                    int width = current.getResources().getDisplayMetrics().widthPixels;
                    int middle = current.getResources().getDisplayMetrics().heightPixels / 2;
                    // Normal Android edge gesture through the existing system
                    // input tool. Caller must verify gestural navigation mode.
                    try (var input = new android.os.ParcelFileDescriptor.AutoCloseInputStream(
                            runner.getUiAutomation().executeShellCommand(
                                "input swipe 1 " + middle + " " + width / 3 + " " + middle + " 250"))) {
                        byte[] drain = new byte[256];
                        while (input.read(drain) != -1) { }
                    }
                }
                else runner.runOnMainSync(button::performClick);
                for (int i=0;i<100 && VideoPreviewActivity.Companion.getInstance()!=null;i++) SystemClock.sleep(20);
                VideoPreviewActivity remaining = VideoPreviewActivity.Companion.getInstance();
                if (remaining!=null) throw new AssertionError("Player not disposed after Back; finishing="+
                    remaining.isFinishing()+"; destroyed="+remaining.isDestroyed()+"; sameInstance="+(remaining==current));
                runner.runOnMainSync(() -> { if (player.isPlaying()) throw new AssertionError("Playback survived exit"); });
                cases.put(new JSONObject().put("case",mode).put("targetDp",button.getWidth()/density)
                    .put("disposed",true).put("exitMs",SystemClock.elapsedRealtime()-exitStarted));
            }
            if (!hash().equals(expectedHash)) throw new AssertionError("Fixture changed");
            result.putString("ui05b",new JSONObject().put("status","PASS").put("cases",cases).put("sourceHashExact",true).toString());
            runner.finish(Activity.RESULT_OK,result);
        } catch (Throwable failure) {
            VideoPreviewActivity current = VideoPreviewActivity.Companion.getInstance();
            if (current != null) runner.runOnMainSync(current::finish);
            result.putString("ui05b","FAIL: "+failure+"; mode="+currentMode+"; completed="+cases);
            runner.finish(Activity.RESULT_CANCELED,result);
        }
    }
}
