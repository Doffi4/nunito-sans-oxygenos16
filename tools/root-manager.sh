#!/system/bin/sh

detect_root_manager() {
    ROOT_MANAGER=
    if [ "${APATCH:-false}" = true ]; then
        ROOT_MANAGER=APatch
    elif [ "${KSU:-false}" = true ]; then
        ROOT_MANAGER=KernelSU
    else
        case "${MAGISK_VER_CODE:-}" in
            ''|*[!0-9]*) return 1 ;;
            *) [ "$MAGISK_VER_CODE" -gt 0 ] || return 1 ;;
        esac
        ROOT_MANAGER=Magisk
    fi
}

mount_provider_ready() {
    # Optional argument used by offline checks; installation uses the default.
    metamodule_dir="${1:-/data/adb/metamodule}"
    [ -f "$metamodule_dir/module.prop" ] &&
        [ -f "$metamodule_dir/metamount.sh" ] &&
        [ ! -e "$metamodule_dir/disable" ] &&
        [ ! -e "$metamodule_dir/remove" ] &&
        grep -Eq '^metamodule=(1|true)$' "$metamodule_dir/module.prop"
}
