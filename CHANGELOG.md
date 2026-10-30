# Changelog

## 0.1.0

First public release, with prebuilt APKs attached to the GitHub release
(`classipod.apk`, `dapsettings.apk`, `SHA256SUMS`).

- **Audio policy module**: generalized `modules/audio/patch_audio_policy.py`
  (idempotent, works on kenzo and sdm845/beryllium stock files) and a
  pre-patched `audio_policy_configuration.xml` per profile. The installer
  installs (and backs up / restores on uninstall) the hi-res audio policy —
  44.1 kHz on the primary/raw/deep-buffer paths and 16/24-bit PCM at
  44.1/48/88.2/96/176.4/192 kHz on the wired `direct_pcm` path. `doctor`
  reports whether the installed policy matches the profile.
- **beryllium (Xiaomi POCO F1) profile**: unverified best-effort port written
  from the LineageOS `beryllium` + `sdm845-common` trees. arm64, single
  physical HOME button + rear Goodix fingerprint (no capacitive nav to remap),
  read-only `/system` → Magisk backend, `/vendor/etc` audio policy target.
  Marked `(VERIFY)` for the vibrator/charge/audio-path nodes that must be
  confirmed on a real device.
- **Easier install**: `scripts/fetch-release.sh` downloads the prebuilt release
  APKs + SHA-256 into `dist/` so users can install without a Flutter/Android
  SDK. `detect_backend` now probes Magisk as root (it was misreporting on
  devices where `/data/adb` is not visible to a non-root shell).
- **doctor**: reads the audio policy and haptics/charge sysfs nodes as root.
- Initial open-source packaging of the kenzo DAP conversion: installer
  (`install.sh`) with `install` / `uninstall` / `doctor` / `list`; device
  profiles (`kenzo` verified, `_template`); system (`/system`) and Magisk
  backends; haptics (2800 mV default), charge bypass, capacitive-key remap,
  SystemUI removal, ClassiPod/DAP Settings home stack.
- ClassiPod fork + DAP Settings source, with DAP Sans (TeX Gyre Heros) in
  place of the proprietary Helvetica.
- Docs: porting, architecture, recovery, troubleshooting, building,
  compatibility.
