# DAPify — troubleshooting

Run `./install.sh doctor --device <codename>` first; it points at most issues
directly. Then check the specific area below.

## Player / home

| Symptom | Cause | Fix |
| --- | --- | --- |
| Launcher chooser instead of player on boot/Home | Replacing an APK clears the preferred-home flag | `./install.sh install` re-sets it; or `adb shell cmd package set-home-activity --user 0 com.sundara.classipod/com.adeeteya.classipod.MainActivity` |
| Player crashes on launch | Corrupt or mismatched-signature APK | Reinstall the APK signed with your current keystore; `adb logcat -d -s AndroidRuntime` for the stack |
| Settings app won't open | `WRITE_SETTINGS`/`SYSTEM_ALERT_WINDOW` not granted | `adb shell appops set com.sundara.dapsettings WRITE_SETTINGS allow` and `... SYSTEM_ALERT_WINDOW allow` |

## Status bar / keys

| Symptom | Cause | Fix |
| --- | --- | --- |
| Status bar / shade still visible | SystemUI not disabled | `adb shell pm disable-user --user 0 com.android.systemui` then `adb reboot` |
| Center key does nothing | Keylayout not applied / not rebooted | Reboot; verify `adb shell cat /system/usr/keylayout/<file>.kl` shows `key 172 MEDIA_PLAY_PAUSE` |
| Recents key still switches apps | Left key still mapped to `APP_SWITCH` | Confirm the keylayout leaves key 139 unmapped; reboot |

## Haptics

| Symptom | Cause | Fix |
| --- | --- | --- |
| No wheel thud | `vtg_level` too low (motor under startup threshold) | `adb shell su -c 'echo 2800 > /sys/devices/virtual/timed_output/vibrator/vtg_level'`; set `DAP_HAPTICS_MV=2800` |
| Sharp buzz instead of thud | Voltage too high | Lower to ~2500–2600 mV; re-run haptics |
| Haptics revert after reboot | rc file missing or wrong path | Check `/system/etc/init/dap-haptics.rc` exists and points at `/system/etc/dapify/dap-haptics.sh` |

Live tuning without remounting:

```sh
adb shell su -c 'setprop persist.dap.haptics.vtg 2800; setprop dap.haptics.apply 0; setprop dap.haptics.apply 1'
adb shell su -c 'cat /sys/devices/virtual/timed_output/vibrator/vtg_level'
adb shell dumpsys vibrator | tail -10   # timeout 14 = detent, 16 = tap
```

## Charge bypass

| Symptom | Cause | Fix |
| --- | --- | --- |
| `init.svc.dap-charge` not `running` | rc not parsed (needs reboot) or wrong init domain | Reboot; check `adb shell su -c 'dmesg \| grep dap-charge'` for AVC denials and set `DAP_INIT_DOMAIN` |
| Phone drops to battery while plugged in | Used the USB `charging_enabled` node | Use the battery-side node (`DAP_CHARGE_NODE`) |
| Never suspends at 100 % | Online nodes not detected | Verify `DAP_CHARGE_ONLINE_NODES` matches the `usb`/`ac` entries that report `online=1` |
| Stays suspended after unplug | Daemon not resuming | `adb logcat -d -s dap-charge`; ensure it sees `online=0` |

Verify:

```sh
adb shell getprop init.svc.dap-charge
adb shell su -c 'cat /sys/class/power_supply/battery/battery_charging_enabled'
adb shell dumpsys battery | sed -n '1,18p'
adb logcat -d -s dap-charge
adb shell su -c 'dmesg | grep dap-charge'
```

Live tuning:

```sh
adb shell su -c 'setprop persist.dap.charge.suspend 100'
adb shell su -c 'setprop persist.dap.charge.resume 90'
```

## Installer

| Symptom | Cause | Fix |
| --- | --- | --- |
| `cannot remount /system read-write` | Read-only system (system-as-root / verity) | Use a Magisk root and let `DAP_ROOT_BACKEND=auto` pick the magisk backend |
| `no working su found` | Root not installed / wrong su path | Install CM root, LOS su, or Magisk; check `adb shell su -c id` |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | New APK signed with a different key than the installed one | `adb shell pm uninstall <package>` then reinstall, or use `--no-apps` |
| `doctor` fails after a clean install | A module was skipped | Re-run `./install.sh install` with the full `--modules` set |

## Still stuck?

`./install.sh uninstall --device <codename>` and start again from a known state.
Re-enabling the stock UI is in [recovery.md](recovery.md).
