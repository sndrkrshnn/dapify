# DAPify — device porting guide

Adding support for a new device means writing a **device profile**. The
installer does all the mechanical work; you just have to discover the
device-specific values.

Work on a rooted device with ADB. Use a device you can re-flash if something
goes wrong.

## 1. Create the profile

```sh
cp -r devices/_template devices/<codename>
# <codename> is `adb shell getprop ro.product.device`
```

Fill in `devices/<codename>/device.conf`. Most values have safe defaults; the
ones you must discover are marked below.

## 2. Discover the values

Run from the host.

### Root and backend

```sh
adb shell su -c id            # or /system/xbin/su, /system/bin/su
adb shell ls -ld /data/adb/magisk   # present -> Magisk backend
```

`DAP_ROOT_BACKEND=auto` picks Magisk when it is present, otherwise the legacy
`/system` backend. On newer ROMs the `/system` partition is read-only and the
system backend will fail — use Magisk.

### Battery / charge bypass

The charge bypass writes a *battery-side* suspend vote. Find the node:

```sh
adb shell 'ls /sys/class/power_supply/battery'
adb shell 'for f in /sys/class/power_supply/battery/*; do echo "$f: $(cat $f 2>/dev/null)"; done'
```

Use a node like `battery_charging_enabled`. **Do not use the sibling
`charging_enabled`** node: on the verified device it also cuts the USB input
path and the phone drops back onto battery power.

Confirm it toggles:

```sh
adb shell su -c 'echo 0 > /sys/class/power_supply/battery/battery_charging_enabled'
adb shell dumpsys battery   # status should flip to Discharging while plugged in
adb shell su -c 'echo 1 > /sys/class/power_supply/battery/battery_charging_enabled'
```

Set `DAP_CHARGE_NODE` to the working node. `DAP_CHARGE_ONLINE_NODES` should
list the `usb`/`ac`/`wireless` entries under `/sys/class/power_supply/` that
report `online=1` when plugged in.

### Haptics

```sh
adb shell 'ls /sys/class/timed_output 2>/dev/null; ls /sys/devices/virtual/timed_output 2>/dev/null'
```

Find the node that has `vtg_level` (QPNP) or an equivalent voltage/driver
control. On the verified device it is
`/sys/devices/virtual/timed_output/vibrator/vtg_level`.

```sh
adb shell su -c 'echo 2800 > /sys/devices/virtual/timed_output/vibrator/vtg_level'
adb shell su -c 'cat /sys/devices/virtual/timed_output/vibrator/vtg_level'
```

2800 mV is the verified starting point for a soft thud. Below ~2500 mV the ERM
motor often stops starting on this class of device. Set `DAP_VIBRATOR_DIR` to
the directory containing the node, and `DAP_HAPTICS_MV` to the verified value.

### Capacitive keys (keylayout)

```sh
adb shell ls /system/usr/keylayout/
# find the file that covers the capacitive keys (often named after the
# touchscreen controller, e.g. Atmel_maXTouch_Touchscreen.kl)
adb shell cat /system/usr/keylayout/<file>.kl
```

Copy the stock file, change only the keys you need, and keep the original
copyright header. The DAP convention is:

- center key -> `MEDIA_PLAY_PAUSE` (primary transport; the player is the home app)
- left key  -> unmapped (remove the old app-switch action)
- right key -> `BACK` (unchanged)

Put the file at `devices/<codename>/keylayout/<name>.kl` and set
`DAP_KEYLAYOUT_SOURCE` / `DAP_KEYLAYOUT_TARGET` to `<name>.kl`. The target must
match the file name in `/system/usr/keylayout/`.

### Init domain (system backend only)

The charge daemon must run in an init domain that can `execve /system/bin/sh`
and write the battery node. On the verified ROM that is `qti_init_shell`.

If you don't know your device's domain, leave `DAP_INIT_DOMAIN` empty and test.
The first boot will log an AVC denial in `dmesg` — that names the domain you
need:

```sh
adb shell su -c 'dmesg | grep -i avc | grep dap-charge'
```

## 3. Verify

```sh
./install.sh doctor --device <codename>
./install.sh install --device <codename>
adb reboot
./install.sh doctor --device <codename>
```

`doctor` checks root, the app packages, home activity, SystemUI, keyguard,
haptics voltage, charge daemon/node, keylayout, and doze whitelist. Read the
output and fix any FAILs before calling the device supported.

Manual checks:

- rotate the wheel: one soft pulse per tick, in sync with the click sound
- press the center key: play/pause through the active media session
- plug in at 100 %: `adb shell getprop init.svc.dap-charge` -> `running`, and
  `adb logcat -d -s dap-charge` shows the suspend event
- unplug: charging resumes immediately

## 4. Submit

- add the profile under `devices/<codename>/`
- add a row to the compatibility table in `docs/compatibility.md`
- keep the profile values quoted (the file is sourced by POSIX shell)
- never commit signing keys, `key.properties`, `local.properties`, or APKs
