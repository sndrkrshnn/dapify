# ClassiPod fork

This directory is a fork of [ClassiPod 2.1.0](https://github.com/adeeteya/Classipod)
(BSD-4-Clause, see `LICENSE`) adapted for use as a single-purpose DAP home app.
The original project README is preserved as `UPSTREAM-README.md`.

## DAP changes

- `MainActivity` declares `MAIN` + `LAUNCHER` + `HOME` + `DEFAULT`, so the
  player can be the device's home app.
- Native `MethodChannel`/`EventChannel` bridges for haptics, screen on/off,
  external power, and battery level.
- Album-art lock screen, AOD while on external power, and a custom volume HUD.
- Click-wheel haptics: one short pulse per rotation tick, synchronized with
  the click sound.
- The settings entry launches the DAP Settings companion app.
- The UI font is DAP Sans (TeX Gyre Heros) instead of proprietary Helvetica.

See `FORK.md` for the file-level change list and `docs/architecture.md` in the
root for how the pieces fit together.

## Building

```sh
# from the repo root
export ANDROID_HOME=/path/to/android-sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
flutter pub get
flutter build apk --release --flavor production --target-platform android-arm64
```

For a release build you need `apps/classipod/android/key.properties`
(gitignored; see `key.properties.example`). Without it the release build is
debug-signed and cannot be used to update a previously signed install.
