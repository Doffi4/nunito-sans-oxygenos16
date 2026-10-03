# Cross-manager Nunito module for Android 16

Status: approved direction; implementation refined using pinned upstream sources

## Goal

Extend the existing Nunito systemless module to one ZIP installable through Magisk, APatch, and KernelSU Next on Android 16. Support OxygenOS 16 and ColorOS 16 where the ROM exposes a recognized Android font configuration. The module changes only the generic `sans-serif` family.

## User-visible boundaries

- Preserve OEM-named families such as One Serif, OPlus Sans, and OPPO Sans.
- Preserve emoji, Noto and other fallback families, monospace, and app-bundled fonts.
- Keep the existing Nunito variable-font weight mapping, including the 450 regular option and weight 900 at `wght=900`.
- Do not write to real system partitions. Create module-owned overlays before the root manager mounts modules.
- Do not claim every OOS/ColorOS device is verified: expose manager support and ROM validation separately in documentation.
- Continue to install through a root manager, never recovery.

## Root-manager integration

Use the common Android module ZIP layout and shared shell helper. Detect APatch via its `APATCH` marker before considering Magisk compatibility variables. KernelSU Next requires its active mount metamodule. APatch 11219+ also requires its own compatible mount metamodule. Magisk supplies its own mount mechanism.

Prepare initial overlays during installation. Magisk and normal KernelSU boot regenerate overlays in pre-mount post-fs-data. APatch retains installation-prepared overlays: pinned APatch 11224 mounts modules before module post-fs-data, contradicting its older guide. APatch must be disabled before OTA and reinstalled from the original ROM view after OTA/module updates. A fingerprint log cannot prevent a stale config already mounted. KernelSU late-load starts after font caching; its wrapper only clears stale overlays and logs that early boot is required. Unsupported manager, API, recovery or installation in late-load fails clearly.

## ROM font-config handling

The algorithm reads the ROM configuration at install and safe pre-mount regeneration stages. Targets are Android 16 active `/system/etc/font_fallback.xml`, legacy `/system/etc/fonts.xml`, observed `/system_ext/etc/fonts_base.xml` and `fonts_ule.xml`, and AOSP `/product/etc/fonts_customization.xml`. Unknown XML paths are skipped because their loader/font directory is unverified. Emit an overlay only for one supported top-level named sans-serif family; preserve its opening attributes and every byte outside its content. Family-list, alias replacements, locale-specific generic families and ambiguity are refused.

Map configs into the root-manager module tree (`system/`, `system/system_ext/`, `system/product/`). Stage additional original Nunito files in module-owned system/product/fonts only when a safe product override is generated. Do not replace raw OEM fonts under paths such as /my_product/fonts. If no safe target is found at install, abort; at boot, log and retain original ROM behavior.

## Packaging and docs

Keep a single source and one build script. Update module metadata and bilingual READMEs with the three manager installation paths, the KernelSU metamodule prerequisite, supported Android API level, known OOS configuration evidence, and ColorOS validation caveat. Link the FontLoader project as an optional separate module; do not make it a dependency or imply it provides the system overlay.

## Validation contract

Before preparing a new public release, statically check the module ZIP contents, Unix file modes, shell syntax, manager detection and failure messages, partition-to-module path mapping, and that generated XML replaces only the generic family while preserving the rest. Verify each public download target and checksum. Runtime rendering and boot behavior remain unverified until exercised on devices running the relevant root managers and OOS/ColorOS builds.

## Risks and constraints

- Android 16 releases can move or regenerate OEM font configuration. Unknown files must be skipped, not guessed.
- Other font modules may target the same generic family; mount precedence can decide which one wins.
- Apps or OEM components that explicitly request private font families will keep those fonts by design.
- A ColorOS 16 device/config dump is still needed to claim tested ColorOS compatibility.
