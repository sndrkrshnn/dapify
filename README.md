# DAPify

Turn a rooted Android phone into a single-purpose, iPod-style music player:

- boots straight into the forked **ClassiPod** player as the home app — no
  launcher, no status bar, no notification shade, no keyguard
- a silk-screened **SETTINGS** key (or the player's Settings menu) opens the
  **DAP Settings** companion: Wi-Fi, Bluetooth, brightness, timeout
- capacitive center key = play/pause, left key inert, right key = back
- soft, muted click-wheel haptics (one pulse per rotation tick)
- charge bypass: when plugged in and full, the phone runs from the wall
  instead of cycling at 100 %

DAPify is a porting kit. The verified baseline is the **Xiaomi Redmi Note 3
(`kenzo`)** on LineageOS 14.1; other LineageOS devices can be added by writing
a device profile — see [docs/porting.md](docs/porting.md).

> **Warning:** DAPify disables `com.android.systemui` and the keyguard. You
> will have no power menu, no volume panel and no status bar. Keep ADB
> connected and read [docs/recovery.md](docs/recovery.md) before installing.
> If you brick the device, unlock the bootloader and re-flash the ROM.

## Quick start

Prerequisites:

- a rooted Android device (CM root, LineageOS built-in su, or Magisk)
- the ADB platform-tools on your host
- the player APKs, or the Flutter/Android SDKs to build them (see
  [Building the apps](#building-the-apps))

```sh
git clone https://github.com/sndrkrshnn/dapify
cd dapify

# check the device and profile
./install.sh doctor --device kenzo

# install (idempotent; records the original state for uninstall)
./install.sh install --device kenzo

# reboot so the keylayout and init files are read
adb reboot

# verify
./install.sh doctor --device kenzo
```

Add your music to the external SD card or internal storage, then rescan in
the player.

## Commands

| Command | What it does |
| --- | --- |
| `./install.sh list` | show available device profiles |
| `./install.sh install --device kenzo` | apply the profile (keymap, haptics, charge, SystemUI, home app) |
| `./install.sh doctor --device kenzo` | read-only health check, exits non-zero on failure |
| `./install.sh uninstall --device kenzo` | remove DAPify and restore the original state |
| `./install.sh help` | usage |

`install` flags: `--modules all|systemui,home,keymap,haptics,charge,doze`,
`--apk-dir DIR`, `--no-apps` (skip installing the APKs), `--yes`, `--dry-run`.

## How it works

- **System backend** (legacy, verified on kenzo): installs
  `/system/etc/dapify/*` scripts and `/system/etc/init/dap-*.rc`, and the
  keylayout into `/system/usr/keylayout/`. Every replaced file is backed up
  under `/data/dapify/backup` and listed in `/data/dapify/manifest` so
  `uninstall` restores it exactly.
- **Magisk backend**: installs a Magisk module that overlays the same files
  and starts the charge daemon from `service.sh`. No `/system` modification.
- The backend is selected by `DAP_ROOT_BACKEND` in the device profile
  (`auto` = Magisk if present, otherwise the system backend).

See [docs/architecture.md](docs/architecture.md) for the full picture.

## Building the apps

The player is a fork of [ClassiPod 2.1.0](https://github.com/adeeteya/Classipod)
(BSD-4-Clause). The settings app is plain Java built against API 25.

```sh
# player (Flutter)
cd apps/classipod
export ANDROID_HOME=/path/to/android-sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
flutter pub get
flutter build apk --release --flavor production --target-platform android-64
cp build/app/outputs/flutter-apk/app-production-release.apk ../../dist/classipod.apk

# settings (API 25 SDK)
cd ../dapsettings
export DAP_KEYSTORE=/path/to/release.keystore
export DAP_KEYSTORE_PASS=<store-password>
export DAP_KEY_ALIAS=dap
./build.sh
cp build/dapsettings.apk ../../dist/dapsettings.apk
```

Both APKs must be signed with the **same** keystore you intend to update with
in the future. Keep that keystore out of the repository; see
[docs/building.md](docs/building.md).

## Porting to your device

1. `cp -r devices/_template devices/<codename>`
2. fill in `devices/<codename>/device.conf` (see the discovery commands in
   [docs/porting.md](docs/porting.md))
3. if the device has capacitive keys, add a `.kl` file under
   `devices/<codename>/keylayout/`
4. `./install.sh doctor --device <codename>`, fix, then `./install.sh install`

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md). Recovery (re-enabling
the stock UI, restoring the previous home app) is in
[docs/recovery.md](docs/recovery.md).

## License

DAPify is MIT licensed (see `LICENSE`). The bundled player is a fork of
ClassiPod (BSD-4-Clause, see `apps/classipod/LICENSE`); the UI font is TeX Gyre
Heros (GUST Font License, see `apps/*/assets/fonts/GUST-FONT-LICENSE.txt`). See
`NOTICE` for the full attribution.
