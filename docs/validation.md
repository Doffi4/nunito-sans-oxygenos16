# Validation — v1.2.0

Checked offline on Windows on 2026-10-03. No module installation, flashing or phone reboot was performed.

## Checked

- POSIX shell syntax using Git Bash `sh -n`; manager detection prioritizes APatch and KSU over Magisk compatibility markers.
- Installer gate fixtures cover Magisk, legacy/current APatch, KernelSU, missing mount providers, unsupported manager, late-load, API other than 36 and recovery mode. The installer fixture stubs the generator (its XML/filesystem behavior is checked separately).
- XML output parses with Python ElementTree. Comments, family attributes, aliases, emoji, fallback and every other byte outside generic-family content are preserved.
- All three saved OnePlus/OxygenOS configs pass the same comparison. The active font_fallback.xml was not captured locally; active-path/schema support is based on Android 16 AOSP and the earlier read-only device audit, not a local copy of that file.
- Missing/duplicate generic family, unsupported roots, family-list/alias, malformed nesting and product families without customizationType are rejected without output.
- Product fixture retains customizationType and gets unchanged font copies under the module's system/product/fonts. Original fixture XML remains unchanged.
- Stale overlay cleanup, missing payloads, late-load skip, invalid relative paths and symlinked destinations are exercised locally. APatch boot preserves install-prepared XML bytes/inodes and logs fingerprint mismatch without touching mounted configs.
- Both 400/450 builds contain the exact package allowlist, original font binaries, UTF-8 scripts/config without BOM or CRLF, and Unix 0755 scripts / 0644 data.
- Both original VFs have a wght axis 200–1000. Upright/italic each contain Russian alphabet including Ё/ё and Ukrainian Є/І/Ї/Ґ pairs. Weight generation checks all 18 normal/italic mappings, including 900 → 900 and 100 → 200.

## Evidence boundaries

Local tests run desktop `sh`/GNU AWK, not Android BusyBox or a root manager. SELinux/chown are stubbed only in the desktop product fixture. Their real behavior, font access in app namespaces, FontLoader, font updates in /data, SystemUI startup and actual mount ordering remain device validation items.

No Magisk/APatch device or ColorOS 16 device was used. Recognized Android config paths provide an integration target, not a promise that every OEM screen selects generic sans-serif.

APatch 11224 source mounts modules before their post-fs-data scripts, contrary to the older guide text. Its mount provider is required; 11219 introduced the metamodule architecture. Nunito uses install-time preparation for all APatch versions and requires disable/reboot/reinstall from the original ROM view after OTA or module updates. A post-mount fingerprint log cannot prevent a stale overlay from mounting.

## Reproduce

```powershell
./build.ps1 -RegularWeight 400
./build.ps1 -RegularWeight 450
python tools/check.py --awk 'C:/Program Files/Git/usr/bin/awk.exe' --shell 'C:/Program Files/Git/bin/sh.exe' --zip outputs/Nunito_Sans_v1.2.0_Regular-400.zip --zip outputs/Nunito_Sans_v1.2.0_Slightly-Bolder-450.zip
```

Optional private fixture directory: `--device-configs work/device-configs`. Private ROM snapshots are excluded from Git and module ZIPs.

## Primary references

- [Magisk module format, partition mapping and boot stages](https://topjohnwu.github.io/Magisk/guides.html)
- [APatch modules and environment markers](https://apatch.dev/apm-guide.html)
- [APatch 11224 boot order](https://github.com/bmax121/APatch/blob/11224/apd/src/event.rs)
- [APatch 11224 mount provider](https://github.com/bmax121/APatch/blob/11224/apd/src/metamodule.rs)
- [KernelSU Next metamodule and late-load semantics](https://github.com/KernelSU-Next/KernelSU-Next/blob/dev/website/docs/guide/metamodule.md)
- [Android 16 SystemFonts config/font directories](https://android.googlesource.com/platform/frameworks/base/+/android16-release/graphics/java/android/graphics/fonts/SystemFonts.java)
- [Android 16 FontListParser](https://android.googlesource.com/platform/frameworks/base/+/android16-release/graphics/java/android/graphics/FontListParser.java)
- [Android 16 FontCustomizationParser](https://android.googlesource.com/platform/frameworks/base/+/android16-release/graphics/java/android/graphics/fonts/FontCustomizationParser.java)
- [FontLoader by JingMatrix](https://github.com/JingMatrix/FontLoader)
