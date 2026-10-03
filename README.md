# Nunito Sans for Android 16

[Русский](README.ru.md) · [Releases](https://github.com/Doffi4/nunito-sans-oxygenos16/releases)

Systemless replacement of Android's generic `sans-serif` with Nunito. One ZIP per weight variant works with the module interfaces of **Magisk, APatch and KernelSU Next**. Targets Android 16 / OxygenOS 16 / ColorOS 16 with recognized font configurations.

## Variants

| ZIP | Android weight 400 |
| --- | --- |
| `Nunito_Sans_v1.2.0_Regular-400.zip` | Nunito axis 400 |
| `Nunito_Sans_v1.2.0_Slightly-Bolder-450.zip` | Nunito axis 450 |

Install **one** variant through your current root manager's Modules page, then reboot. Both use the same module ID, so switching variants updates the existing module. No root manager change is needed. Recovery installation is unsupported.

| Manager | Mount requirement |
| --- | --- |
| Magisk | Its normal module mounting must be enabled |
| APatch | APM mounting enabled; APatch 11219+ requires an enabled compatible mount metamodule |
| KernelSU Next | An enabled compatible mount metamodule is required |

KernelSU late-load is unsupported: it starts after system fonts have been cached. The module skips config generation in that mode and records the reason in its log.

## Scope and compatibility

Only generic `sans-serif` is replaced. OEM families (One Serif, OPlus Sans, OPPO Sans, `sys-sans-en`, `op-sans-en`), emoji, Noto fallback families, monospace and app-bundled fonts retain their definitions. OEM screens that explicitly request an OEM family can keep their original font.

The original upright and italic Nunito variable fonts support Cyrillic. Android weights 200–900 use matching Nunito axes, except weight 400 in the 450 variant. **Weight 900 uses Black, axis 900.** Nunito's actual minimum is 200, so requested weight 100 is approximated by ExtraLight 200; 100 and 200 cannot have distinct genuine Nunito instances.

OnePlus 13 `CPH2653_16.0.10.501(EX01)` configurations were read and checked offline. The archives have not been installed during this work. Magisk/APatch/KernelSU Next integration has been checked against official interfaces and local fixtures; this is not device runtime certification. **ColorOS 16 has not been tested on a device.**

## How it works

At installation, the script reads the current ROM's known configs. Magisk and normal-boot KernelSU regenerate them before module mounting; APatch keeps the install-prepared files because recent APatch mounts modules before their post-fs-data scripts:

```text
/system/etc/font_fallback.xml                 # Android 16 framework config
/system/etc/fonts.xml                         # legacy config
/system_ext/etc/fonts_base.xml                # observed OxygenOS config
/system_ext/etc/fonts_ule.xml                 # observed OxygenOS config
/product/etc/fonts_customization.xml          # AOSP OEM customization
```

It replaces the content of exactly one top-level `<family name="sans-serif">`, keeping its attributes and every byte outside that content. Missing, ambiguous and unsupported configs are skipped. Unknown OEM paths, `family-list`, aliases named `sans-serif` and locale-specific generic families require an audit; the module does not guess.

Generated XML stays inside the module's `system/` tree. Product customization gets matching Nunito files in the module's `system/product/fonts/`, because Android resolves that config from `/product/fonts/`. The root manager mounts these overlays; no command writes or remounts real `/system`, `/product` or `/vendor` partitions. Old configs are cleared when regeneration is safe. All logs and temporary files stay in the module directory.

**APatch updates:** disable Nunito and reboot before an OTA. After updating the ROM, reinstall Nunito while its old overlay is disabled, then enable/reboot. Use the same disable/reboot/reinstall procedure for module updates to ensure installation reads the original ROM view. The fingerprint check only logs a mismatch after mounting; it cannot prevent a stale XML from being mounted. This limitation follows the current [APatch boot order](https://github.com/bmax121/APatch/blob/11224/apd/src/event.rs).

## FontLoader credit

[FontLoader by JingMatrix](https://github.com/JingMatrix/FontLoader) supplies the companion font-preloading mechanism for apps that lose access to systemless font files. Thank you to JingMatrix for that project.

FontLoader is a separate, optional Zygisk module; this ZIP contains no Zygisk code. Nunito's config overlay is mounted by the root manager. Follow FontLoader's upstream usage instructions if using it; its behavior with Android 16 and each Zygisk implementation remains unverified here.

## Rollback and diagnostics

Disable/remove **Nunito Sans** in your current root manager and reboot to restore ROM fonts. The manager removes the module's overlay; no uninstall script is needed.

If boot fails, use your manager's rescue mode: [KernelSU](https://kernelsu.org/guide/rescue-from-bootloop.html), [APatch](https://apatch.dev/rescue-bootloop.html), [Magisk](https://topjohnwu.github.io/Magisk/faq.html). KernelSU normal-boot Safe Mode can be triggered by pressing/releasing Volume Down more than three times after the first boot screen; late-load does not offer this key detection.

If an authorized root shell is available, creating `/data/adb/modules/nunito_sans_ksu/disable` disables only this module at the next boot. A recovery shell needs access to decrypted `/data` to do the same. Do not wipe data or flash another boot image for a font-module rollback.

The current generation result is in `/data/adb/modules/nunito_sans_ksu/font-status.log`. Other font modules can override the same config, and hiding/unmounting root modules from an app can affect font access.

## Build and checks

PowerShell 7:

```powershell
./build.ps1 -RegularWeight 400
./build.ps1 -RegularWeight 450
```

Offline checks need Python 3, POSIX `sh` and AWK (Git Bash provides the latter two on Windows):

```sh
python tools/check.py --zip outputs/Nunito_Sans_v1.2.0_Regular-400.zip --zip outputs/Nunito_Sans_v1.2.0_Slightly-Bolder-450.zip
```

See [validation evidence and limits](docs/validation.md). The original [v1.0.0](https://github.com/Doffi4/nunito-sans-oxygenos16/releases/tag/v1.0.0) and [v1.1.0](https://github.com/Doffi4/nunito-sans-oxygenos16/releases/tag/v1.1.0) are the older KernelSU-only builds.

## Contact and font license

Telegram: [@doffi14](https://t.me/doffi14) · Email: [operagxyu@gmail.com](mailto:operagxyu@gmail.com)

Original fonts: [Google Fonts Nunito](https://github.com/google/fonts/tree/main/ofl/nunito), SIL Open Font License in [LICENSES/OFL.txt](LICENSES/OFL.txt).
