package com.sundara.dapsettings;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.app.KeyguardManager;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.net.wifi.ScanResult;
import android.net.wifi.WifiConfiguration;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;
import android.os.BatteryManager;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.os.StatFs;
import android.provider.Settings;
import android.text.InputType;
import android.text.format.Formatter;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.io.File;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class SettingsActivity extends Activity {

    public static final String PLAYER_PACKAGE = "com.sundara.classipod";
    private static final int REQ_LOCATION = 42;

    private static final int BG = 0xFF121418;
    private static final int SEP = 0xFF2A2F36;
    private static final int TEXT = 0xFFE8EAED;
    private static final int SECONDARY = 0xFFB0B6C0;
    private static final int MUTED = 0xFF8E939D;
    private static final int ACCENT = 0xFF0A84FF;
    private static final int WARN = 0xFFFF9F0A;

    private Typeface regularTypeface;
    private Typeface boldTypeface;
    private WifiManager wifiManager;
    private BluetoothAdapter bluetoothAdapter;

    private IpodSwitch wifiSwitch;
    private IpodSwitch btSwitch;
    private TextView wifiSub;
    private TextView btSub;
    private TextView statusBattery;
    private TextView batteryValue;
    private TextView storageValue;
    private TextView timeoutValue;
    private TextView brightnessValue;
    private IpodSlider brightnessBar;

    private boolean refreshing = false;
    private BroadcastReceiver batteryReceiver;
    private BroadcastReceiver wifiScanReceiver;
    private BroadcastReceiver btReceiver;
    private BroadcastReceiver wifiStateReceiver;
    private BroadcastReceiver btStateReceiver;
    private boolean batteryRegistered = false;
    private boolean scanningBt = false;

    private AlertDialog wifiDialog;
    private AlertDialog btDialog;
    private ArrayAdapter<String> wifiListAdapter;
    private ArrayAdapter<String> btListAdapter;
    private final List<ScanResult> wifiNetworks = new ArrayList<ScanResult>();
    private final List<BluetoothDevice> btDevices = new ArrayList<BluetoothDevice>();

    private static final long[] TIMEOUTS = {
            15000L, 30000L, 60000L, 120000L, 300000L, 600000L, 1800000L, Integer.MAX_VALUE
    };
    private static final String[] TIMEOUT_LABELS = {
            "15 seconds", "30 seconds", "1 minute", "2 minutes",
            "5 minutes", "10 minutes", "30 minutes", "Never"
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        regularTypeface = loadTypeface("fonts/DAPSans-Regular.otf", Typeface.SANS_SERIF);
        boldTypeface = loadTypeface("fonts/DAPSans-Bold.otf", Typeface.DEFAULT_BOLD);

        getWindow().addFlags(
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                        | WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                        | WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                        | WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON);
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);

        try {
            KeyguardManager km = (KeyguardManager) getSystemService(Context.KEYGUARD_SERVICE);
            if (km != null) {
                km.newKeyguardLock("dapsettings").disableKeyguard();
            }
        } catch (Exception ignored) {
        }

        wifiManager = (WifiManager) getSystemService(Context.WIFI_SERVICE);
        bluetoothAdapter = BluetoothAdapter.getDefaultAdapter();

        setContentView(buildUi());
        refreshAll();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (!batteryRegistered) {
            batteryReceiver = new BroadcastReceiver() {
                @Override
                public void onReceive(Context context, Intent intent) {
                    updateBattery(intent);
                }
            };
            registerReceiver(batteryReceiver, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
            batteryRegistered = true;
        }
        if (wifiStateReceiver == null) {
            wifiStateReceiver = new BroadcastReceiver() {
                @Override
                public void onReceive(Context context, Intent intent) {
                    refreshAll();
                }
            };
            registerReceiver(wifiStateReceiver,
                    new IntentFilter(WifiManager.WIFI_STATE_CHANGED_ACTION));
        }
        if (btStateReceiver == null) {
            btStateReceiver = new BroadcastReceiver() {
                @Override
                public void onReceive(Context context, Intent intent) {
                    refreshAll();
                }
            };
            registerReceiver(btStateReceiver,
                    new IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED));
        }
        refreshAll();
        refreshBrightness();
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (batteryRegistered && batteryReceiver != null) {
            try {
                unregisterReceiver(batteryReceiver);
            } catch (Exception ignored) {
            }
            batteryRegistered = false;
        }
        if (wifiStateReceiver != null) {
            try {
                unregisterReceiver(wifiStateReceiver);
            } catch (Exception ignored) {
            }
            wifiStateReceiver = null;
        }
        if (btStateReceiver != null) {
            try {
                unregisterReceiver(btStateReceiver);
            } catch (Exception ignored) {
            }
            btStateReceiver = null;
        }
    }

    private Typeface loadTypeface(String assetPath, Typeface fallback) {
        try {
            return Typeface.createFromAsset(getAssets(), assetPath);
        } catch (Exception ignored) {
            return fallback;
        }
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private TextView text(String value, int sp, int color, boolean bold) {
        TextView v = new TextView(this);
        v.setText(value);
        v.setTextSize(sp);
        v.setTextColor(color);
        v.setTypeface(bold ? boldTypeface : regularTypeface);
        v.setIncludeFontPadding(false);
        return v;
    }

    private View divider() {
        View v = new View(this);
        v.setBackgroundColor(SEP);
        v.setLayoutParams(new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 1));
        return v;
    }

    private GradientDrawable rounded(int color, int radiusDp) {
        GradientDrawable d = new GradientDrawable();
        d.setColor(color);
        d.setCornerRadius(dp(radiusDp));
        return d;
    }

    private TextView sectionLabel(String label) {
        TextView v = text(label, 11, MUTED, true);
        v.setLetterSpacing(0.12f);
        v.setPadding(0, dp(18), 0, dp(6));
        return v;
    }

    private LinearLayout buildStatusBar() {
        LinearLayout bar = new LinearLayout(this);
        bar.setOrientation(LinearLayout.HORIZONTAL);
        bar.setGravity(Gravity.CENTER_VERTICAL);
        bar.setBackgroundResource(R.drawable.statusbar_bg);
        bar.setPadding(dp(8), 0, dp(12), 0);
        bar.setLayoutParams(new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(30)));

        TextView back = text("\u2039", 23, ACCENT, false);
        back.setGravity(Gravity.CENTER);
        back.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                openPlayer();
            }
        });
        bar.addView(back, new LinearLayout.LayoutParams(
                dp(30), ViewGroup.LayoutParams.MATCH_PARENT));

        TextView title = text("DAP Settings", 14, TEXT, true);
        LinearLayout.LayoutParams titleLp = new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1);
        titleLp.leftMargin = dp(2);
        bar.addView(title, titleLp);

        statusBattery = text("", 13, TEXT, true);
        statusBattery.setGravity(Gravity.CENTER_VERTICAL);
        bar.addView(statusBattery);
        return bar;
    }

    private View buildUi() {
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setBackgroundColor(BG);

        page.addView(buildStatusBar());
        page.addView(divider());

        ScrollView scroll = new ScrollView(this);
        scroll.setBackgroundColor(BG);
        scroll.setFillViewport(true);

        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(dp(20), 0, dp(20), dp(20));
        scroll.addView(content, new ScrollView.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));

        page.addView(scroll, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));

        content.addView(sectionLabel("WIRELESS"));

        wifiSwitch = new IpodSwitch(this);
        wifiSwitch.setChecked(wifiManager != null && wifiManager.isWifiEnabled());
        wifiSwitch.setOnCheckedChangeListener(new OnCheckedChangeListener() {
            @Override
            public void onCheckedChanged(IpodSwitch buttonView, boolean isChecked) {
                if (!refreshing) {
                    setWifiEnabled(isChecked);
                }
            }
        });
        wifiSub = text("", 12, SECONDARY, false);
        wifiSub.setPadding(0, dp(3), 0, 0);
        LinearLayout wifiRow = toggleRow("Wi-Fi", wifiSub, wifiSwitch);
        wifiRow.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                showWifiDialog();
            }
        });
        content.addView(wifiRow);
        content.addView(divider());

        btSwitch = new IpodSwitch(this);
        btSwitch.setChecked(bluetoothAdapter != null && bluetoothAdapter.isEnabled());
        btSwitch.setOnCheckedChangeListener(new OnCheckedChangeListener() {
            @Override
            public void onCheckedChanged(IpodSwitch buttonView, boolean isChecked) {
                if (!refreshing) {
                    setBluetoothEnabled(isChecked);
                }
            }
        });
        btSub = text("", 12, SECONDARY, false);
        btSub.setPadding(0, dp(3), 0, 0);
        LinearLayout btRow = toggleRow("Bluetooth", btSub, btSwitch);
        btRow.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                showBluetoothDialog();
            }
        });
        content.addView(btRow);
        content.addView(divider());

        content.addView(sectionLabel("DISPLAY"));

        LinearLayout brightnessBlock = new LinearLayout(this);
        brightnessBlock.setOrientation(LinearLayout.VERTICAL);
        brightnessBlock.setPadding(0, dp(12), 0, dp(8));

        LinearLayout brightnessHeader = new LinearLayout(this);
        brightnessHeader.setOrientation(LinearLayout.HORIZONTAL);
        brightnessHeader.setGravity(Gravity.CENTER_VERTICAL);
        TextView brightnessTitle = text("Brightness", 17, TEXT, true);
        brightnessValue = text("", 13, SECONDARY, false);
        brightnessValue.setGravity(Gravity.END);
        brightnessHeader.addView(brightnessTitle, new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        brightnessHeader.addView(brightnessValue);
        brightnessBlock.addView(brightnessHeader);

        brightnessBar = new IpodSlider(this);
        brightnessBar.setMax(255);
        int currentBrightness = 128;
        try {
            currentBrightness = Settings.System.getInt(getContentResolver(),
                    Settings.System.SCREEN_BRIGHTNESS, 128);
        } catch (Exception ignored) {
        }
        brightnessBar.setProgress(Math.max(1, Math.min(255, currentBrightness)));
        updateBrightnessLabel(brightnessBar.getProgress());
        brightnessBar.setOnSliderChangeListener(new OnSliderChangeListener() {
            @Override
            public void onProgressChanged(IpodSlider slider, int progress, boolean fromUser) {
                updateBrightnessLabel(progress);
                applyWindowBrightness(progress);
                if (fromUser) {
                    // Write continuously while dragging. Waiting for
                    // onStopTrackingTouch made the slider feel broken because
                    // the settings window uses its own brightness override.
                    setSystemBrightness(progress, false);
                }
            }

            @Override
            public void onStartTrackingTouch(IpodSlider slider) {
            }

            @Override
            public void onStopTrackingTouch(IpodSlider slider) {
                setSystemBrightness(slider.getProgress(), true);
            }
        });
        brightnessBlock.addView(brightnessBar, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(38)));
        content.addView(brightnessBlock);
        content.addView(divider());

        LinearLayout timeoutRow = new LinearLayout(this);
        timeoutRow.setOrientation(LinearLayout.HORIZONTAL);
        timeoutRow.setGravity(Gravity.CENTER_VERTICAL);
        timeoutRow.setMinimumHeight(dp(52));
        timeoutRow.setPadding(0, dp(14), 0, dp(14));
        timeoutRow.setBackgroundResource(R.drawable.row_bg);
        timeoutRow.setClickable(true);
        TextView timeoutTitle = text("Screen timeout", 17, TEXT, true);
        timeoutValue = text("", 13, SECONDARY, false);
        timeoutValue.setGravity(Gravity.END);
        timeoutRow.addView(timeoutTitle, new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        timeoutRow.addView(timeoutValue);
        timeoutRow.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                cycleTimeout();
            }
        });
        content.addView(timeoutRow);
        content.addView(divider());
        updateTimeoutLabel();

        content.addView(sectionLabel("SYSTEM"));

        batteryValue = text("", 13, SECONDARY, false);
        batteryValue.setGravity(Gravity.END);
        content.addView(infoRow("Battery", batteryValue));
        content.addView(divider());

        LinearLayout storageBlock = new LinearLayout(this);
        storageBlock.setOrientation(LinearLayout.VERTICAL);
        storageBlock.setPadding(0, dp(14), 0, dp(14));
        storageBlock.addView(text("Storage", 17, TEXT, true));
        storageValue = text("", 12, SECONDARY, false);
        storageValue.setPadding(0, dp(4), 0, 0);
        storageValue.setLineSpacing(dp(2), 1f);
        storageBlock.addView(storageValue);
        content.addView(storageBlock);
        content.addView(divider());

        if (!Settings.System.canWrite(this)) {
            TextView warn = text(
                    "Brightness and timeout need WRITE_SETTINGS. Grant with adb:\n"
                            + "appops set com.sundara.dapsettings WRITE_SETTINGS allow",
                    12, WARN, false);
            warn.setPadding(0, dp(14), 0, 0);
            content.addView(warn);
        }

        TextView footer = text("DAP Settings 1.0  \u00b7  no ads, no telemetry",
                10, 0xFF5A5E66, false);
        footer.setGravity(Gravity.CENTER_HORIZONTAL);
        footer.setPadding(0, dp(24), 0, dp(10));
        content.addView(footer);

        return page;
    }

    private LinearLayout toggleRow(String title, TextView subtitle, View toggle) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setMinimumHeight(dp(62));
        row.setPadding(0, dp(10), 0, dp(10));
        row.setBackgroundResource(R.drawable.row_bg);
        row.setClickable(true);

        LinearLayout labels = new LinearLayout(this);
        labels.setOrientation(LinearLayout.VERTICAL);
        labels.addView(text(title, 17, TEXT, true));
        if (subtitle != null) {
            labels.addView(subtitle);
        }

        row.addView(labels, new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(dp(46), dp(28));
        lp.leftMargin = dp(14);
        row.addView(toggle, lp);
        return row;
    }

    private LinearLayout infoRow(String title, TextView value) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setMinimumHeight(dp(52));
        row.setPadding(0, dp(14), 0, dp(14));
        row.addView(text(title, 17, TEXT, true), new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));
        row.addView(value, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));
        return row;
    }

    private void updateBrightnessLabel(int progress) {
        int percent = Math.round(progress * 100f / 255f);
        brightnessValue.setText(percent + "%");
    }

    private void refreshBrightness() {
        if (brightnessBar == null) {
            return;
        }
        try {
            int value = Settings.System.getInt(getContentResolver(),
                    Settings.System.SCREEN_BRIGHTNESS, 128);
            brightnessBar.setProgress(Math.max(1, Math.min(255, value)));
            updateBrightnessLabel(brightnessBar.getProgress());
        } catch (Exception ignored) {
        }
    }

    private void applyWindowBrightness(int progress) {
        try {
            WindowManager.LayoutParams lp = getWindow().getAttributes();
            lp.screenBrightness = Math.max(0.02f, progress / 255f);
            getWindow().setAttributes(lp);
        } catch (Exception ignored) {
        }
    }

    private void setSystemBrightness(int value, boolean announce) {
        try {
            Settings.System.putInt(getContentResolver(),
                    Settings.System.SCREEN_BRIGHTNESS_MODE,
                    Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL);
            Settings.System.putInt(getContentResolver(),
                    Settings.System.SCREEN_BRIGHTNESS, Math.max(1, Math.min(255, value)));
            if (announce) {
                toast("Brightness " + Math.round(value * 100f / 255f) + "%");
            }
        } catch (Exception e) {
            if (announce) {
                toast("WRITE_SETTINGS not granted");
            }
        }
    }

    private void updateTimeoutLabel() {
        if (timeoutValue == null) {
            return;
        }
        long current = 1800000L;
        try {
            current = Settings.System.getInt(getContentResolver(),
                    Settings.System.SCREEN_OFF_TIMEOUT, 1800000);
        } catch (Exception ignored) {
        }
        int best = 2;
        long bestDelta = Long.MAX_VALUE;
        for (int i = 0; i < TIMEOUTS.length; i++) {
            long delta = Math.abs(TIMEOUTS[i] - current);
            if (delta < bestDelta) {
                bestDelta = delta;
                best = i;
            }
        }
        timeoutValue.setText(TIMEOUT_LABELS[best]);
        timeoutValue.setTag(Integer.valueOf(best));
    }

    private void cycleTimeout() {
        int index = 2;
        Object tag = timeoutValue.getTag();
        if (tag instanceof Integer) {
            index = ((Integer) tag).intValue();
        }
        index = (index + 1) % TIMEOUTS.length;
        try {
            Settings.System.putInt(getContentResolver(),
                    Settings.System.SCREEN_OFF_TIMEOUT, (int) TIMEOUTS[index]);
            timeoutValue.setText(TIMEOUT_LABELS[index]);
            timeoutValue.setTag(Integer.valueOf(index));
            toast("Screen timeout: " + TIMEOUT_LABELS[index]);
        } catch (Exception e) {
            toast("WRITE_SETTINGS not granted");
        }
    }

    private void refreshAll() {
        refreshing = true;
        try {
            if (wifiSwitch != null) {
                wifiSwitch.setChecked(wifiManager != null && wifiManager.isWifiEnabled());
            }
            if (wifiSub != null) {
                wifiSub.setText(wifiStatusText());
            }
            if (btSwitch != null) {
                btSwitch.setChecked(bluetoothAdapter != null && bluetoothAdapter.isEnabled());
            }
            if (btSub != null) {
                btSub.setText(btStatusText());
            }
            if (storageValue != null) {
                storageValue.setText(storageText());
            }
        } finally {
            refreshing = false;
        }
    }

    private String wifiStatusText() {
        if (wifiManager == null) {
            return "Not available";
        }
        if (!wifiManager.isWifiEnabled()) {
            return "Off  \u00b7  tap to connect";
        }
        try {
            WifiInfo info = wifiManager.getConnectionInfo();
            String ssid = info == null ? null : info.getSSID();
            if (ssid != null && !ssid.contains("unknown")) {
                ssid = ssid.replace("\"", "");
                if (ssid.length() > 0 && !ssid.equals("0x")) {
                    return "Connected to " + ssid;
                }
            }
        } catch (Exception ignored) {
        }
        return "On  \u00b7  not connected";
    }

    private String btStatusText() {
        if (bluetoothAdapter == null) {
            return "Not available";
        }
        if (!bluetoothAdapter.isEnabled()) {
            return "Off  \u00b7  tap to pair";
        }
        try {
            Set<BluetoothDevice> bonded = bluetoothAdapter.getBondedDevices();
            int count = bonded == null ? 0 : bonded.size();
            return "On  \u00b7  " + count + " paired";
        } catch (Exception e) {
            return "On";
        }
    }

    private String storageText() {
        try {
            StatFs internal = new StatFs(Environment.getDataDirectory().getAbsolutePath());
            long internalFree = (long) internal.getAvailableBlocks() * internal.getBlockSize();
            String sd = "not mounted";
            File sdFile = new File("/storage/658C-1E0A");
            if (sdFile.exists()) {
                StatFs external = new StatFs(sdFile.getAbsolutePath());
                long sdFree = (long) external.getAvailableBlocks() * external.getBlockSize();
                sd = Formatter.formatFileSize(this, sdFree) + " free";
            }
            return Formatter.formatFileSize(this, internalFree) + " free  \u00b7  SD " + sd;
        } catch (Exception e) {
            return "";
        }
    }

    private void updateBattery(Intent intent) {
        if (intent == null) {
            return;
        }
        int level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
        int scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, 100);
        int status = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1);
        if (level < 0 || scale <= 0) {
            if (statusBattery != null) {
                statusBattery.setText("");
            }
            if (batteryValue != null) {
                batteryValue.setText("");
            }
            return;
        }
        int percent = Math.round(level * 100f / scale);
        boolean charging = status == BatteryManager.BATTERY_STATUS_CHARGING
                || status == BatteryManager.BATTERY_STATUS_FULL;
        if (statusBattery != null) {
            statusBattery.setText(percent + "%");
        }
        if (batteryValue != null) {
            batteryValue.setText(percent + "%"
                    + (charging ? "  \u00b7  charging" : "  \u00b7  on battery"));
        }
    }

    private void setWifiEnabled(boolean enabled) {
        if (wifiManager == null) {
            return;
        }
        try {
            wifiManager.setWifiEnabled(enabled);
            wifiSub.setText(enabled ? "Turning on..." : "Turning off...");
            new Handler().postDelayed(new Runnable() {
                @Override
                public void run() {
                    refreshAll();
                }
            }, 1600);
        } catch (Exception e) {
            toast("Could not change Wi-Fi");
            refreshAll();
        }
    }

    private void setBluetoothEnabled(boolean enabled) {
        if (bluetoothAdapter == null) {
            return;
        }
        try {
            if (enabled) {
                bluetoothAdapter.enable();
            } else {
                bluetoothAdapter.disable();
            }
            btSub.setText(enabled ? "Turning on..." : "Turning off...");
            new Handler().postDelayed(new Runnable() {
                @Override
                public void run() {
                    refreshAll();
                }
            }, 1200);
        } catch (Exception e) {
            toast("Could not change Bluetooth");
            refreshAll();
        }
    }

    private TextView dialogTitle(String title) {
        TextView v = text(title, 18, TEXT, true);
        v.setPadding(dp(24), dp(20), dp(24), dp(6));
        return v;
    }

    private void showWifiDialog() {
        if (wifiManager == null) {
            toast("Wi-Fi not available");
            return;
        }
        if (!wifiManager.isWifiEnabled()) {
            wifiManager.setWifiEnabled(true);
        }
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
                != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION
            }, REQ_LOCATION);
            toast("Allow location, then tap Wi-Fi again");
            return;
        }

        try {
            int mode = Settings.Secure.getInt(getContentResolver(), Settings.Secure.LOCATION_MODE);
            if (mode == Settings.Secure.LOCATION_MODE_OFF) {
                Settings.Secure.putInt(getContentResolver(),
                        Settings.Secure.LOCATION_MODE,
                        Settings.Secure.LOCATION_MODE_HIGH_ACCURACY);
            }
        } catch (Exception ignored) {
        }

        wifiNetworks.clear();
        wifiListAdapter = new ArrayAdapter<String>(this,
                android.R.layout.simple_list_item_1, new ArrayList<String>()) {
            @Override
            public View getView(int position, View convertView, ViewGroup parent) {
                TextView v = (TextView) super.getView(position, convertView, parent);
                v.setTextColor(TEXT);
                v.setTextSize(16);
                v.setTypeface(regularTypeface);
                v.setMinHeight(dp(52));
                v.setGravity(Gravity.CENTER_VERTICAL);
                v.setPadding(dp(20), dp(12), dp(20), dp(12));
                return v;
            }
        };

        AlertDialog.Builder builder = new AlertDialog.Builder(this, R.style.DapDialog);
        builder.setCustomTitle(dialogTitle("Wi-Fi Networks"));
        builder.setAdapter(wifiListAdapter, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {
                if (which >= 0 && which < wifiNetworks.size()) {
                    connectToWifi(wifiNetworks.get(which));
                }
            }
        });
        builder.setNegativeButton("Scan", new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {
                wifiManager.startScan();
                toast("Scanning for Wi-Fi...");
            }
        });
        builder.setPositiveButton("Close", null);
        wifiDialog = builder.create();
        wifiDialog.setOnDismissListener(new DialogInterface.OnDismissListener() {
            @Override
            public void onDismiss(DialogInterface dialog) {
                unregisterWifiScan();
            }
        });
        wifiDialog.setOnShowListener(new DialogInterface.OnShowListener() {
            @Override
            public void onShow(DialogInterface dialog) {
                styleDialog(wifiDialog);
                wifiDialog.getButton(AlertDialog.BUTTON_NEGATIVE)
                        .setOnClickListener(new View.OnClickListener() {
                            @Override
                            public void onClick(View v) {
                                wifiManager.startScan();
                                toast("Scanning for Wi-Fi...");
                            }
                        });
            }
        });
        wifiDialog.show();
        registerWifiScan();
        updateWifiList();
        wifiManager.startScan();
    }

    private void registerWifiScan() {
        unregisterWifiScan();
        wifiScanReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                updateWifiList();
            }
        };
        registerReceiver(wifiScanReceiver,
                new IntentFilter(WifiManager.SCAN_RESULTS_AVAILABLE_ACTION));
    }

    private void unregisterWifiScan() {
        if (wifiScanReceiver != null) {
            try {
                unregisterReceiver(wifiScanReceiver);
            } catch (Exception ignored) {
            }
            wifiScanReceiver = null;
        }
    }

    private void updateWifiList() {
        if (wifiListAdapter == null) {
            return;
        }
        List<ScanResult> results;
        try {
            results = wifiManager.getScanResults();
        } catch (Exception e) {
            toast("Wi-Fi scan failed");
            return;
        }
        Map<String, ScanResult> best = new LinkedHashMap<String, ScanResult>();
        for (int i = 0; i < results.size(); i++) {
            ScanResult r = results.get(i);
            if (r == null || r.SSID == null || r.SSID.length() == 0) {
                continue;
            }
            ScanResult previous = best.get(r.SSID);
            if (previous == null || r.level > previous.level) {
                best.put(r.SSID, r);
            }
        }
        wifiNetworks.clear();
        wifiNetworks.addAll(best.values());
        Collections.sort(wifiNetworks, new Comparator<ScanResult>() {
            @Override
            public int compare(ScanResult a, ScanResult b) {
                return b.level - a.level;
            }
        });
        wifiListAdapter.clear();
        for (int i = 0; i < wifiNetworks.size(); i++) {
            ScanResult r = wifiNetworks.get(i);
            String security = r.capabilities != null
                    && (r.capabilities.contains("WPA") || r.capabilities.contains("WEP"))
                    ? "  [secured]" : "";
            wifiListAdapter.add(r.SSID + security + "   " + signalLabel(r.level));
        }
        wifiListAdapter.notifyDataSetChanged();
        if (wifiNetworks.isEmpty()) {
            wifiListAdapter.add("No networks found \u2014 tap Scan");
        }
    }

    private String signalLabel(int level) {
        if (level >= -55) {
            return "||||";
        }
        if (level >= -70) {
            return "|||";
        }
        if (level >= -85) {
            return "||";
        }
        return "|";
    }

    private WifiConfiguration findConfigured(String ssid) {
        try {
            List<WifiConfiguration> configured = wifiManager.getConfiguredNetworks();
            if (configured == null) {
                return null;
            }
            for (int i = 0; i < configured.size(); i++) {
                WifiConfiguration c = configured.get(i);
                if (c != null && c.SSID != null && c.SSID.equals("\"" + ssid + "\"")) {
                    return c;
                }
            }
        } catch (Exception ignored) {
        }
        return null;
    }

    private void connectToWifi(ScanResult result) {
        final String ssid = result.SSID;
        WifiConfiguration existing = findConfigured(ssid);
        if (existing != null) {
            try {
                wifiManager.enableNetwork(existing.networkId, true);
                wifiManager.reconnect();
                toast("Connecting to " + ssid);
                if (wifiDialog != null) {
                    wifiDialog.dismiss();
                }
            } catch (Exception e) {
                toast("Could not connect");
            }
            return;
        }
        boolean secured = result.capabilities != null
                && (result.capabilities.contains("WPA")
                || result.capabilities.contains("WEP")
                || result.capabilities.contains("PSK"));
        if (secured) {
            showPasswordDialog(ssid, result.capabilities);
            return;
        }
        WifiConfiguration config = new WifiConfiguration();
        config.SSID = "\"" + ssid + "\"";
        config.allowedKeyManagement.set(WifiConfiguration.KeyMgmt.NONE);
        try {
            int id = wifiManager.addNetwork(config);
            if (id >= 0) {
                wifiManager.enableNetwork(id, true);
                wifiManager.reconnect();
                toast("Connecting to " + ssid);
                if (wifiDialog != null) {
                    wifiDialog.dismiss();
                }
            } else {
                toast("Could not add network");
            }
        } catch (Exception e) {
            toast("Could not connect");
        }
    }

    private void showPasswordDialog(final String ssid, final String capabilities) {
        final EditText input = new EditText(this);
        input.setInputType(InputType.TYPE_CLASS_TEXT
                | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        input.setHint("Password");
        input.setTextColor(TEXT);
        input.setHintTextColor(SECONDARY);
        input.setTypeface(regularTypeface);
        input.setSingleLine(true);
        input.setPadding(dp(20), dp(10), dp(20), dp(10));

        final AlertDialog passwordDialog = new AlertDialog.Builder(this, R.style.DapDialog)
                .setCustomTitle(dialogTitle(ssid))
                .setView(input)
                .setPositiveButton("Connect", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface dialog, int which) {
                        connectWithPassword(ssid, capabilities, input.getText().toString());
                    }
                })
                .setNegativeButton("Cancel", null)
                .create();
        passwordDialog.setOnShowListener(new DialogInterface.OnShowListener() {
            @Override
            public void onShow(DialogInterface dialog) {
                styleDialog(passwordDialog);
            }
        });
        passwordDialog.show();
    }

    private void connectWithPassword(String ssid, String capabilities, String password) {
        if (password.length() == 0) {
            toast("Password required");
            return;
        }
        WifiConfiguration config = new WifiConfiguration();
        config.SSID = "\"" + ssid + "\"";
        if (capabilities != null && capabilities.contains("WEP")) {
            config.wepKeys[0] = "\"" + password + "\"";
            config.wepTxKeyIndex = 0;
            config.allowedKeyManagement.set(WifiConfiguration.KeyMgmt.NONE);
            config.allowedGroupCiphers.set(WifiConfiguration.GroupCipher.WEP40);
        } else {
            config.preSharedKey = "\"" + password + "\"";
            config.allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA_PSK);
        }
        try {
            int id = wifiManager.addNetwork(config);
            if (id < 0) {
                toast("Could not add network");
                return;
            }
            wifiManager.disconnect();
            wifiManager.enableNetwork(id, true);
            wifiManager.reconnect();
            toast("Connecting to " + ssid);
            if (wifiDialog != null) {
                wifiDialog.dismiss();
            }
        } catch (Exception e) {
            toast("Could not connect");
        }
    }

    private void showBluetoothDialog() {
        if (bluetoothAdapter == null) {
            toast("Bluetooth not available");
            return;
        }
        if (!bluetoothAdapter.isEnabled()) {
            bluetoothAdapter.enable();
            toast("Turning Bluetooth on...");
            new Handler().postDelayed(new Runnable() {
                @Override
                public void run() {
                    if (!isFinishing() && bluetoothAdapter.isEnabled()) {
                        showBluetoothDialog();
                    }
                }
            }, 1800);
            return;
        }
        btDevices.clear();
        try {
            Set<BluetoothDevice> bonded = bluetoothAdapter.getBondedDevices();
            if (bonded != null) {
                btDevices.addAll(bonded);
            }
        } catch (Exception ignored) {
        }
        btListAdapter = new ArrayAdapter<String>(this,
                android.R.layout.simple_list_item_1, new ArrayList<String>()) {
            @Override
            public View getView(int position, View convertView, ViewGroup parent) {
                TextView v = (TextView) super.getView(position, convertView, parent);
                v.setTextColor(TEXT);
                v.setTextSize(16);
                v.setTypeface(regularTypeface);
                v.setMinHeight(dp(52));
                v.setGravity(Gravity.CENTER_VERTICAL);
                v.setPadding(dp(20), dp(12), dp(20), dp(12));
                return v;
            }
        };
        rebuildBtList();

        AlertDialog.Builder builder = new AlertDialog.Builder(this, R.style.DapDialog);
        builder.setCustomTitle(dialogTitle("Bluetooth Devices"));
        builder.setAdapter(btListAdapter, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {
                if (which >= 0 && which < btDevices.size()) {
                    selectBtDevice(btDevices.get(which));
                }
            }
        });
        builder.setNegativeButton("Scan", new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialog, int which) {
                startBtDiscovery();
            }
        });
        builder.setPositiveButton("Close", null);
        btDialog = builder.create();
        btDialog.setOnDismissListener(new DialogInterface.OnDismissListener() {
            @Override
            public void onDismiss(DialogInterface dialog) {
                unregisterBt();
            }
        });
        btDialog.setOnShowListener(new DialogInterface.OnShowListener() {
            @Override
            public void onShow(DialogInterface dialog) {
                styleDialog(btDialog);
                btDialog.getButton(AlertDialog.BUTTON_NEGATIVE)
                        .setOnClickListener(new View.OnClickListener() {
                            @Override
                            public void onClick(View v) {
                                startBtDiscovery();
                            }
                        });
            }
        });
        btDialog.show();
        registerBt();
    }

    private void rebuildBtList() {
        if (btListAdapter == null) {
            return;
        }
        btListAdapter.clear();
        for (int i = 0; i < btDevices.size(); i++) {
            BluetoothDevice d = btDevices.get(i);
            String name = null;
            try {
                name = d.getName();
            } catch (Exception ignored) {
            }
            if (name == null || name.length() == 0) {
                name = d.getAddress();
            }
            String state = d.getBondState() == BluetoothDevice.BOND_BONDED
                    ? "  [paired]" : "  [tap to pair]";
            btListAdapter.add(name + state);
        }
        if (btDevices.isEmpty()) {
            btListAdapter.add("No devices yet \u2014 tap Scan");
        }
        btListAdapter.notifyDataSetChanged();
    }

    private void registerBt() {
        unregisterBt();
        btReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                String action = intent.getAction();
                if (BluetoothDevice.ACTION_FOUND.equals(action)) {
                    BluetoothDevice device = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);
                    if (device != null && !btDevices.contains(device)) {
                        btDevices.add(device);
                        rebuildBtList();
                    }
                } else if (BluetoothAdapter.ACTION_DISCOVERY_FINISHED.equals(action)) {
                    scanningBt = false;
                    toast("Bluetooth scan finished");
                }
            }
        };
        IntentFilter filter = new IntentFilter();
        filter.addAction(BluetoothDevice.ACTION_FOUND);
        filter.addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED);
        registerReceiver(btReceiver, filter);
    }

    private void unregisterBt() {
        if (bluetoothAdapter != null) {
            try {
                if (bluetoothAdapter.isDiscovering()) {
                    bluetoothAdapter.cancelDiscovery();
                }
            } catch (Exception ignored) {
            }
        }
        if (btReceiver != null) {
            try {
                unregisterReceiver(btReceiver);
            } catch (Exception ignored) {
            }
            btReceiver = null;
        }
    }

    private void startBtDiscovery() {
        if (bluetoothAdapter == null) {
            return;
        }
        try {
            if (bluetoothAdapter.isDiscovering()) {
                bluetoothAdapter.cancelDiscovery();
            }
            boolean started = bluetoothAdapter.startDiscovery();
            toast(started ? "Scanning for Bluetooth devices..." : "Could not start scan");
        } catch (Exception e) {
            toast("Could not start scan");
        }
    }

    private void selectBtDevice(BluetoothDevice device) {
        try {
            if (device.getBondState() == BluetoothDevice.BOND_BONDED) {
                toast("Paired: " + safeName(device)
                        + " \u2014 audio connects automatically");
            } else {
                boolean started = device.createBond();
                toast(started ? "Pairing with " + safeName(device) : "Could not pair");
            }
        } catch (Exception e) {
            toast("Could not pair");
        }
    }

    private String safeName(BluetoothDevice device) {
        try {
            String name = device.getName();
            if (name != null && name.length() > 0) {
                return name;
            }
            return device.getAddress();
        } catch (Exception e) {
            return "device";
        }
    }

    private void styleDialog(AlertDialog dialog) {
        if (dialog == null) {
            return;
        }
        try {
            Window window = dialog.getWindow();
            if (window != null) {
                window.setDimAmount(0.55f);
                window.setLayout(dp(318), WindowManager.LayoutParams.WRAP_CONTENT);
            }
            TextView title = (TextView) dialog.findViewById(android.R.id.title);
            if (title != null) {
                title.setTypeface(boldTypeface);
                title.setTextColor(TEXT);
                title.setTextSize(18);
            }
            styleDialogButton(dialog.getButton(AlertDialog.BUTTON_POSITIVE));
            styleDialogButton(dialog.getButton(AlertDialog.BUTTON_NEGATIVE));
            styleDialogButton(dialog.getButton(AlertDialog.BUTTON_NEUTRAL));
        } catch (Exception ignored) {
        }
    }

    private void styleDialogButton(Button button) {
        if (button == null) {
            return;
        }
        button.setAllCaps(false);
        button.setTypeface(regularTypeface);
        button.setTextSize(15);
        button.setTextColor(ACCENT);
    }

    private void openPlayer() {
        // DAP Settings is a separate task launched above the player. Finishing
        // is enough to reveal the existing player task; launching a fresh HOME
        // intent here created a second player task and a brief launcher flash.
        finish();
    }

    public static Intent playerIntent() {
        Intent intent = new Intent(Intent.ACTION_MAIN);
        intent.addCategory(Intent.CATEGORY_HOME);
        intent.setPackage(PLAYER_PACKAGE);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
        return intent;
    }

    private void toast(String message) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQ_LOCATION
                && grantResults.length > 0
                && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            toast("Location granted \u2014 tap Wi-Fi to scan");
        }
    }

    @Override
    public void onBackPressed() {
        openPlayer();
    }

    /**
     * A fully custom slider. The stock SeekBar kept its track and thumb frozen
     * on this Android build while the brightness value changed, so this view
     * paints every part itself and invalidates on each touch move. The track
     * and fill are true pills; the fill has a rounded cap at the thumb.
     */
    private interface OnSliderChangeListener {
        void onProgressChanged(IpodSlider slider, int progress, boolean fromUser);

        void onStartTrackingTouch(IpodSlider slider);

        void onStopTrackingTouch(IpodSlider slider);
    }

    private class IpodSlider extends View {
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final RectF rect = new RectF();
        private final float trackHeight = dp(6);
        private final float thumbRadius = dp(10);
        private int max = 255;
        private int progress = 0;
        private float trackLeft;
        private float trackRight;
        private float centerY;
        private Shader fillShader;
        private OnSliderChangeListener listener;
        private boolean dragging = false;

        IpodSlider(Context context) {
            super(context);
            setFocusable(true);
            setClickable(true);
            setContentDescription("Brightness");
        }

        void setMax(int value) {
            max = Math.max(1, value);
        }

        int getMax() {
            return max;
        }

        int getProgress() {
            return progress;
        }

        void setProgress(int value) {
            setProgressInternal(value, false);
        }

        void setOnSliderChangeListener(OnSliderChangeListener value) {
            listener = value;
        }

        private void setProgressInternal(int value, boolean fromUser) {
            int clamped = Math.max(0, Math.min(max, value));
            if (progress == clamped) {
                if (fromUser) {
                    invalidate();
                }
                return;
            }
            progress = clamped;
            invalidate();
            if (listener != null) {
                listener.onProgressChanged(this, progress, fromUser);
            }
        }

        @Override
        protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
            int width = MeasureSpec.getSize(widthMeasureSpec);
            int height = (int) (thumbRadius * 2 + dp(18));
            setMeasuredDimension(
                    resolveSize(width, widthMeasureSpec),
                    resolveSize(height, heightMeasureSpec));
        }

        @Override
        protected void onSizeChanged(int w, int h, int oldw, int oldh) {
            super.onSizeChanged(w, h, oldw, oldh);
            trackLeft = thumbRadius + dp(1);
            trackRight = w - thumbRadius - dp(1);
            centerY = h / 2f;
            fillShader = new LinearGradient(
                    trackLeft, 0, trackRight, 0,
                    0xFF2A6DA8, 0xFF2E8BE0, Shader.TileMode.CLAMP);
        }

        @Override
        protected void onDraw(Canvas canvas) {
            float half = trackHeight / 2f;
            float thumbX = trackLeft
                    + (trackRight - trackLeft) * progress / (float) max;

            paint.setStyle(Paint.Style.FILL);
            paint.setShader(null);
            paint.setColor(0xFF2B2F36);
            rect.set(trackLeft, centerY - half, trackRight, centerY + half);
            canvas.drawRoundRect(rect, half, half, paint);

            if (thumbX > trackLeft) {
                paint.setShader(fillShader);
                rect.set(trackLeft, centerY - half, thumbX, centerY + half);
                canvas.drawRoundRect(rect, half, half, paint);
                paint.setShader(null);
            }

            paint.setStyle(Paint.Style.FILL);
            paint.setColor(0xFFF5F7FA);
            canvas.drawCircle(thumbX, centerY, thumbRadius, paint);
            paint.setStyle(Paint.Style.STROKE);
            paint.setStrokeWidth(dp(1));
            paint.setColor(0xFFB9C0C9);
            canvas.drawCircle(thumbX, centerY, thumbRadius - dp(1) * 0.5f, paint);
        }

        private int progressForX(float x) {
            if (trackRight <= trackLeft) {
                return progress;
            }
            float ratio = (x - trackLeft) / (trackRight - trackLeft);
            ratio = Math.max(0f, Math.min(1f, ratio));
            return Math.round(ratio * max);
        }

        @Override
        public boolean onTouchEvent(MotionEvent event) {
            if (!isEnabled()) {
                return false;
            }
            switch (event.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    dragging = true;
                    setPressed(true);
                    if (getParent() != null) {
                        getParent().requestDisallowInterceptTouchEvent(true);
                    }
                    if (listener != null) {
                        listener.onStartTrackingTouch(this);
                    }
                    setProgressInternal(progressForX(event.getX()), true);
                    return true;
                case MotionEvent.ACTION_MOVE:
                    if (dragging) {
                        setProgressInternal(progressForX(event.getX()), true);
                    }
                    return true;
                case MotionEvent.ACTION_UP:
                    if (dragging) {
                        setProgressInternal(progressForX(event.getX()), true);
                        dragging = false;
                        setPressed(false);
                        if (getParent() != null) {
                            getParent().requestDisallowInterceptTouchEvent(false);
                        }
                        if (listener != null) {
                            listener.onStopTrackingTouch(this);
                        }
                        performClick();
                    }
                    return true;
                case MotionEvent.ACTION_CANCEL:
                    if (dragging) {
                        dragging = false;
                        setPressed(false);
                        if (getParent() != null) {
                            getParent().requestDisallowInterceptTouchEvent(false);
                        }
                        if (listener != null) {
                            listener.onStopTrackingTouch(this);
                        }
                    }
                    return true;
                default:
                    return super.onTouchEvent(event);
            }
        }

        @Override
        public boolean performClick() {
            super.performClick();
            return true;
        }
    }

    /**
     * A small iOS-style switch drawn in the same graphite/blue palette as the
     * player. It replaces the Material switch, which immediately made the
     * settings page feel like a stock Android screen.
     */
    private interface OnCheckedChangeListener {
        void onCheckedChanged(IpodSwitch buttonView, boolean isChecked);
    }

    private class IpodSwitch extends View {
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final RectF track = new RectF();
        private boolean checked = false;
        private OnCheckedChangeListener listener;

        IpodSwitch(Context context) {
            super(context);
            setClickable(true);
            setFocusable(true);
            setContentDescription("Off");
        }

        void setChecked(boolean value) {
            if (checked == value) {
                return;
            }
            checked = value;
            setContentDescription(value ? "On" : "Off");
            invalidate();
        }

        boolean isChecked() {
            return checked;
        }

        void setOnCheckedChangeListener(OnCheckedChangeListener value) {
            listener = value;
        }

        @Override
        protected void onDraw(Canvas canvas) {
            float w = getWidth();
            float h = getHeight();
            float inset = dp(1);
            float radius = h / 2f;

            paint.setStyle(Paint.Style.FILL);
            paint.setColor(checked ? ACCENT : 0xFF3A3F46);
            track.set(inset, inset, w - inset, h - inset);
            canvas.drawRoundRect(track, radius, radius, paint);

            if (!checked) {
                paint.setStyle(Paint.Style.STROKE);
                paint.setStrokeWidth(dp(1));
                paint.setColor(0xFF5A6068);
                canvas.drawRoundRect(track, radius, radius, paint);
            }

            float thumbRadius = h / 2f - dp(3);
            float thumbX = checked
                    ? w - thumbRadius - dp(3)
                    : thumbRadius + dp(3);
            paint.setStyle(Paint.Style.FILL);
            paint.setColor(0xFFF5F7FA);
            canvas.drawCircle(thumbX, h / 2f, thumbRadius, paint);
        }

        @Override
        public boolean onTouchEvent(MotionEvent event) {
            if (!isEnabled()) {
                return false;
            }
            int action = event.getAction();
            if (action == MotionEvent.ACTION_DOWN) {
                setPressed(true);
                return true;
            }
            if (action == MotionEvent.ACTION_CANCEL) {
                setPressed(false);
                return true;
            }
            if (action == MotionEvent.ACTION_UP) {
                setPressed(false);
                if (event.getX() >= 0 && event.getX() <= getWidth()) {
                    checked = !checked;
                    setContentDescription(checked ? "On" : "Off");
                    invalidate();
                    if (listener != null) {
                        listener.onCheckedChanged(this, checked);
                    }
                    performClick();
                }
                return true;
            }
            return super.onTouchEvent(event);
        }

        @Override
        public boolean performClick() {
            super.performClick();
            return true;
        }
    }
}
