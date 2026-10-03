#!/system/bin/sh
# Generate overlays from the current ROM configs before KernelSU mounts modules.
# All writes stay inside this module directory; no real system partition is changed.

MODDIR="${0%/*}"
LOG_TAG="NunitoSans"
FAMILY_BLOCK="$MODDIR/.nunito-sans-family.xml"
INPUT_FILE="$MODDIR/.nunito-sans-input.xml"
TEMP_FILE="$MODDIR/.nunito-sans-output.xml"

log_info() { log -t "$LOG_TAG" -p i "$*" 2>/dev/null; }
log_warn() { log -t "$LOG_TAG" -p w "$*" 2>/dev/null; }

write_family_block() {
    cat > "$FAMILY_BLOCK" <<'EOF'
<family name="sans-serif">
    <font weight="100" style="normal">Nunito-VF.ttf
        <axis tag="wght" stylevalue="200" />
    </font>
    <font weight="200" style="normal">Nunito-VF.ttf
        <axis tag="wght" stylevalue="200" />
    </font>
    <font weight="300" style="normal">Nunito-VF.ttf
        <axis tag="wght" stylevalue="300" />
    </font>
    <font weight="400" style="normal">Nunito-VF.ttf
        <axis tag="wght" stylevalue="450" />
    </font>
    <font weight="500" style="normal">Nunito-VF.ttf
        <axis tag="wght" stylevalue="500" />
    </font>
    <font weight="600" style="normal">Nunito-VF.ttf
        <axis tag="wght" stylevalue="600" />
    </font>
    <font weight="700" style="normal">Nunito-VF.ttf
        <axis tag="wght" stylevalue="700" />
    </font>
    <font weight="800" style="normal">Nunito-VF.ttf
        <axis tag="wght" stylevalue="800" />
    </font>
    <font weight="900" style="normal">Nunito-VF.ttf
        <axis tag="wght" stylevalue="900" />
    </font>
    <font weight="100" style="italic">Nunito-Italic-VF.ttf
        <axis tag="wght" stylevalue="200" />
    </font>
    <font weight="200" style="italic">Nunito-Italic-VF.ttf
        <axis tag="wght" stylevalue="200" />
    </font>
    <font weight="300" style="italic">Nunito-Italic-VF.ttf
        <axis tag="wght" stylevalue="300" />
    </font>
    <font weight="400" style="italic">Nunito-Italic-VF.ttf
        <axis tag="wght" stylevalue="450" />
    </font>
    <font weight="500" style="italic">Nunito-Italic-VF.ttf
        <axis tag="wght" stylevalue="500" />
    </font>
    <font weight="600" style="italic">Nunito-Italic-VF.ttf
        <axis tag="wght" stylevalue="600" />
    </font>
    <font weight="700" style="italic">Nunito-Italic-VF.ttf
        <axis tag="wght" stylevalue="700" />
    </font>
    <font weight="800" style="italic">Nunito-Italic-VF.ttf
        <axis tag="wght" stylevalue="800" />
    </font>
    <font weight="900" style="italic">Nunito-Italic-VF.ttf
        <axis tag="wght" stylevalue="900" />
    </font>
</family>
EOF
}

patch_config() {
    source_file="$1"
    relative_path="$2"
    destination="$MODDIR/$relative_path"
    destination_dir="${destination%/*}"

    if [ ! -f "$source_file" ]; then
        log_warn "Skipped missing ROM config: $source_file"
        return 0
    fi

    rm -f "$destination" "$destination.tmp" "$INPUT_FILE" "$TEMP_FILE"
    mkdir -p "$destination_dir" || {
        log_warn "Could not create module overlay directory for $source_file"
        return 1
    }
    cp "$source_file" "$INPUT_FILE" || {
        log_warn "Could not read ROM config: $source_file"
        rm -f "$INPUT_FILE"
        return 1
    }

    awk -v replacement_file="$FAMILY_BLOCK" \
        -f "$MODDIR/tools/patch-sans-family.awk" "$INPUT_FILE" > "$TEMP_FILE" || {
        log_warn "No unique sans-serif family found; left $source_file unchanged"
        rm -f "$INPUT_FILE" "$TEMP_FILE"
        return 1
    }

    chown 0:0 "$TEMP_FILE" 2>/dev/null
    chmod 0644 "$TEMP_FILE" 2>/dev/null
    chcon u:object_r:system_file:s0 "$destination_dir" "$TEMP_FILE" 2>/dev/null || {
        log_warn "Could not set system_file SELinux context for $source_file"
        rm -f "$INPUT_FILE" "$TEMP_FILE"
        return 1
    }
    mv -f "$TEMP_FILE" "$destination" || {
        log_warn "Could not finalize overlay for $source_file"
        rm -f "$INPUT_FILE" "$TEMP_FILE"
        return 1
    }

    rm -f "$INPUT_FILE"
    log_info "Prepared systemless sans-serif config: $source_file"
    return 0
}

if [ ! -f "$MODDIR/system/fonts/Nunito-VF.ttf" ] || [ ! -f "$MODDIR/system/fonts/Nunito-Italic-VF.ttf" ]; then
    log_warn "Nunito font files are missing; config overlays were not generated"
    exit 0
fi
if [ ! -f "$MODDIR/tools/patch-sans-family.awk" ]; then
    log_warn "XML patch helper is missing; config overlays were not generated"
    exit 0
fi

write_family_block || exit 0
patch_config /system/etc/font_fallback.xml system/etc/font_fallback.xml
patch_config /system/etc/fonts.xml system/etc/fonts.xml
patch_config /system_ext/etc/fonts_base.xml system/system_ext/etc/fonts_base.xml
patch_config /system_ext/etc/fonts_ule.xml system/system_ext/etc/fonts_ule.xml
rm -f "$FAMILY_BLOCK" "$INPUT_FILE" "$TEMP_FILE"
