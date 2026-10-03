# Changelog

## [1.2.0] - Cross-manager

- One ZIP per weight variant, installable in Magisk, APatch or KernelSU Next.
- Keep the original module ID; install one variant at a time.
- Patch known Android 16/OxygenOS font configs and product customization only when a unique generic family is recognized.
- Preserve family attributes and every byte outside its content, including comments, aliases and fallback families.
- Prepare /product/fonts overlays only for a recognized product generic-family override.
- Generate initial overlays at install; Magisk/KSU regenerate before mounts. APatch retains installed overlays and requires disable/reinstall around OTA because its new mount stage precedes module scripts.
- Check mount providers for KernelSU and APatch 11219+; reject symlinked destinations and unsupported XML.
- Record results in module-owned font-status.log.
- Skip KSU late-load: this module requires execution before Zygote font caching.
- ColorOS 16 and other manager runtime behavior still require device testing.

## [1.1.0] — Slightly Bolder 450

- Set Nunito's `wght` axis to 450 for Android weight 400 (regular and italic).
- Kept all other weight mappings, including weight 900 → Nunito Black.

## [1.0.0] — Regular 400

- Initial KernelSU Next systemless `sans-serif` overlay for Android 16 / OxygenOS 16.
- Android weight 400 uses Nunito `wght=400`; weight 900 remains Nunito Black.
