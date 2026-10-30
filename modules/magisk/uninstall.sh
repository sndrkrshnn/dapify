#!/system/bin/sh
# DAPify Magisk uninstall hook. The module's system/ overlay disappears with
# the module directory on the next boot; this only stops the daemon and
# removes runtime state. Original keylayout files were never replaced on disk,
# so they reappear automatically.

pkill -f 'dap-charge.sh' 2>/dev/null || true
rm -rf /data/adb/dapify
