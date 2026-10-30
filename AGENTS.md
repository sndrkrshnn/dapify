# AGENTS.md — DAPify

Guidance for AI coding agents working in this repository.

## Ground rules

- **Never commit** signing keys, `key.properties`, `local.properties`,
  `*.keystore`, `*.apk`, build artifacts (`.dart_tool`, `.gradle`, `build/`),
  or personal backups. The `.gitignore` enforces this; keep it that way.
- **Never commit** the proprietary Linotype Helvetica font files. The UI font is
  DAP Sans (TeX Gyre Heros, GUST Font License) under `apps/*/assets/fonts/`.
- **Preserve licenses and attribution.** ClassiPod is BSD-4-Clause (see
  `apps/classipod/LICENSE`, `NOTICE`). DAPify's own code is MIT (`LICENSE`).
  Keep `NOTICE` and the per-component license files in sync with any change.
- **Do not change the verified kenzo behavior** unless the user asks. The
  verified values live in `devices/kenzo/device.conf` and
  `docs/compatibility.md` (haptics 2800 mV, charge node
  `battery_charging_enabled`, init domain `qti_init_shell`, etc.).
- **Prefer the dedicated tools** over shell one-liners, and keep shell scripts
  POSIX `sh` compatible (no bashisms; `sh -n` must pass).

## Repo map

- `install.sh` + `lib/` — the host-side installer (POSIX sh). Commands:
  `install`, `uninstall`, `doctor`, `list`, `help`.
- `modules/` — device-side payloads: `device-backend.sh` (system backend),
  `haptics/`, `charge/`, `magisk/` (Magisk module).
- `devices/<codename>/device.conf` — per-device profile, sourced by POSIX sh on
  both host and device. `devices/_template/` is the starting point for ports.
- `apps/classipod/` — ClassiPod fork (player). `apps/dapsettings/` — companion
  settings app.
- `docs/` — porting, architecture, recovery, troubleshooting, building,
  compatibility.

## Adding a device

Follow `docs/porting.md`. Concretely: copy `devices/_template/` to
`devices/<codename>/`, fill in `device.conf`, add a keylayout if there are
capacitive keys, then `./install.sh doctor --device <codename>` and fix FAILs
before `./install.sh install`. Add a row to `docs/compatibility.md`.

## Verification

- Shell: `sh -n <script>` on every shell file you touch.
- Installer: `./install.sh list` and `./install.sh doctor --device kenzo` are
  read-only and safe to run against a connected device. `./install.sh install
  --dry-run` previews without changing the device.
- After a real install on a device: `adb reboot`, then `./install.sh doctor`.

## Safety

- Never run destructive device operations (uninstall, remount, `pm
  uninstall`) without an explicit user request and, in interactive mode, a
  confirmation.
- `install` must stay idempotent and must keep recording the original
  home/SystemUI/lockscreen state for `uninstall`.
- When in doubt, read `docs/recovery.md` before touching `/system`.
