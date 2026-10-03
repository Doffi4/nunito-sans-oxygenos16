#!/system/bin/sh
MODDIR="${0%/*}"
. "$MODDIR/tools/prepare-fonts.sh"
# Zygote has already cached fonts. Clean old overlays without a live reload.
KSU_LATE_LOAD=1
prepare_fonts
