# DAPify doctor. POSIX sh; sourced by install.sh after lib/common.sh.

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

check() {
    # $1=pass|warn|fail  $2=label  $3=detail
    case "$1" in
        pass) PASS_COUNT=$((PASS_COUNT + 1)); printf '%s%s%s %s%s\n' "$C_GREEN" "ok  " "$C_RESET" "$2" "${3:+ — $3}" ;;
        warn) WARN_COUNT=$((WARN_COUNT + 1)); printf '%s%s%s %s%s\n' "$C_YELLOW" "warn" "$C_RESET" "$2" "${3:+ — $3}" ;;
        fail) FAIL_COUNT=$((FAIL_COUNT + 1)); printf '%s%s%s %s%s\n' "$C_RED" "FAIL" "$C_RESET" "$2" "${3:+ — $3}" ;;
    esac
}

pkg_installed() {
    adb_shell "pm list packages $1" 2>/dev/null |
        grep -qx "package:$2"
}

pkg_disabled() {
    adb_shell "pm list packages -d" 2>/dev/null |
        grep -qx "package:$1"
}

do_doctor() {
    require_adb
    load_device "$DAP_DEVICE"

    info "doctor: $(device_prop ro.product.model) codename=$(device_codename) android=$(device_android) sdk=$(device_sdk)"
    info "profile: $DAP_DEVICE_CODENAME backend=$DAP_ROOT_BACKEND"
    say

    # root
    if detect_su >/dev/null 2>&1; then
        check pass "root available" "$SU_CMD"
    else
        check fail "root available" "no working su found"
    fi

    # player app
    if pkg_installed "" "$DAP_PLAYER_PACKAGE"; then
        check pass "player package installed" "$DAP_PLAYER_PACKAGE"
    else
        check fail "player package installed" "$DAP_PLAYER_PACKAGE"
    fi
    if pkg_installed "" "$DAP_SETTINGS_PACKAGE"; then
        check pass "settings package installed" "$DAP_SETTINGS_PACKAGE"
    else
        check fail "settings package installed" "$DAP_SETTINGS_PACKAGE"
    fi

    # home activity
    home=$(adb_shell "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME" \
        | grep -E '^[A-Za-z0-9_.]+/[A-Za-z0-9_.$]+$' | tail -n 1)
    case "$home" in
        "$DAP_PLAYER_PACKAGE/$DAP_PLAYER_ACTIVITY")
            check pass "home activity" "$home" ;;
        "")
            check fail "home activity" "could not resolve a home activity" ;;
        *)
            check warn "home activity" "resolved to $home, expected $DAP_PLAYER_PACKAGE/$DAP_PLAYER_ACTIVITY" ;;
    esac

    # systemui
    if pkg_disabled "$DAP_SYSTEMUI_PACKAGE"; then
        check pass "SystemUI disabled" "$DAP_SYSTEMUI_PACKAGE"
    else
        check fail "SystemUI disabled" "$DAP_SYSTEMUI_PACKAGE is still enabled"
    fi

    # keyguard
    if [ "$(adb_shell 'settings get secure lockscreen.disabled')" = "1" ]; then
        check pass "keyguard disabled" "lockscreen.disabled=1"
    else
        check fail "keyguard disabled" "lockscreen.disabled is not 1"
    fi

    # haptics (node needs root)
    vtg=$(adb_root_cat "$DAP_VIBRATOR_DIR/vtg_level")
    want_vtg=$(adb_shell "getprop persist.dap.haptics.vtg" 2>/dev/null | tr -d '\r')
    [ -n "$want_vtg" ] || want_vtg=$DAP_HAPTICS_MV
    if [ -n "$vtg" ]; then
        if [ "$vtg" = "$want_vtg" ]; then
            check pass "haptics voltage" "$vtg mV (persist=$want_vtg)"
        else
            check warn "haptics voltage" "$vtg mV on device, persist requests $want_vtg (a live override is fine)"
        fi
    else
        check fail "haptics voltage" "$DAP_VIBRATOR_DIR/vtg_level unreadable as root"
    fi

    # charge
    charge_svc=$(adb_shell "getprop init.svc.dap-charge" 2>/dev/null | tr -d '\r')
    if [ "$charge_svc" = "running" ]; then
        check pass "charge daemon" "init.svc.dap-charge=running"
    else
        # Magisk backend runs it as a plain process, not an init service.
        if adb_shell "pgrep -f dap-charge.sh" >/dev/null 2>&1; then
            check pass "charge daemon" "process running (magisk)"
        else
            check fail "charge daemon" "init.svc.dap-charge=$charge_svc and no dap-charge process"
        fi
    fi
    charge_node=$(adb_root_cat "$DAP_CHARGE_NODE")
    if [ -n "$charge_node" ]; then
        check pass "charge node" "$DAP_CHARGE_NODE = $charge_node (1=charging, 0=suspended)"
    else
        check fail "charge node" "$DAP_CHARGE_NODE unreadable as root"
    fi

    # keylayout
    if [ -n "${DAP_KEYLAYOUT_TARGET:-}" ]; then
        kl=$(adb_shell "cat /system/usr/keylayout/$DAP_KEYLAYOUT_TARGET" 2>/dev/null)
        if printf '%s\n' "$kl" | grep -q 'key 172' &&
            printf '%s\n' "$kl" | grep -q 'MEDIA_PLAY_PAUSE'; then
            check pass "keylayout" "center key remapped to MEDIA_PLAY_PAUSE"
        elif [ -n "$kl" ]; then
            check warn "keylayout" "$DAP_KEYLAYOUT_TARGET present but not the DAP remap (reboot required?)"
        else
            check fail "keylayout" "/system/usr/keylayout/$DAP_KEYLAYOUT_TARGET not found"
        fi
    else
        check warn "keylayout" "profile has no keylayout target"
    fi

    # doze whitelist
    if adb_shell "dumpsys deviceidle whitelist" 2>/dev/null |
        grep -q "$DAP_PLAYER_PACKAGE"; then
        check pass "doze whitelist" "player whitelisted"
    else
        check warn "doze whitelist" "player not in deviceidle whitelist"
    fi

    say
    say "summary: $PASS_COUNT ok, $WARN_COUNT warnings, $FAIL_COUNT failed"
    [ "$FAIL_COUNT" -eq 0 ] || return 1
    return 0
}
