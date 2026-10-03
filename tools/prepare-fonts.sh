#!/system/bin/sh
# Called by installation or supported boot stages. Writes stay in the module.

nunito_log() {
    printf '%s\n' "$*" >> "$MODDIR/font-status.log"
    log -t NunitoSans -p i "$*" 2>/dev/null || :
}

safe_module_path() {
    case "$1" in system/*) ;; *) return 1 ;; esac
    case "/$1/" in *'/../'*|*'/./'*|*'//'*) return 1 ;; esac
    safe_check="$MODDIR/$1"
    while [ "$safe_check" != "$MODDIR" ]; do
        [ ! -L "$safe_check" ] || return 1
        safe_check="${safe_check%/*}"
    done
    [ ! -L "$MODDIR" ]
}

ensure_module_directory() {
    safe_module_path "$1" || return 1
    mkdir -p "$MODDIR/$1" || return 1
    current_dir="$MODDIR/$1"
    while [ "$current_dir" != "$MODDIR" ]; do
        chown 0:0 "$current_dir" && chmod 0755 "$current_dir" &&
            chcon u:object_r:system_file:s0 "$current_dir" || return 1
        current_dir="${current_dir%/*}"
    done
}

clear_generated_overlays() {
    for relative in system/etc/font_fallback.xml system/etc/fonts.xml system/system_ext/etc/fonts_base.xml system/system_ext/etc/fonts_ule.xml system/product/etc/fonts_customization.xml system/product/fonts/Nunito-VF.ttf system/product/fonts/Nunito-Italic-VF.ttf; do
        safe_module_path "$relative" || return 1
        rm -f "$MODDIR/$relative" "$MODDIR/$relative.tmp" || return 1
    done
}

write_font_content() {
    printf '\n'
    for style in normal italic; do
        if [ "$style" = normal ]; then font=Nunito-VF.ttf; else font=Nunito-Italic-VF.ttf; fi
        for weight in 100 200 300 400 500 600 700 800 900; do
            axis_weight="$weight"
            case "$weight" in 100) axis_weight=200 ;; 400) axis_weight="$regular_weight" ;; esac
            printf '    <font weight="%s" style="%s">%s\n        <axis tag="wght" stylevalue="%s" />\n    </font>\n' "$weight" "$style" "$font" "$axis_weight"
        done
    done
}

stage_product_fonts() {
    ensure_module_directory system/product/fonts || return 1
    for filename in Nunito-VF.ttf Nunito-Italic-VF.ttf; do
        safe_module_path "system/product/fonts/$filename" || return 1
        cp "$MODDIR/system/fonts/$filename" "$MODDIR/system/product/fonts/$filename" &&
            chown 0:0 "$MODDIR/system/product/fonts/$filename" &&
            chmod 0644 "$MODDIR/system/product/fonts/$filename" &&
            chcon u:object_r:system_file:s0 "$MODDIR/system/product/fonts/$filename" || return 1
    done
}

patch_config() {
    source_file="$1"
    relative="$2"
    [ -f "$source_file" ] && [ -r "$source_file" ] || { nunito_log "Skipped missing/unreadable: $source_file"; return 1; }
    safe_module_path "$relative" && safe_module_path "$relative.tmp" || return 1
    ensure_module_directory "${relative%/*}" || return 1
    destination="$MODDIR/$relative"
    if ! awk -v replacement_file="$MODDIR/.nunito-content.xml" -f "$MODDIR/tools/patch-sans-family.awk" "$source_file" > "$destination.tmp"; then
        rm -f "$destination.tmp"
        nunito_log "Skipped ambiguous, absent or unsupported generic family: $source_file"
        return 1
    fi
    if [ "$relative" = system/product/etc/fonts_customization.xml ]; then
        if ! stage_product_fonts; then
            rm -f "$destination.tmp"
            nunito_log "Could not prepare product font files; skipped $source_file"
            return 1
        fi
    fi
    if ! { chown 0:0 "$destination.tmp" && chmod 0644 "$destination.tmp" && chcon u:object_r:system_file:s0 "$destination.tmp" && mv -f "$destination.tmp" "$destination"; }; then
        rm -f "$destination.tmp"
        nunito_log "Could not finalize module overlay: $source_file"
        return 1
    fi
    nunito_log "Prepared: $source_file"
}

prepare_fonts() {
    [ -n "$MODDIR" ] && [ -d "$MODDIR" ] && [ ! -L "$MODDIR" ] || return 0
    [ ! -L "$MODDIR/font-status.log" ] && [ ! -L "$MODDIR/.nunito-content.xml" ] || return 0
    : > "$MODDIR/font-status.log" || return 0
    chmod 0600 "$MODDIR/font-status.log"
    installed_manager="$(sed -n 's/^manager=//p' "$MODDIR/.nunito-install-state" 2>/dev/null)"
    if [ "${1:-boot}" != install ] && { [ "${APATCH:-false}" = true ] || [ "$installed_manager" = APatch ]; }; then
        # Modern APatch has already mounted modules; never replace/clear inodes.
        installed_fingerprint="$(sed -n 's/^fingerprint=//p' "$MODDIR/.nunito-install-state" 2>/dev/null)"
        current_fingerprint="$(getprop ro.build.fingerprint)"
        if [ -n "$installed_fingerprint" ] && [ "$installed_fingerprint" = "$current_fingerprint" ]; then
            nunito_log "APatch: using install-prepared configs; no post-mount regeneration."
        else
            nunito_log "APatch: ROM fingerprint changed/unknown. Rebuild from the original ROM configs: disable, reboot, reinstall."
        fi
        return 0
    fi
    clear_generated_overlays || { nunito_log "Unsafe/unwritable overlay paths; skipped generation"; return 0; }
    if [ "${KSU_LATE_LOAD:-0}" = 1 ]; then
        nunito_log "Late-load is unsupported: system fonts are already cached. An early-boot root setup is required."
        return 0
    fi
    for relative in system/fonts/Nunito-VF.ttf system/fonts/Nunito-Italic-VF.ttf; do
        safe_module_path "$relative" && [ -s "$MODDIR/$relative" ] || { nunito_log "Missing/unsafe Nunito font files; no overlays generated"; return 0; }
    done
    [ -f "$MODDIR/tools/patch-sans-family.awk" ] && [ -f "$MODDIR/nunito.conf" ] || return 0
    regular_weight="$(sed -n 's/^regular_weight=//p' "$MODDIR/nunito.conf")"
    case "$regular_weight" in 400|450) ;; *) nunito_log "Invalid regular weight; no overlays generated"; return 0 ;; esac
    write_font_content > "$MODDIR/.nunito-content.xml" || return 0
    applied=0
    patch_config /system/etc/font_fallback.xml system/etc/font_fallback.xml && applied=$((applied + 1))
    patch_config /system/etc/fonts.xml system/etc/fonts.xml && applied=$((applied + 1))
    patch_config /system_ext/etc/fonts_base.xml system/system_ext/etc/fonts_base.xml && applied=$((applied + 1))
    patch_config /system_ext/etc/fonts_ule.xml system/system_ext/etc/fonts_ule.xml && applied=$((applied + 1))
    patch_config /product/etc/fonts_customization.xml system/product/etc/fonts_customization.xml && applied=$((applied + 1))
    rm -f "$MODDIR/.nunito-content.xml"
    nunito_log "Prepared $applied config(s), regular axis $regular_weight. Unknown OEM paths are not patched."
    return 0
}
