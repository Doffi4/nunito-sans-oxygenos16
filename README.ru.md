# Nunito Sans для OxygenOS 16

Systemless-модуль KernelSU Next, который назначает Nunito семейству Android `sans-serif` на OnePlus 13 (`CPH2653`, Android 16 / OxygenOS 16).

## Скачать

- [v1.0.0 — Regular 400](https://github.com/Doffi4/nunito-sans-oxygenos16/releases/tag/v1.0.0): для Android-веса 400 используется Nunito `wght=400`.

Установи ZIP через KernelSU Next → **Modules** → **Install from storage**. Нужен активный KernelSU metamodule. ZIP не предназначен для прошивки из recovery.

## Что меняется

Модуль создаёт overlay конфигурации ROM и заменяет только семейство `sans-serif`. Emoji, Noto fallback, monospace, отдельные OEM-семейства и встроенные в приложения шрифты остаются без изменений. Файлы Nunito распространяются по SIL Open Font License. Так как у Nunito нет веса 100, он отображается ближайшим ExtraLight (`wght=200`). Вес 900 — Black (`wght=900`).

## FontLoader

[FontLoader от JingMatrix](https://github.com/JingMatrix/FontLoader) — отдельный необязательный Zygisk-модуль. В upstream он описан как способ предварительно загрузить шрифты для приложений, теряющих доступ к файлам модулей. Этот модуль не включает FontLoader и не зависит от него: system overlay предоставляет KernelSU metamodule. Совместимость FontLoader с KernelSU Next и этой сборкой OxygenOS не проверялась.

## Откат

Отключи или удали модуль в KernelSU Next и перезагрузи телефон. Если Android не загружается, используй KernelSU Safe Mode, отключи модули и удали этот. Реальные системные разделы не изменяются.

## Проверка

Конфигурация целевой ROM прочитана с OnePlus 13 на `CPH2653_16.0.10.501(EX01)`. ZIP и XML-скрипты проверены локально. Модуль не устанавливался на телефон, поэтому работу после загрузки и совместимость с SystemUI нельзя считать проверенными.

## Контакты

Telegram: [@doffi14](https://t.me/doffi14) · Email: [operagxyu@gmail.com](mailto:operagxyu@gmail.com)

Шрифты Nunito и лицензия: [Google Fonts — Nunito](https://github.com/google/fonts/tree/main/ofl/nunito), `LICENSES/OFL.txt`.
