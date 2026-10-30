# DAPify — architecture

## Components

```
+---------------------------------------------------------------------+
| host (macOS / Linux)                                                 |
|   install.sh + lib/*.sh   <-  drives everything over ADB            |
+---------------------------------------------------------------------+
            |  adb shell / adb push / adb install
            v
+---------------------------------------------------------------------+
| device (rooted Android)                                              |
|                                                                      |
|  /system (system backend)      OR      Magisk module (magisk backend)|
|   etc/dapify/device.conf              overlay: etc/dapify/*          |
|   etc/dapify/dap-haptics.sh           etc/init/dap-haptics.rc        |
|   etc/dapify/dap-charge.sh            usr/keylayout/<name>.kl        |
|   etc/init/dap-haptics.rc             service.sh (late_start)        |
|   etc/init/dap-charge.rc                                                  |
|   usr/keylayout/<name>.kl                                            |
|                                                                      |
|  /data/dapify/  backup + manifest      (system backend state)        |
|  /data/adb/dapify/  runtime scripts    (magisk backend state)        |
|                                                                      |
|  apps:                                                               |
|   com.sundara.classipod   player (HOME app)                          |
|   com.sundara.dapsettings companion settings                         |
+---------------------------------------------------------------------+
```

## Boot flow

1. init parses `/system/etc/init/dap-haptics.rc` and `dap-charge.rc`
   (system backend). On Magisk the module overlay is mounted by Magisk and
   `service.sh` runs at `late_start`.
2. `sys.boot_completed=1` fires:
   - the haptics script writes `vtg_level` to the vibrator node
   - the `dap-charge` init service starts the charge-bypass daemon
   - (Magisk) `service.sh` does the same for both
3. `com.sundara.dapsettings` `BootReceiver` fires on `BOOT_COMPLETED`:
   starts the foreground `OverlayService`, which after 3 s wakes the screen,
   disables the keyguard, and launches the player.
4. The player is the home activity, so it is also what the Home key returns
   to. It keeps the screen flags and registers screen-on/off, power and
   battery broadcasts.

## Haptics

The app sends two kinds of pulses through a `MethodChannel`:

- `tap`    -> 16 ms, button press
- `detent` -> 14 ms, one per wheel rotation tick

`haptics_service.dart` throttles detents to a 35 ms minimum gap so fast flicks
stay distinct. The actual *strength* is set once at boot by
`dap-haptics.sh` writing `vtg_level` (mV) to the QPNP vibrator node. Below
~2500 mV the ERM motor stops starting reliably; 2800 mV is the verified
"soft thud".

## Charge bypass

`dap-charge.sh` polls every 15 s:

- while external power is online **and** `capacity >= suspend_at` (default
  100), it writes `0` to `DAP_CHARGE_NODE` to suspend battery charging
- while suspended and (unplugged **or** `capacity <= resume_at` (default 90)),
  it writes `1` to resume

It reads everything from `/sys/class/power_supply` because the init domain it
runs in has no binder access (no `dumpsys`). It must use the battery-side node,
never the USB `charging_enabled` node.

The daemon is sysfs-only and logs to `logcat` + `/dev/kmsg` (no files), because
the domain cannot write `/data/local/tmp`.

## Keymap

The keylayout remaps the capacitive keys:

- center (Linux 172) -> `MEDIA_PLAY_PAUSE`
- left  (Linux 139)  -> unmapped
- right (Linux 158)  -> `BACK`

Android reads keylayouts when the input device opens, so a reboot is required
after installing one.

## SystemUI and home

- `pm disable-user --user 0 com.android.systemui` removes the status bar,
  shade, nav bar, volume panel and power menu
- `settings put secure lockscreen.disabled 1` keeps the keyguard off
- `cmd package set-home-activity` points the HOME category at the player

The installer records the previous home activity and SystemUI state before
changing them, so `uninstall` can restore them.

## Security / footguns

- **`charging_enabled` (USB node) is wrong.** It cuts the input path; use the
  battery-side node.
- **The charge daemon must run in the right SELinux domain.** On kenzo that is
  `qti_init_shell`; the default init domain cannot `execve /system/bin/sh` on
  this ROM.
- **Do not move haptics to `/system/etc/init.d`.** `sysinit` runs as
  `u:r:sysinit:s0`, cannot write the vibrator node, and cannot call `su`.
- **Keylayouts need a reboot.** They are read when the input device opens.
- **Replacing the APK clears the preferred-home flag.** `install_home` always
  re-sets the home activity after installing.
