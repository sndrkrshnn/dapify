# DAP Settings

The companion settings app for DAPify: Wi-Fi, Bluetooth, display timeout and
brightness, storage readout, and a boot helper that wakes the screen, dismisses
the keyguard, and launches the player.

Plain Java, no AndroidX, built against the API 25 SDK (Android 7.1.2). The UI
uses DAP Sans (TeX Gyre Heros, GUST Font License) — see `assets/fonts/`.

## Building

Signing is external to the repository. Set the keystore environment variables
to produce an installable APK:

```sh
export ANDROID_SDK_ROOT=/path/to/android-sdk
export DAP_KEYSTORE=/path/to/release.keystore
export DAP_KEYSTORE_PASS=<store-password>
export DAP_KEY_ALIAS=dap
./build.sh
# -> build/dapsettings.apk
```

Without `DAP_KEYSTORE` the script still builds an unsigned APK at
`build/dapsettings-unsigned.apk` for CI checks only.

`build.sh` uses v1 `jarsigner` signing deliberately: Android 7 accepts it, and
`apksigner` crashes under Java 17 with `InaccessibleObjectException` on some
hosts.
