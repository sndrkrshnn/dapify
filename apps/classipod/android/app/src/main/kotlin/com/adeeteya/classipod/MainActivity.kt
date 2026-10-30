package com.adeeteya.classipod

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.KeyEvent
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.roundToInt

/**
 * The player is the HOME app, so it must keep ownership of Back and the
 * volume keys:
 *
 * - Back is forwarded to Flutter and behaves like MENU. Letting the activity
 *   finish would make Android relaunch the HOME app immediately (the visible
 *   "flicker").
 * - Volume keys are forwarded to Flutter so the app-volume mode and our own
 *   volume HUD stay in sync. Both the down and up events are consumed so the
 *   system volume is not changed twice.
 * - Screen on/off is forwarded so Flutter can show the album-art lock panel.
 *
 * Extending AudioServiceActivity is required: audio_service uses a cached
 * FlutterEngine, and a plain FlutterActivity would start a second engine.
 */
class MainActivity : AudioServiceActivity() {

    private lateinit var systemChannel: MethodChannel
    private lateinit var hapticsChannel: MethodChannel
    private var vibrator: Vibrator? = null
    private var screenReceiver: BroadcastReceiver? = null
    private var screenSink: EventChannel.EventSink? = null
    private var powerReceiver: BroadcastReceiver? = null
    private var powerSink: EventChannel.EventSink? = null
    private var lastPlugged: Boolean? = null
    private var lastBatteryLevel: Int? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        systemChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sundara.classipod/system"
        )
        systemChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "openDapSettings" -> {
                    try {
                        val intent = Intent().apply {
                            component = ComponentName(
                                "com.sundara.dapsettings",
                                "com.sundara.dapsettings.SettingsActivity"
                            )
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("settings", e.message, null)
                    }
                }
                "setKeepScreenOn" -> {
                    setKeepScreenOn(call.arguments as? Boolean ?: false)
                    result.success(true)
                }
                "setScreenDim" -> {
                    setScreenDim(call.arguments as? Boolean ?: false)
                    result.success(true)
                }
                "batteryLevel" -> {
                    result.success(readBatteryLevelPercentage())
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sundara.classipod/power"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                powerSink = events
                registerPowerReceiver()
                emitPowerState(force = true)
            }

            override fun onCancel(arguments: Any?) {
                unregisterPowerReceiver()
                powerSink = null
                lastPlugged = null
                lastBatteryLevel = null
            }
        })

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sundara.classipod/screen"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                screenSink = events
                registerScreenReceiver()
            }

            override fun onCancel(arguments: Any?) {
                unregisterScreenReceiver()
                screenSink = null
            }
        })

        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        hapticsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.sundara.classipod/haptics"
        )
        hapticsChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "tap" -> {
                    playHaptic(durationMs = 16L, amplitude = 100)
                    result.success(true)
                }
                "detent" -> {
                    // 14 ms is just above the ERM spin-up threshold on this
                    // phone, giving a soft single "thud" without the
                    // motor staying excited.  Amplitude 55 keeps it muted.
                    playHaptic(durationMs = 14L, amplitude = 55)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Reads the battery percentage from the sticky ACTION_BATTERY_CHANGED
     * broadcast — the same source used by the system settings and
     * `dumpsys battery`.
     *
     * battery_plus reads BatteryManager.BATTERY_PROPERTY_CAPACITY, which has
     * been observed returning a frozen value on this Android 7 build (the
     * lock screen stayed at 97 % while the real level was 82 %). Reading the
     * sticky broadcast from /sys/class/power_supply keeps the player in sync
     * with the rest of the system.
     */
    private fun readBatteryLevelPercentage(): Int? = batteryLevelFrom(
        registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
    )

    private fun batteryLevelFrom(intent: Intent?): Int? {
        if (intent == null) return null
        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        if (level < 0 || scale <= 0) return null
        return (level * 100.0 / scale).roundToInt()
    }

    /**
     * A single short pulse. Android 7 cannot set per-call amplitude, so the
     * QPNP driver voltage is tuned globally by the DAP boot script; newer
     * devices use the amplitude argument to keep the same muted character.
     */
    private fun playHaptic(durationMs: Long, amplitude: Int) {
        val device = vibrator ?: return
        if (!device.hasVibrator()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            device.vibrate(VibrationEffect.createOneShot(durationMs, amplitude))
        } else {
            @Suppress("DEPRECATION")
            device.vibrate(durationMs)
        }
    }

    private fun registerScreenReceiver() {
        if (screenReceiver != null) return
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        screenReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    Intent.ACTION_SCREEN_ON -> screenSink?.success("screen_on")
                    Intent.ACTION_SCREEN_OFF -> screenSink?.success("screen_off")
                }
            }
        }
        val receiver = screenReceiver ?: return
        registerReceiver(receiver, filter)
    }

    private fun unregisterScreenReceiver() {
        val receiver = screenReceiver ?: return
        try {
            unregisterReceiver(receiver)
        } catch (_: Exception) {
        }
        screenReceiver = null
    }

    /**
     * AOD support: while the player is resumed and external power is
     * connected, the lock screen can be shown at the lowest window brightness
     * instead of letting the display sleep. The flag keeps the panel alive;
     * the brightness override only applies while [setScreenDim] is on, so
     * normal use is not affected.
     */
    private fun setKeepScreenOn(enabled: Boolean) {
        val flag = WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        if (enabled) {
            window.addFlags(flag)
        } else {
            window.clearFlags(flag)
        }
    }

    private fun setScreenDim(enabled: Boolean) {
        val target =
            if (enabled) 0.01f else WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
        val attributes = window.attributes
        if (attributes.screenBrightness != target) {
            attributes.screenBrightness = target
            window.attributes = attributes
        }
    }

    private fun registerPowerReceiver() {
        if (powerReceiver != null) return
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_POWER_CONNECTED)
            addAction(Intent.ACTION_POWER_DISCONNECTED)
            addAction(Intent.ACTION_BATTERY_CHANGED)
        }
        powerReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    Intent.ACTION_POWER_CONNECTED -> emitPowerState(true)
                    Intent.ACTION_POWER_DISCONNECTED -> emitPowerState(false)
                    else -> emitPowerState()
                }
            }
        }
        val receiver = powerReceiver ?: return
        registerReceiver(receiver, filter)
    }

    private fun unregisterPowerReceiver() {
        val receiver = powerReceiver ?: return
        try {
            unregisterReceiver(receiver)
        } catch (_: Exception) {
        }
        powerReceiver = null
    }

    private fun emitPowerState(force: Boolean = false) {
        val sink = powerSink ?: return
        val battery = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val plugged =
            (battery?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0) != 0
        val level = batteryLevelFrom(battery)
        val pluggedChanged = lastPlugged != plugged
        val levelChanged = level != null && level != lastBatteryLevel
        if (!force && !pluggedChanged && !levelChanged) return
        lastPlugged = plugged
        lastBatteryLevel = level
        // A map keeps the plug state and the live battery level in one event;
        // Flutter uses the level so the status bar and lock screen never show
        // a stale percentage.
        sink.success(
            mapOf(
                "plugged" to plugged,
                "level" to level,
            )
        )
    }

    override fun onBackPressed() {
        if (::systemChannel.isInitialized) {
            systemChannel.invokeMethod("back", null)
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val keyCode = event.keyCode
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
            keyCode == KeyEvent.KEYCODE_VOLUME_DOWN
        ) {
            if (event.action == KeyEvent.ACTION_DOWN &&
                ::systemChannel.isInitialized
            ) {
                systemChannel.invokeMethod(
                    "volumeKey",
                    if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) 1 else -1
                )
            }
            // Consume KEY_UP as well, otherwise Android applies the volume
            // change a second time after Flutter has handled it.
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    override fun onDestroy() {
        unregisterScreenReceiver()
        unregisterPowerReceiver()
        setKeepScreenOn(false)
        setScreenDim(false)
        super.onDestroy()
    }
}
