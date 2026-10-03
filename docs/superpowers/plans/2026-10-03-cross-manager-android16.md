# Cross-manager Nunito implementation plan

> **For agentic workers:** Implement in this session using the approved design. Track checks below. Do not install on a device.

**Goal:** Produce one manager-independent ZIP per existing weight variant for Android 16.

**Architecture:** Keep the existing module ID and original Nunito VFs. Share the boot generator between the standard entry point and the KernelSU late-load entry point. Patch only an unambiguous top-level generic family in known Android/OOS XML files, preserving its opening tag and all other bytes.

**Tech stack:** POSIX shell, BusyBox-compatible AWK, PowerShell ZIP builder, Python offline checks.

**Spec:** ../specs/2026-10-03-cross-manager-android16-design.md

## Global constraints

- API 36; manager installation only; Magisk/APatch/KernelSU Next.
- APatch detection precedes Magisk compatibility markers; KSU requires a mount provider.
- All runtime writes remain in the module directory. No partition remounts or global boot scripts.
- Only generic sans-serif; preserve OEM families, aliases, Noto, emoji, monospace and bundled app fonts.
- Keep 400 and 450 regular variants; requested 900 maps to axis 900. Requested 100 maps to axis 200, the minimum supported by the original font.
- Runtime compatibility remains unverified without separately authorized device tests.

## Review focus

- Commented examples and duplicate/unsupported generic families must never produce a partial overlay.
- OEM product customization must retain customizationType and resolve fonts in /product/fonts.
- Stale generated configs must be removed before regeneration after an OTA or a failed check.
- Symlinked module destinations must never cause writes outside the module directory.
- Late-load happens after Zygote startup; it cannot safely promise a system-wide font change.

## Task 1: Installer and guarded XML generator

Files: customize.sh, post-fs-data.sh, late-load.sh, tools/prepare-fonts.sh, tools/root-manager.sh, tools/patch-sans-family.awk, nunito.conf, tools/check.py.

- [ ] Add offline fixtures for preserved comments/attributes/fallbacks, duplicate or missing generic family, malformed and unsupported structures.
- [ ] Run them against the original helper and record expected failures.
- [ ] Implement manager detection and manager/API/recovery gates.
- [ ] Replace only the content of a unique top-level named family; reject unfamiliar structures.
- [ ] Generate only known framework/OOS paths and the AOSP product customization path; skip unknown OEM paths because their loader/font directory is unverified.
- [ ] Stage product font copies only when a safe product generic overlay is generated.
- [ ] Remove stale overlays on every invocation; guard directory/file symlinks; log results to module-owned font-status.log.
- [ ] In KSU late-load, clean stale overlays and report that normal early boot is required; do not attempt cached font reloads.
- [ ] Check shell syntax, fixture XML and installer failure cases locally.

## Task 2: Packaging and documentation

Files: build.ps1, module.prop, README.md, README.ru.md, CHANGELOG.md, docs/validation.md.

- [ ] Build v1.2.0 Regular 400 and Slightly Bolder 450 from one source using a build parameter.
- [ ] Verify ZIP allowlist, LF/no BOM, Unix modes, both font payloads, Cyrillic coverage and 18 weight/style mappings.
- [ ] Document manager prerequisites, actual FontLoader purpose/upstream link, OOS evidence, ColorOS uncertainty and manager-specific rollback.
- [ ] Keep the original v1.0.0/v1.1.0 release artifacts intact.
- [ ] Review the resulting change and record final checks and limitations.

## Implementation decisions

The approved broad XML discovery is narrowed to known loader paths: finding an XML does not establish that Android loads it or which font directory it uses. AOSP confirms product customization uses /product/fonts and requires customizationType. KernelSU Next documents that late-load occurs after the system has fully booted; font caches make that mode unsuitable for this early-boot replacement. These decisions reduce unsupported behavior rather than adding speculative compatibility.

Git metadata for the previously published source is work/publish-meta/.git, not the empty top-level .git. Preserve its history.

APatch reviewer finding: pinned release 11224 mounts before module post-fs-data. Resolved with install-time generation for all APatch versions, no post-mount inode replacement, fingerprint diagnostics and explicit disable-before-OTA/reinstall instructions. APatch 11219+ mount provider is checked. Initial install-time generation is shared by all managers; Magisk/KSU still regenerate before mounts.

Checks: XML edge-case tests first failed on the original line helper, then passed with the conservative scanner. Attribute-value text was covered by a new failing regression and a lexical attribute reader. Installer, mount marker, product staging, stale cleanup, symlink, weight, font payload and ZIP cases are covered in tools/check.py. Independent review found the APatch issue above; it has been fixed and covered by an inode-preservation regression.
