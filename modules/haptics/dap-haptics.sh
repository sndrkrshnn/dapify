#!/system/bin/sh
# DAPify haptics: set the QPNP vibrator drive voltage for the click-wheel
# detent and the button tap.
#
# The app sends a 14 ms wheel pulse and a 16 ms button pulse. At 2800 mV the
# short detent reads as a soft "thud"; below roughly 2500 mV the ERM motor
# stops starting reliably even though the pulse is still sent.
#
# Tune without remounting /system:
#   su -c 'setprop persist.dap.haptics.vtg 2800;
#          setprop dap.haptics.apply 0; setprop dap.haptics.apply 1'
#
# The device profile is installed at /system/etc/dapify/device.conf. The
# /data/adb fallback is used by the Magisk service before the overlay is
# available.

PATH=/system/bin:/system/xbin
CONF=${DAP_CONF:-/system/etc/dapify/device.conf}
[ -f "$CONF" ] || CONF=/data/adb/dapify/device.conf
[ -f "$CONF" ] && . "$CONF"

VIB=${DAP_VIBRATOR_DIR:-/sys/devices/virtual/timed_output/vibrator}
DEFAULT=${DAP_HAPTICS_MV:-2800}
MIN=${DAP_HAPTICS_MIN_MV:-800}
MAX=${DAP_HAPTICS_MAX_MV:-3600}

dap_log() {
    /system/bin/log -p i -t dap-haptics "$*" 2>/dev/null
    echo "dap-haptics: $*" > /dev/kmsg 2>/dev/null
}

TARGET=$(getprop persist.dap.haptics.vtg)
[ -n "$TARGET" ] || TARGET=$(getprop dap.haptics.vtg)
[ -n "$TARGET" ] || TARGET=$DEFAULT

case "$TARGET" in
    ''|*[!0-9]*) TARGET=$DEFAULT ;;
esac
if [ "$TARGET" -lt "$MIN" ] || [ "$TARGET" -gt "$MAX" ]; then
    dap_log "ignoring out-of-range vtg=$TARGET (${MIN}-${MAX}), using $DEFAULT"
    TARGET=$DEFAULT
fi

if [ -e "$VIB/vtg_level" ]; then
    if echo "$TARGET" > "$VIB/vtg_level" 2>/dev/null; then
        dap_log "vtg_level=$(cat "$VIB/vtg_level" 2>/dev/null)"
    else
        dap_log "ERROR cannot write $VIB/vtg_level"
        exit 1
    fi
else
    dap_log "ERROR vibrator sysfs not found at $VIB/vtg_level"
    exit 1
fi
