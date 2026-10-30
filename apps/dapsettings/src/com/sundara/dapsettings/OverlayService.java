package com.sundara.dapsettings;

import android.app.Notification;
import android.app.Service;
import android.content.Intent;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.PowerManager;
import android.util.Log;

/**
 * Boot helper only. The settings gear is now drawn inside the Flutter player,
 * so this service no longer needs a system overlay.
 */
public class OverlayService extends Service {

    public static final String EXTRA_BOOT = "boot";
    private static final String TAG = "DapSettings";
    private static final int NOTIFICATION_ID = 1001;

    private final Handler handler = new Handler(Looper.getMainLooper());

    private final Runnable bootRoutine = new Runnable() {
        @Override
        public void run() {
            wakeScreen();
            dismissKeyguard();
            launchPlayer();
        }
    };

    @Override
    public void onCreate() {
        super.onCreate();
        startForeground(NOTIFICATION_ID, buildNotification());
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && intent.getBooleanExtra(EXTRA_BOOT, false)) {
            handler.removeCallbacks(bootRoutine);
            handler.postDelayed(bootRoutine, 3000L);
        }
        return START_STICKY;
    }

    private Notification buildNotification() {
        Notification.Builder builder = new Notification.Builder(this)
                .setSmallIcon(android.R.drawable.ic_media_play)
                .setContentTitle("DAP")
                .setContentText("Player controls active")
                .setOngoing(true)
                .setPriority(Notification.PRIORITY_MIN);
        return builder.build();
    }

    private void wakeScreen() {
        PowerManager pm = (PowerManager) getSystemService(POWER_SERVICE);
        if (pm == null) {
            return;
        }
        try {
            PowerManager.WakeLock lock = pm.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK
                            | PowerManager.ACQUIRE_CAUSES_WAKEUP, "dap:boot");
            lock.acquire(8000L);
            lock.release();
        } catch (Exception ignored) {
        }
    }

    private void dismissKeyguard() {
        try {
            android.app.KeyguardManager km =
                    (android.app.KeyguardManager) getSystemService(KEYGUARD_SERVICE);
            if (km != null) {
                km.newKeyguardLock("dapboot").disableKeyguard();
            }
        } catch (Exception ignored) {
        }
    }

    private void launchPlayer() {
        try {
            startActivity(SettingsActivity.playerIntent());
        } catch (Exception e) {
            Log.w(TAG, "Could not launch player", e);
        }
    }

    @Override
    public void onDestroy() {
        handler.removeCallbacksAndMessages(null);
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
