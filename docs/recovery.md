# DAPify — recovery

DAPify disables `com.android.systemui` and the keyguard. If you need the stock
UI back, ADB is your friend. All of the following work over ADB; you do **not**
need the touch screen.

Serial is `45abfcf1` on the verified device; use `adb -s <serial>` if you have
more than one device attached.

## Re-enable the stock UI

```sh
adb shell pm enable com.android.systemui
adb shell am force-stop com.android.systemui
adb reboot
```

You now have the status bar, notification shade, navigation bar and power menu
back.

## Restore the previous home app

`./install.sh uninstall` restores the home activity it recorded at install
time. To do it manually, find the launcher you want and set it:

```sh
adb shell cmd package resolve-activity --brief \
    -a android.intent.action.MAIN -c android.intent.category.HOME
# pick the launcher line, then:
adb shell cmd package set-home-activity --user 0 <pkg>/<activity>
```

## Remove DAPify (scripts, keymap, charge daemon)

```sh
./install.sh uninstall --device kenzo
adb reboot
```

This restores every file it backed up under `/data/dapify/backup` and removes
the DAPify state. Apps are left installed unless you pass `--remove-apps`.

Manually, the DAPify files are:

```
/system/etc/dapify/            # device.conf, scripts, version
/system/etc/init/dap-haptics.rc
/system/etc/init/dap-charge.rc
/system/usr/keylayout/<your keylayout>.kl   (replaced, not added)
/data/dapify/                  # backup + manifest
```

## Stop the charge daemon

```sh
# system backend
adb shell su -c 'stop dap-charge'
# magisk backend
adb shell su -c 'pkill -f dap-charge.sh'
```

Re-enable charging immediately if you have suspended it:

```sh
adb shell su -c 'echo 1 > /sys/class/power_supply/battery/battery_charging_enabled'
```

## If the player won't start

```sh
# bring up the default home instead of the player
adb shell am start -a android.intent.action.MAIN -c android.intent.category.HOME
# or launch the player explicitly
adb shell am start -n com.sundara.classipod/com.adeeteya.classipod.MainActivity
```

## If you are stuck on a black screen

- power off and on again (power button, hold ~10 s)
- if that fails, force a reboot from the host: `adb reboot`
- last resort: unlock the bootloader and re-flash the ROM. The DAP state is
  all in `/system` and `/data/dapify`, so a clean flash removes it.

## Disable the keyguard only

If you want the status bar back but the player as home, just re-enable
SystemUI (first section) and leave the home activity pointing at the player.
