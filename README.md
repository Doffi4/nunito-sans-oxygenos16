# Nunito Sans for OxygenOS 16

A systemless KernelSU Next module that maps Android `sans-serif` to Nunito on the OnePlus 13 (`CPH2653`, Android 16 / OxygenOS 16).

## Download

- [v1.1.0 — Slightly Bolder 450](https://github.com/Doffi4/nunito-sans-oxygenos16/releases/tag/v1.1.0): Nunito `wght=450` for Android weight 400.
- [v1.0.0 — Regular 400](https://github.com/Doffi4/nunito-sans-oxygenos16/releases/tag/v1.0.0): Nunito `wght=400` for Android weight 400.

Install the ZIP in KernelSU Next → **Modules** → **Install from storage**. An active KernelSU metamodule is required. This ZIP is not for recovery flashing.

## What it changes

The module overlays the ROM font configuration and replaces only the `sans-serif` family. In v1.1.0, Android weight 400 uses `wght=450` for slightly denser regular text; v1.0.0 uses `wght=400`. Emoji, Noto fallback fonts, monospace, OEM-specific families and fonts bundled by apps are left alone. Nunito’s original font files are included under the SIL Open Font License; Android weight 100 maps to ExtraLight (`wght=200`) because Nunito has no 100 instance. Weight 900 maps to Black (`wght=900`).

## FontLoader

[FontLoader by JingMatrix](https://github.com/JingMatrix/FontLoader) is a separate, optional Zygisk module. Its upstream project describes preloading fonts for apps that lose access to module font files. This module does not bundle or depend on FontLoader: the system overlay is provided by the KernelSU metamodule. FontLoader compatibility with KernelSU Next and this OxygenOS build has not been verified.

## Remove / recovery

Disable or remove the module in KernelSU Next and reboot. If Android does not finish booting, use KernelSU Safe Mode to disable modules, then remove this one. No real system partition is modified.

## Verification

The target ROM’s font configuration was read from a OnePlus 13 running `CPH2653_16.0.10.501(EX01)`. The ZIP and XML-generation scripts were checked locally. The module has not been installed on the phone, so post-boot rendering and SystemUI compatibility are unverified.

## Contact

Telegram: [@doffi14](https://t.me/doffi14) · Email: [operagxyu@gmail.com](mailto:operagxyu@gmail.com)

Nunito font files and license: [Google Fonts — Nunito](https://github.com/google/fonts/tree/main/ofl/nunito), `LICENSES/OFL.txt`.
