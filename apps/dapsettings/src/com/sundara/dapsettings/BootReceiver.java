package com.sundara.dapsettings;

import android.app.KeyguardManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class BootReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || !Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) {
            return;
        }
        try {
            KeyguardManager km = (KeyguardManager) context.getSystemService(Context.KEYGUARD_SERVICE);
            if (km != null) {
                km.newKeyguardLock("dapboot").disableKeyguard();
            }
        } catch (Exception ignored) {
        }

        Intent service = new Intent(context, OverlayService.class);
        service.putExtra(OverlayService.EXTRA_BOOT, true);
        try {
            context.startService(service);
        } catch (Exception ignored) {
        }
    }
}
