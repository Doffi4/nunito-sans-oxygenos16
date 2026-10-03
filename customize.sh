#!/system/bin/sh

if [ "${KSU:-false}" != "true" ]; then
    abort "Install this ZIP from KernelSU Next Manager. It is not a recovery ZIP."
fi

if [ "${API:-0}" -ne 36 ]; then
    abort "This build targets Android 16 (API 36); detected API ${API:-unknown}."
fi

if [ ! -f /data/adb/metamodule/module.prop ]; then
    abort "A KernelSU metamodule is required to mount systemless font/config overlays. Install a compatible metamodule, then retry."
fi

if ! grep -Eq '^metamodule=(1|true)$' /data/adb/metamodule/module.prop; then
    abort "The active KernelSU mount provider is not marked as a metamodule."
fi

if [ ! -f "$MODPATH/system/fonts/Nunito-VF.ttf" ] || [ ! -f "$MODPATH/system/fonts/Nunito-Italic-VF.ttf" ]; then
    abort "Nunito variable font files are missing from this ZIP."
fi
if [ ! -f "$MODPATH/tools/patch-sans-family.awk" ]; then
    abort "The XML patch helper is missing from this ZIP."
fi

if [ ! -f /system/etc/font_fallback.xml ]; then
    abort "Android's active /system/etc/font_fallback.xml was not found; refusing an incomplete install."
fi

set_perm_recursive "$MODPATH/system/fonts" 0 0 0755 0644 u:object_r:system_file:s0
ui_print "Nunito Sans: module files checked. XML overlays are prepared at boot."
