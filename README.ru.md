# Nunito Sans для Android 16

[English](README.md) · [Релизы](https://github.com/Doffi4/nunito-sans-oxygenos16/releases)

Systemless-замена стандартного Android-семейства `sans-serif` на Nunito. Один ZIP на вариант жирности использует интерфейсы модулей **Magisk, APatch и KernelSU Next**. Целевые системы — Android 16, OxygenOS 16 и ColorOS 16 с распознаваемой конфигурацией шрифтов.

## Два варианта

| ZIP | Android-вес 400 |
| --- | --- |
| `Nunito_Sans_v1.2.0_Regular-400.zip` | Nunito 400 |
| `Nunito_Sans_v1.2.0_Slightly-Bolder-450.zip` | Nunito 450, немного плотнее |

Установи **один** вариант через раздел модулей своего рут-менеджера и перезагрузи телефон. У вариантов одинаковый ID: установка другого ZIP обновляет существующий модуль. Менять рут-менеджер не нужно. Установка через recovery не поддерживается.

| Менеджер | Требование к монтированию |
| --- | --- |
| Magisk | Включённое стандартное монтирование модулей |
| APatch | Включённое монтирование APM; в APatch 11219+ нужен совместимый включённый mount metamodule |
| KernelSU Next | Включённый совместимый mount metamodule |

KernelSU late-load не поддерживается: Android к этому моменту уже закэшировал системные шрифты. В этом режиме модуль пропускает генерацию конфигов и пишет причину в лог.

## Что меняется и что проверено

Заменяется только generic `sans-serif`. OEM-семейства One Serif, OPlus Sans, OPPO Sans, `sys-sans-en`, `op-sans-en`, emoji, Noto fallback, monospace и встроенные в приложения шрифты сохраняют свои определения. Экраны прошивки, которые явно выбирают OEM-семейство, могут сохранить прежний шрифт.

В ZIP включены оригинальные upright/italic Nunito Variable Fonts с кириллицей. Веса 200–900 используют соответствующие оси Nunito, кроме Android-веса 400 в варианте 450. **Вес 900 — Black, ось 900.** Минимум настоящего Nunito — 200, поэтому запрос веса 100 приближается через ExtraLight 200; разных настоящих начертаний 100 и 200 в этих файлах нет.

Конфиги OnePlus 13 `CPH2653_16.0.10.501(EX01)` прочитаны и проверены локально. ZIP в ходе этой работы на телефон не устанавливался. Интеграция с тремя менеджерами проверена по официальным интерфейсам и локальным сценариям, но запуск на устройствах с каждым менеджером не проверен. **ColorOS 16 на устройстве пока не проверена.**

## Механизм

При установке модуль читает актуальные известные конфиги ROM. Magisk и KernelSU при обычной загрузке заново готовят их перед монтированием. APatch сохраняет файлы, подготовленные при установке: свежий APatch монтирует модули раньше их post-fs-data-скриптов.

```text
/system/etc/font_fallback.xml                 # конфиг Android 16
/system/etc/fonts.xml                         # старый формат
/system_ext/etc/fonts_base.xml                # обнаружен в OxygenOS
/system_ext/etc/fonts_ule.xml                 # обнаружен в OxygenOS
/product/etc/fonts_customization.xml          # OEM-дополнения AOSP
```

Меняется содержимое единственного верхнеуровневого `<family name="sans-serif">`. Его атрибуты и каждый байт вне содержимого сохраняются. Отсутствующие, неоднозначные и неподдерживаемые конфиги пропускаются. Неизвестные OEM-пути, `family-list`, alias с именем `sans-serif` и языковые generic-семейства требуют отдельного анализа.

Новые XML записываются только в `system/` внутри модуля. Для product-конфига файлы Nunito добавляются в `system/product/fonts/` модуля: Android ищет их в `/product/fonts/`. Overlay монтирует рут-менеджер. Скрипты не пишут в реальные `/system`, `/product`, `/vendor` и не перемонтируют разделы. Старые конфиги очищаются при безопасной повторной генерации. Логи и временные файлы остаются внутри модуля.

**Обновления на APatch:** до OTA отключи Nunito и перезагрузи телефон. После обновления ROM переустанови Nunito, пока старый overlay отключён, затем включи/перезагрузи. Для обновления самого модуля также используй отключение → reboot → переустановка: установщик должен прочитать исходную ROM, а не прежний overlay. Проверка fingerprint только сообщает о несовпадении после mount; она не предотвращает монтирование старого XML. Это ограничение связано с текущим [порядком загрузки APatch](https://github.com/bmax121/APatch/blob/11224/apd/src/event.rs).

## FontLoader и автор

[FontLoader от JingMatrix](https://github.com/JingMatrix/FontLoader) предоставляет дополнительный механизм предварительной загрузки шрифтов для приложений, теряющих доступ к файлам systemless-модулей. Спасибо JingMatrix за этот проект.

FontLoader — отдельный необязательный Zygisk-модуль. Сам ZIP Nunito не содержит Zygisk-кода; overlay конфигурации монтирует рут-менеджер. При использовании FontLoader следуй его upstream-инструкции. Его работа на Android 16 с каждой реализацией Zygisk здесь не проверялась.

## Откат и диагностика

Отключи или удали **Nunito Sans** в своём менеджере и перезагрузи телефон. Менеджер уберёт overlay и вернутся шрифты ROM. Отдельный uninstall-скрипт не нужен.

При проблеме с загрузкой используй механизм восстановления своего менеджера: [KernelSU](https://kernelsu.org/guide/rescue-from-bootloop.html), [APatch](https://apatch.dev/rescue-bootloop.html), [Magisk](https://topjohnwu.github.io/Magisk/faq.html). Для KernelSU при обычной загрузке после первого экрана загрузки нажми и отпусти Volume Down больше трёх раз: Safe Mode отключит модули. В late-load этот способ не работает.

Если доступна авторизованная root-shell, создание файла `/data/adb/modules/nunito_sans_ksu/disable` отключит именно этот модуль при следующем запуске. В recovery для этого нужен доступ к расшифрованному `/data`. Для отката шрифтов не нужно стирать данные или прошивать другой boot.

Лог генерации: `/data/adb/modules/nunito_sans_ksu/font-status.log`. Другой шрифтовый модуль может перекрыть те же конфиги. Скрытие/размонтирование root-модулей в приложении может влиять на доступность шрифтов.

## Сборка и проверка

PowerShell 7:

```powershell
./build.ps1 -RegularWeight 400
./build.ps1 -RegularWeight 450
```

Для локальных проверок нужны Python 3, POSIX `sh` и AWK. На Windows последние два есть в Git Bash:

```sh
python tools/check.py --zip outputs/Nunito_Sans_v1.2.0_Regular-400.zip --zip outputs/Nunito_Sans_v1.2.0_Slightly-Bolder-450.zip
```

Подробности: [проверки и ограничения](docs/validation.md). Старые [v1.0.0](https://github.com/Doffi4/nunito-sans-oxygenos16/releases/tag/v1.0.0) и [v1.1.0](https://github.com/Doffi4/nunito-sans-oxygenos16/releases/tag/v1.1.0) предназначены только для KernelSU.

## Контакты и лицензия шрифта

Telegram: [@doffi14](https://t.me/doffi14) · Email: [operagxyu@gmail.com](mailto:operagxyu@gmail.com)

Оригинальный шрифт: [Google Fonts Nunito](https://github.com/google/fonts/tree/main/ofl/nunito), SIL Open Font License — [LICENSES/OFL.txt](LICENSES/OFL.txt).
