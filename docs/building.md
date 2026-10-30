# DAPify — building the apps

Both apps must be signed with a **keystore you keep**. DAPify never commits
keystores, `key.properties`, `local.properties`, or APKs. Generate one release
keystore and store it somewhere safe (backups, a password manager, CI secrets).

```sh
keytool -genkeypair -keystore release.keystore -alias dap \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=DAPify, O=DAPify, C=US"
```

You need the same keystore for every future update of both apps; Android will
not let you update an app with a different signature.

## Player (`apps/classipod`)

A Flutter fork of ClassiPod 2.1.0.

```sh
cd apps/classipod
export ANDROID_HOME=/path/to/android-sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME

# release signing (gitignored)
cp android/key.properties.example android/key.properties
# edit android/key.properties: storeFile -> ../keystore/release.keystore,
#   storePassword / keyPassword / keyAlias

flutter pub get
flutter build apk --release --flavor production --target-platform android-arm64
cp build/app/outputs/flutter-apk/app-production-release.apk ../../dist/classipod.apk
```

Notes:

- `applicationId` defaults to `com.sundara.classipod`; override with
  `-PdapApplicationId=org.example.player` if you want a different ID (this
  also requires updating the native channel names and the settings app's
  `PLAYER_PACKAGE`).
- Without `android/key.properties` the release build is debug-signed (works for
  testing, not for updates).
- If Gradle asks for a platform that exists as `android-NN.0`, keep the
  symlink `android-NN -> android-NN.0`.

## Settings (`apps/dapsettings`)

Plain Java, API 25 SDK, v1 `jarsigner` signing.

```sh
cd apps/dapsettings
export ANDROID_SDK_ROOT=/path/to/android-sdk
export DAP_KEYSTORE=../keystore/release.keystore   # or absolute path
export DAP_KEYSTORE_PASS=<store-password>
export DAP_KEY_ALIAS=dap
./build.sh
cp build/dapsettings.apk ../../dist/dapsettings.apk
```

`build.sh` uses `aapt`/`dx`/`jarsigner` from `build-tools/25.0.3` and
`platforms/android-25`. Do not switch to `apksigner`: it crashes under Java 17
with `InaccessibleObjectException` on some hosts.

## Fonts

The UI font is **DAP Sans**, the unmodified TeX Gyre Heros font (GUST Font
License). It is committed under `apps/*/assets/fonts/`. The proprietary
Linotype Helvetica files used in the private kenzo build are **not** part of
this repository — do not add them.

## Releasing

1. Build both APKs with the release keystore.
2. Create a GitHub release and upload `dist/classipod.apk` and
   `dist/dapsettings.apk` as assets (name them `classipod.apk` and
   `dapsettings.apk`).
3. Publish the SHA-256 of each in the release notes.
4. `install.sh` can install either the local `dist/` copies or the release
   assets.
