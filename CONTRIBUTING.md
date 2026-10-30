# DAPify

Turn an old Android phone into a single-purpose, iPod-style music player.

## Contributing

Thanks for helping. The fastest way to make an impact is to **port a new
device** — see [docs/porting.md](docs/porting.md).

### Before you open a PR

- Read [AGENTS.md](AGENTS.md).
- Keep shell scripts POSIX `sh` compatible (`sh -n` passes, no bashisms).
- Never add signing keys, `key.properties`, `local.properties`, `*.keystore`,
  `*.apk`, build artifacts, or proprietary fonts (Linotype Helvetica).
- Preserve licenses and `NOTICE`; ClassiPod stays BSD-4-Clause.
- Don't change the verified kenzo values unless you have a reason and a way to
  verify the change.

### What to include with a device port

1. `devices/<codename>/device.conf`
2. a keylayout under `devices/<codename>/keylayout/` if the device has
   capacitive keys
3. a row in the `docs/compatibility.md` table
4. the output of `./install.sh doctor --device <codename>` showing no FAILs

### Reporting problems

Open an issue with the output of `./install.sh doctor`, your ROM and root
solution, and the relevant `adb logcat -d -s dap-charge` / `dmesg | grep
dap-charge` lines.
