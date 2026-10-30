# Security

DAPify requires root and modifies system partitions or Magisk modules. If you
believe you have found a security issue, please report it responsibly.

## Reporting

Open a **private** security advisory (GitHub: Security > Reporting a
vulnerability) rather than a public issue, or email the maintainer.

Include:

- the device codename, ROM and root solution
- the command you ran and what you expected vs. what happened
- any log output (`adb logcat -d`, `dmesg`)

## What we will and won't fix

- We will fix bugs that let the installer corrupt a device or lose user data.
- We will not add features that weaken the device's security posture (e.g.
  disabling SELinux broadly, exposing root without the user's intent).

## Secrets

Never commit signing keys, `key.properties`, `local.properties`, `*.keystore`,
or proprietary fonts. If you accidentally commit a secret, rotate it and purge
it from history; do not rely on a later commit to remove it.
