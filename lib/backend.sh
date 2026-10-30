# DAPify install backend. POSIX sh; sourced by install.sh after lib/common.sh.

# ---------------------------------------------------------------------------
# payload staging
# ---------------------------------------------------------------------------

prepare_staging() {
    [ "$DRY_RUN" = "1" ] && return 0
    adb_shell "rm -rf /data/local/tmp/dapify && mkdir -p /data/local/tmp/dapify/keylayout"
    adb_do push "$DAP_PROFILE_DIR/device.conf" /data/local/tmp/dapify/device.conf >/dev/null
    adb_do push "$DAPIFY_ROOT/modules/device-backend.sh" \
        /data/local/tmp/dapify/device-backend.sh >/dev/null
    adb_do push "$DAPIFY_ROOT/modules/haptics/dap-haptics.sh" \
        /data/local/tmp/dapify/dap-haptics.sh >/dev/null
    adb_do push "$DAPIFY_ROOT/modules/haptics/dap-haptics.rc" \
        /data/local/tmp/dapify/dap-haptics.rc >/dev/null
    adb_do push "$DAPIFY_ROOT/modules/charge/dap-charge.sh" \
        /data/local/tmp/dapify/dap-charge.sh >/dev/null
    adb_do push "$DAPIFY_ROOT/modules/charge/dap-charge.rc" \
        /data/local/tmp/dapify/dap-charge.rc >/dev/null
    if [ -n "${DAP_KEYLAYOUT_SOURCE:-}" ] &&
        [ -f "$DAP_PROFILE_DIR/$DAP_KEYLAYOUT_SOURCE" ]; then
        adb_do push "$DAP_PROFILE_DIR/$DAP_KEYLAYOUT_SOURCE" \
            "/data/local/tmp/dapify/keylayout/$DAP_KEYLAYOUT_TARGET" >/dev/null
    fi
}

module_enabled() {
    case ",$MODULES," in
        *,all,*|*,"$1",*) return 0 ;;
        *) return 1 ;;
    esac
}

module_available() {
    module_enabled "$1" && return 0
    return 1
}

# ---------------------------------------------------------------------------
# legacy /system backend
# ---------------------------------------------------------------------------

install_system_backend() {
    require_dry_run_ok "device-backend.sh install"
    [ "$DRY_RUN" = "1" ] && return 0
    out=$(adb_root_script "sh /data/local/tmp/dapify/device-backend.sh install" 2>&1) || {
        printf '%s\n' "$out" | tr -d '\r'
        die "system backend install failed"
    }
    printf '%s\n' "$out" | tr -d '\r'
}

uninstall_system_backend() {
    require_dry_run_ok "device-backend.sh uninstall"
    [ "$DRY_RUN" = "1" ] && return 0
    out=$(adb_root_script "sh /data/local/tmp/dapify/device-backend.sh uninstall" 2>&1) || {
        printf '%s\n' "$out" | tr -d '\r'
        die "system backend uninstall failed"
    }
    printf '%s\n' "$out" | tr -d '\r'
}

# ---------------------------------------------------------------------------
# Magisk backend
# ---------------------------------------------------------------------------

build_magisk_module() {
    [ "$DRY_RUN" = "1" ] && return 0
    out=$DAPIFY_ROOT/dist/magisk-build
    rm -rf "$out"
    mkdir -p "$out/system/etc/dapify" "$out/system/usr/keylayout"

    cp "$DAPIFY_ROOT/modules/magisk/module.prop" "$out/module.prop"
    cp "$DAPIFY_ROOT/modules/magisk/service.sh" "$out/service.sh"
    cp "$DAPIFY_ROOT/modules/magisk/uninstall.sh" "$out/uninstall.sh"
    cp "$DAPIFY_ROOT/modules/haptics/dap-haptics.sh" "$out/system/etc/dapify/"
    cp "$DAPIFY_ROOT/modules/charge/dap-charge.sh" "$out/system/etc/dapify/"
    cp "$DAP_PROFILE_DIR/device.conf" "$out/system/etc/dapify/device.conf"

    if [ -n "${DAP_KEYLAYOUT_SOURCE:-}" ] &&
        [ -f "$DAP_PROFILE_DIR/$DAP_KEYLAYOUT_SOURCE" ]; then
        cp "$DAP_PROFILE_DIR/$DAP_KEYLAYOUT_SOURCE" \
            "$out/system/usr/keylayout/$DAP_KEYLAYOUT_TARGET"
    fi

    chmod 755 "$out/service.sh" "$out/uninstall.sh" \
        "$out/system/etc/dapify/dap-haptics.sh" \
        "$out/system/etc/dapify/dap-charge.sh"
    chmod 644 "$out/module.prop" "$out/system/etc/dapify/device.conf"
    [ -n "${DAP_KEYLAYOUT_TARGET:-}" ] &&
        chmod 644 "$out/system/usr/keylayout/$DAP_KEYLAYOUT_TARGET" 2>/dev/null
}

install_magisk_backend() {
    require_dry_run_ok "magisk module install"
    [ "$DRY_RUN" = "1" ] && return 0
    build_magisk_module
    adb_shell "rm -rf /data/local/tmp/dapify/module"
    adb_do push "$DAPIFY_ROOT/dist/magisk-build" /data/local/tmp/dapify/module >/dev/null

    out=$(adb_root_script '
set -e
rm -rf /data/adb/modules/dapify
mkdir -p /data/adb/modules
cp -r /data/local/tmp/dapify/module /data/adb/modules/dapify
find /data/adb/modules/dapify -type f -exec chmod 644 {} \;
chmod 755 /data/adb/modules/dapify/service.sh
chmod 755 /data/adb/modules/dapify/uninstall.sh
chmod 755 /data/adb/modules/dapify/system/etc/dapify/dap-haptics.sh
chmod 755 /data/adb/modules/dapify/system/etc/dapify/dap-charge.sh
restorecon -R /data/adb/modules/dapify 2>/dev/null || true
mkdir -p /data/adb/dapify
cp -f /data/local/tmp/dapify/module/system/etc/dapify/device.conf /data/adb/dapify/
cp -f /data/local/tmp/dapify/module/system/etc/dapify/dap-haptics.sh /data/adb/dapify/
cp -f /data/local/tmp/dapify/module/system/etc/dapify/dap-charge.sh /data/adb/dapify/
chmod 755 /data/adb/dapify/dap-haptics.sh /data/adb/dapify/dap-charge.sh
DAP_CONF=/data/adb/dapify/device.conf /system/bin/sh /data/adb/dapify/dap-haptics.sh || true
if command -v pgrep >/dev/null 2>&1; then
    pgrep -f "dap-charge.sh" >/dev/null 2>&1 || {
        if command -v setsid >/dev/null 2>&1; then
            setsid /system/bin/sh -c "while true; do DAP_CONF=/data/adb/dapify/device.conf /system/bin/sh /data/adb/dapify/dap-charge.sh; sleep 10; done" >/dev/null 2>&1 &
        else
            nohup /system/bin/sh -c "while true; do DAP_CONF=/data/adb/dapify/device.conf /system/bin/sh /data/adb/dapify/dap-charge.sh; sleep 10; done" >/dev/null 2>&1 &
        fi
    }
fi
echo "magisk module installed"
' 2>&1) || {
        printf '%s\n' "$out" | tr -d '\r'
        die "magisk backend install failed"
    }
    printf '%s\n' "$out" | tr -d '\r'
}

uninstall_magisk_backend() {
    require_dry_run_ok "magisk module remove"
    [ "$DRY_RUN" = "1" ] && return 0
    out=$(adb_root_script '
pkill -f "dap-charge.sh" 2>/dev/null || true
rm -rf /data/adb/modules/dapify /data/adb/dapify
echo "magisk module removed"
' 2>&1) || {
        printf '%s\n' "$out" | tr -d '\r'
        die "magisk backend uninstall failed"
    }
    printf '%s\n' "$out" | tr -d '\r'
}

# ---------------------------------------------------------------------------
# host-side modules (run as adb shell, no root needed)
# ---------------------------------------------------------------------------

record_original_state() {
    ORIGINAL_HOME=$(adb_shell "cmd package resolve-activity --brief \
        -a android.intent.action.MAIN -c android.intent.category.HOME" \
        | grep -E '^[A-Za-z0-9_.]+/[A-Za-z0-9_.$]+$' | tail -n 1)
    if adb_shell "pm list packages -d" |
        grep -qx "package:$DAP_SYSTEMUI_PACKAGE"; then
        SYSTEMUI_WAS_DISABLED=1
    else
        SYSTEMUI_WAS_DISABLED=0
    fi
    if [ "$(adb_shell 'settings get secure lockscreen.disabled')" = "1" ]; then
        LOCKSCREEN_WAS_DISABLED=1
    else
        LOCKSCREEN_WAS_DISABLED=0
    fi
    [ "$DRY_RUN" = "1" ] || save_state
    ok "recorded original state (home=$ORIGINAL_HOME systemui_disabled=$SYSTEMUI_WAS_DISABLED lockscreen_disabled=$LOCKSCREEN_WAS_DISABLED)"
}

install_systemui() {
    if [ "$SYSTEMUI_WAS_DISABLED" != "1" ]; then
        require_dry_run_ok "pm disable-user --user 0 $DAP_SYSTEMUI_PACKAGE"
        [ "$DRY_RUN" = "1" ] && return 0
        adb_shell "pm disable-user --user 0 $DAP_SYSTEMUI_PACKAGE" >/dev/null ||
            warn "could not disable $DAP_SYSTEMUI_PACKAGE"
        adb_shell "am force-stop $DAP_SYSTEMUI_PACKAGE" >/dev/null 2>&1 || true
    fi
    require_dry_run_ok "settings put secure lockscreen.disabled 1"
    [ "$DRY_RUN" = "1" ] && return 0
    adb_shell "settings put secure lockscreen.disabled 1" >/dev/null ||
        warn "could not set lockscreen.disabled"
}

apk_present() {
    [ -f "$APK_DIR/$1" ]
}

install_home() {
    player_apk=$APK_DIR/classipod.apk
    settings_apk=$APK_DIR/dapsettings.apk

    if apk_present classipod.apk; then
        require_dry_run_ok "adb install -r classipod.apk"
        if [ "$DRY_RUN" != "1" ]; then
            adb_do install -r "$player_apk" >/dev/null ||
                die "installing classipod.apk failed; if this is an existing DAP with a different signature, uninstall the old package first or use --no-apps"
            ok "installed player APK"
        fi
    else
        warn "classipod.apk not found in $APK_DIR; skipping player install"
    fi

    if apk_present dapsettings.apk; then
        require_dry_run_ok "adb install -r dapsettings.apk"
        if [ "$DRY_RUN" != "1" ]; then
            adb_do install -r "$settings_apk" >/dev/null ||
                die "installing dapsettings.apk failed; if this is an existing DAP with a different signature, uninstall the old package first or use --no-apps"
            ok "installed settings APK"
        fi
    else
        warn "dapsettings.apk not found in $APK_DIR; skipping settings install"
    fi

    require_dry_run_ok "cmd package set-home-activity $DAP_PLAYER_PACKAGE/$DAP_PLAYER_ACTIVITY"
    [ "$DRY_RUN" = "1" ] && return 0
    adb_shell "cmd package set-home-activity --user 0 $DAP_PLAYER_PACKAGE/$DAP_PLAYER_ACTIVITY" >/dev/null ||
        warn "could not set home activity; press Home to verify the player is the default"
    ok "home activity set"

    if apk_present dapsettings.apk; then
        for perm in ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION; do
            adb_shell "pm grant $DAP_SETTINGS_PACKAGE android.permission.$perm" >/dev/null 2>&1 || true
        done
        adb_shell "appops set $DAP_SETTINGS_PACKAGE SYSTEM_ALERT_WINDOW allow" >/dev/null 2>&1 ||
            warn "could not grant SYSTEM_ALERT_WINDOW (Android 7 may prompt on first launch)"
        adb_shell "appops set $DAP_SETTINGS_PACKAGE WRITE_SETTINGS allow" >/dev/null 2>&1 || true
        adb_shell "settings put secure location_mode 3" >/dev/null ||
            warn "could not enable location mode (needed for Wi-Fi scans on Android 7)"
    fi
}

install_doze() {
    require_dry_run_ok "dumpsys deviceidle whitelist +$DAP_PLAYER_PACKAGE +$DAP_SETTINGS_PACKAGE"
    [ "$DRY_RUN" = "1" ] && return 0
    adb_shell "dumpsys deviceidle whitelist +$DAP_PLAYER_PACKAGE" >/dev/null 2>&1 || true
    adb_shell "dumpsys deviceidle whitelist +$DAP_SETTINGS_PACKAGE" >/dev/null 2>&1 || true
}

restore_state() {
    [ "$DRY_RUN" = "1" ] && return 0
    if [ -n "${ORIGINAL_HOME:-}" ]; then
        adb_shell "cmd package set-home-activity --user 0 $ORIGINAL_HOME" >/dev/null ||
            warn "could not restore home activity ($ORIGINAL_HOME)"
    fi
    if [ "${SYSTEMUI_WAS_DISABLED:-0}" != "1" ]; then
        adb_shell "pm enable $DAP_SYSTEMUI_PACKAGE" >/dev/null ||
            warn "could not re-enable $DAP_SYSTEMUI_PACKAGE"
        adb_shell "am force-stop $DAP_SYSTEMUI_PACKAGE" >/dev/null 2>&1 || true
    fi
    if [ "${LOCKSCREEN_WAS_DISABLED:-0}" != "1" ]; then
        adb_shell "settings put secure lockscreen.disabled 0" >/dev/null || true
    fi
    rm -f "$(state_file)"
}

# ---------------------------------------------------------------------------
# orchestration
# ---------------------------------------------------------------------------

do_install() {
    require_adb
    require_root
    load_device "$DAP_DEVICE"
    DAP_BACKEND=$(detect_backend)

    sdk=$(device_sdk)
    if is_uint "$sdk"; then
        if [ "$sdk" -lt "$DAP_MIN_SDK" ] || [ "$sdk" -gt "$DAP_MAX_SDK" ]; then
            warn "SDK $sdk is outside the profile range $DAP_MIN_SDK-$DAP_MAX_SDK; continuing, but this device is unverified"
        fi
    fi

    info "device: $(device_prop ro.product.model) codename=$(device_codename) android=$(device_android) sdk=$sdk"
    info "profile: $DAP_DEVICE_CODENAME ($DAP_DEVICE_NAME)"
    info "backend: $DAP_BACKEND"
    info "modules: $MODULES"
    [ "$DRY_RUN" = "1" ] && warn "dry-run: no changes will be made"

    record_original_state
    prepare_staging

    if [ "$DAP_BACKEND" = "magisk" ]; then
        install_magisk_backend
    else
        install_system_backend
    fi

    module_available systemui && install_systemui
    module_available home && install_home
    module_available doze && install_doze

    ok "done (state saved to $(state_file))"
    say
    if [ "$DAP_BACKEND" = "system" ] || [ -n "${DAP_KEYLAYOUT_TARGET:-}" ]; then
        say "The keylayout and init files are read at boot. Reboot to complete the"
        say "installation:"
        say "  $ADB reboot"
    fi
    say
    say "Verify afterwards with:"
    say "  $0 doctor --device $DAP_DEVICE_CODENAME"
}

do_uninstall() {
    require_adb
    require_root
    load_device "$DAP_DEVICE"
    DAP_BACKEND=$(detect_backend)

    if ! confirm "Remove DAPify from $(device_prop ro.product.model)?"; then
        say "aborted"
        exit 0
    fi

    if [ "$DAP_BACKEND" = "magisk" ]; then
        uninstall_magisk_backend
    else
        uninstall_system_backend
    fi

    if load_state; then
        restore_state
        ok "restored original home/systemui state"
    else
        say
        say "No saved state found. If you need the stock UI back:"
        say "  $ADB shell pm enable $DAP_SYSTEMUI_PACKAGE"
        say "  $ADB shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME"
    fi

    if [ "$REMOVE_APPS" = "1" ]; then
        require_dry_run_ok "pm uninstall $DAP_PLAYER_PACKAGE $DAP_SETTINGS_PACKAGE"
        if [ "$DRY_RUN" != "1" ]; then
            adb_shell "pm uninstall $DAP_SETTINGS_PACKAGE" >/dev/null || true
            adb_shell "pm uninstall $DAP_PLAYER_PACKAGE" >/dev/null || true
            ok "removed apps"
        fi
    else
        say
        say "Apps left installed. Remove them with:"
        say "  $ADB shell pm uninstall $DAP_PLAYER_PACKAGE"
        say "  $ADB shell pm uninstall $DAP_SETTINGS_PACKAGE"
    fi

    say
    say "Reboot to finish: $ADB reboot"
}
