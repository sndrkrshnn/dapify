# beryllium (Xiaomi POCO F1)

**Status: unverified / best-effort port.** This profile was written from the
LineageOS `beryllium` + `sdm845-common` device trees (lineage-16.0) and public
hardware notes. It has **not** been run on a real POCO F1. Treat it as a
starting point and verify the `(VERIFY)` items in `device.conf` on-device before
trusting it.

## What is confirmed from the device tree

- **SoC / ABI**: Snapdragon 845 (SDM845), **arm64** — the arm64 player APK is fine.
- **Key input**: no capacitive nav keys. A single physical **HOME** button on
  the bottom bezel (`keylayout/gpio-keys.kl`, `key 102 → HOME`) plus a **rear
  Goodix** fingerprint sensor. Nothing to remap for the DAP model, so no
  keylayout is shipped.
- **SystemUI**: standard `com.android.systemui`.
- **System partition**: system-as-root + dm-verity, `/system` mounted read-only
  → the **Magisk backend is required** (the profile sets
  `DAP_ROOT_BACKEND=magisk`).
- **Audio**: 3.5 mm TRRS jack present (SLIMBUS_6 headphones/line/ANC backends).
  The stock `audio_policy_configuration.xml` (inherited from `sdm845-common`)
  lives in **`/vendor/etc/`** and its wired device ports advertise only
  16-bit/48 kHz; the hi-res profiles exist only on the `direct_pcm` mix port.
  The shipped patch adds 44.1 kHz to the primary/raw/deep-buffer paths and the
  full 16/24-bit hi-res set to the wired device ports.

## What must be verified on a real POCO F1

Run these from the host against a rooted device and adjust `device.conf` if the
values differ:

```sh
# vibrator node + type (ERM vs LRA)
adb shell 'ls /sys/class/timed_output/vibrator/'
adb shell su -c 'sh -c "cat /sys/class/timed_output/vibrator/vtg_level 2>/dev/null; cat /sys/class/timed_output/vibrator/amplitude 2>/dev/null"'

# battery charge-suspend node (must be the battery-side vote)
adb shell 'ls /sys/class/power_supply/battery/'

# which audio policy file actually exists (system vs vendor)
adb shell 'ls -l /vendor/etc/audio_policy_configuration.xml /system/etc/audio_policy_configuration.xml 2>&1'
```

Then `./install.sh doctor --device beryllium`, fix any FAILs, and
`./install.sh install --device beryllium`. See `docs/porting.md`.

## Notes

- ClassiPod/just_audio plays 24-bit FLAC through the 16-bit/48 kHz primary path.
  The 24-bit/192 kHz `direct_pcm` path the patch configures is for direct-output
  players (Poweramp/Neutron/UAPP).
- If you want the physical HOME button to be play/pause, copy
  `keylayout/gpio-keys.kl` into `devices/beryllium/keylayout/`, change only the
  `key 102` line to `MEDIA_PLAY_PAUSE`, and set `DAP_KEYLAYOUT_SOURCE`/
  `DAP_KEYLAYOUT_TARGET`. Verify on-device first.
