#!/system/bin/sh

[ "${BOOTMODE:-false}" = true ] || abort "Install in Magisk, APatch or KernelSU Next Manager; recovery installation is unsupported."
[ "${API:-0}" = 36 ] || abort "Android 16 (API 36) is required; detected API ${API:-unknown}."

for required_file in tools/root-manager.sh tools/prepare-fonts.sh tools/patch-sans-family.awk nunito.conf system/fonts/Nunito-VF.ttf system/fonts/Nunito-Italic-VF.ttf; do
    [ -f "$MODPATH/$required_file" ] || abort "Required module file missing: $required_file"
done
. "$MODPATH/tools/root-manager.sh"
detect_root_manager || abort "Unsupported root manager; use Magisk, APatch or KernelSU Next."

if [ "$ROOT_MANAGER" = KernelSU ]; then
    mount_provider_ready || abort "KernelSU requires an enabled compatible metamodule to mount systemless overlays."
    [ "${KSU_LATE_LOAD:-0}" != 1 ] && [ "${KSU_RUNTIME_MODE:-}" != late-load ] || abort "This font module requires early-boot KernelSU; late-load starts after fonts are cached."
elif [ "$ROOT_MANAGER" = APatch ]; then
    case "${APATCH_VER_CODE:-}" in
        ''|*[!0-9]*) abort "Cannot determine APatch version/mount requirements." ;;
    esac
    if [ "$APATCH_VER_CODE" -ge 11219 ]; then
        mount_provider_ready || abort "APatch 11219+ requires an enabled compatible mount metamodule."
    fi
fi

if [ ! -r /system/etc/font_fallback.xml ] && [ ! -r /system/etc/fonts.xml ] && [ ! -r /product/etc/fonts_customization.xml ]; then
    abort "No known readable Android font configuration; this ROM needs a separate read-only audit."
fi

set_perm_recursive "$MODPATH/system" 0 0 0755 0644 u:object_r:system_file:s0
for script in post-fs-data.sh late-load.sh tools/prepare-fonts.sh tools/root-manager.sh; do
    set_perm "$MODPATH/$script" 0 0 0755
done
MODDIR="$MODPATH"
. "$MODPATH/tools/prepare-fonts.sh"
prepare_fonts install
[ "${applied:-0}" -gt 0 ] || abort "No safely supported generic sans-serif family was found; this ROM needs a font-config audit."
[ ! -L "$MODPATH/.nunito-install-state" ] || abort "Unsafe module state path."
printf 'manager=%s\nfingerprint=%s\n' "$ROOT_MANAGER" "$(getprop ro.build.fingerprint)" > "$MODPATH/.nunito-install-state" || abort "Could not save module state."
set_perm "$MODPATH/.nunito-install-state" 0 0 0600
ui_print "Nunito Sans: $ROOT_MANAGER / Android 16."
ui_print "Only generic sans-serif is replaced; OEM font styles retain their fonts."
if [ "$ROOT_MANAGER" = APatch ]; then
    ui_print "Configs prepared at install. Disable before OTA; rebuild after OTA from the original ROM view."
else
    ui_print "Configs are regenerated before mounts on normal boot."
fi
