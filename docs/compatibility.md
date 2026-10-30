# DAPify — compatibility

| Device | Codename | ROM | Root | Backend | Status |
| --- | --- | --- | --- | --- | --- |
| Xiaomi Redmi Note 3 | `kenzo` | LineageOS 14.1 (A 7.1.2), Radon V6.3 | CM root | system (`/system`) | **verified** |

## Verified values (kenzo)

| Item | Value |
| --- | --- |
| Player | `com.sundara.classipod` / `com.adeeteya.classipod.MainActivity`, v2.1.0+27 |
| Settings | `com.sundara.dapsettings` / `.SettingsActivity` |
| Keylayout | `Atmel_maXTouch_Touchscreen.kl` (center=172 play/pause, left=139 inert, right=158 back) |
| Vibrator node | `/sys/devices/virtual/timed_output/vibrator/vtg_level` |
| Haptics | 2800 mV default; wheel detent 14 ms, button tap 16 ms, 35 ms detent gap |
| Charge node | `/sys/class/power_supply/battery/battery_charging_enabled` |
| Charge thresholds | suspend 100 %, resume 90 % (or on unplug), 15 s poll |
| Init domain | `u:r:qti_init_shell:s0` |
| ADB serial | `45abfcf1` |

## Known limitations (kenzo)

- No power menu, volume panel, status bar, notification shade or navigation
  bar while SystemUI is disabled. Long-pressing power does nothing. Use ADB.
- The keyguard is gone, not merely bypassed.
- Wi-Fi scanning requires location mode on (`settings put secure location_mode
  3`) — an Android 7 requirement, set once at install.
- Bluetooth pairing uses the stock `com.android.bluetooth` dialog (not
  SystemUI), so it still appears.
- ClassiPod/just_audio plays 24-bit FLAC through the 16-bit/48 kHz primary
  path. A 24-bit/192 kHz `direct_pcm` audio-policy path is configured but the
  player does not use it.
- The three capacitive-key backlights share a single `button-backlight` channel
  (`max_brightness=40`); there is no per-key software control. All three can be
  turned off with `adb shell 'settings --cm put secure button_brightness 0'`
  (restore with `40`); only physical covering isolates the left LED.

## Adding a device

See [porting.md](porting.md). Add a row to the table above and a "verified
values" block for the new codename.
