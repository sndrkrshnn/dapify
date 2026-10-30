# DAPify — compatibility

| Device | Codename | ROM | Root | Backend | Status |
| --- | --- | --- | --- | --- | --- |
| Xiaomi Redmi Note 3 | `kenzo` | LineageOS 14.1 (A 7.1.2), Radon V6.3 | CM root | system (`/system`) | **verified** |
| Xiaomi POCO F1 | `beryllium` | LineageOS 16.0+ (A 9/10+) | Magisk | magisk | **unverified** (best-effort) |

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

## Audio policy (both devices)

The audio module patches `audio_policy_configuration.xml` to advertise 44.1 kHz
on the primary/raw/deep-buffer paths and the full 16/24-bit hi-res set
(44.1/48/88.2/96/176.4/192 kHz) on the wired device ports. The same
`modules/audio/patch_audio_policy.py` is used for every device; the profile
points at the generated file.

| Device | Stock path | Patched file | Status |
| --- | --- | --- | --- |
| `kenzo` | `/system/etc/audio_policy_configuration.xml` | `devices/kenzo/audio/audio_policy_configuration.xml` (md5 `00ec45d1…`) | **verified** (matches the live device) |
| `beryllium` | `/vendor/etc/audio_policy_configuration.xml` | `devices/beryllium/audio/audio_policy_configuration.xml` (generated from the sdm845-common stock) | **patch verified clean; on-device listen-test pending** |

Note: ClassiPod/just_audio plays 24-bit FLAC through the 16-bit/48 kHz primary
path on both devices. The 24-bit/192 kHz `direct_pcm` path the patch configures
is what a direct-output player (Poweramp/Neutron/UAPP) uses for bit-perfect
wired playback.

## beryllium (Xiaomi POCO F1) — unverified

Written from the LineageOS `beryllium` + `sdm845-common` trees (lineage-16.0).
Confirmed from the tree: arm64 (SDM845), single physical HOME button
(`keylayout/gpio-keys.kl`, key 102) + rear Goodix fingerprint (no capacitive nav
to remap), standard `com.android.systemui`, read-only `/system` → **Magisk
required**. The audio patch is generated from the real stock `/vendor/etc` file
and patches cleanly.

**Verify on a real device before relying on it** (full list in
`devices/beryllium/README.md`):

- vibrator node + type: `ls /sys/class/timed_output/vibrator/`
- battery charge-suspend node: `ls /sys/class/power_supply/battery/`
- audio policy path (`/vendor/etc` vs `/system/etc`): `ls -l
  /vendor/etc/audio_policy_configuration.xml /system/etc/audio_policy_configuration.xml`

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
