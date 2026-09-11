# Свежий OSINT-аудит стабильности Zenbook/Omarchy

**Дата среза:** 2026-09-12 (MSK)
**Статус:** исследование и варианты; системные изменения в этом срезе не выполнялись.

## Короткий вывод

Сейчас нет подтверждения, что причиной сбоев является NVMe, прошивка или нехватка памяти. Самая сильная свежая гипотеза — дефект на стыке `Quickshell 0.3.1-1` и Qt 6.11.2 в QML-incubation/reload-сценариях. Она хорошо совпадает с локальным `SIGSEGV` в `__dynamic_cast`/`QQmlObjectCreator::finalize` и upstream-issue, но пока не является доказательством единственной причины.

Отдельный класс — старые `SIGBUS` у bundled `kDrive` AppImage/Crashpad. Это не похоже на NVMe и не связано автоматически с Quickshell. kDrive для Linux официально ориентирован на Ubuntu, поэтому Arch/Omarchy следует считать неподдерживаемым вариантом совместимости.

`fstrim.timer` настроен корректно как еженедельный systemd-timer. Корневой Btrfs за LUKS не принимает discard из-за безопасной политики шифрования. Это не поломка таймера; это осознанный выбор между trim и утечкой информации о занятых блоках.

## Что подтверждено локально

| Область | Факт | Оценка |
| --- | --- | --- |
| Storage | `fwupd`, `smartmontools`, `nvme-cli` установлены; fwupd не предлагает обновлений; в ядре нет свежих timeout/reset/AER/I/O error | драйверная авария не подтверждена |
| NVMe | SMART ранее `PASSED`, media/data errors `0`; `unsafe shutdowns=125` и `error log entries=14` — lifetime-счётчики, не текущие ошибки | нужен свежий привилегированный re-read и наблюдение, но не паническая замена диска |
| Quickshell | две разные исторические сигнатуры: GLib/GVFS `SIGABRT` и Qt/QML `SIGSEGV`; новых core после контролируемого restart не появилось | containment работает, root cause остаётся открытой |
| Protected stack | Hermes→SearXNG read-only search, Camofox, Voxtype, Telegram transport, Chromium isolated test — положительно; Telegram message E2E не выполнялся | основной стек оставлен |
| Hygiene | pacman orphans/foreign packages `0`, failed units `0`; Zen residue уже убран в recoverable runtime backup | удалять пакеты вслепую нечего |
| LocalSearch | остановка user-unit дала примерно 70 MiB дополнительной available RAM в A/B; пакет нужен Nautilus | кандидат на пользовательский профиль, не «мусор» |

## Свежая проверка OSINT

### 1. Quickshell и Qt — наиболее вероятный текущий риск

Самый важный свежий upstream-материал — [Quickshell issue #983](https://github.com/quickshell-mirror/quickshell/issues/983). В нём описан `SIGSEGV` на Qt 6.11.2 в минимальном QML-сценарии с `PanelWindow`, `Variants`, экраном и binding вида `parent.width`; автор указывает, что тот же бинарник работает на Qt 6.11.1. Там же отмечено сходство с паттернами, встречающимися в Omarchy bar/background/lock/polkit. Отключение QML disk cache в issue не помогло.

Отдельно [issue #956](https://github.com/quickshell-mirror/quickshell/issues/956) описывает `IpcHandlerRegistry::forGeneration`, освобождённое расширение и стек через `__dynamic_cast` и `QQmlObjectCreator::finalize` во время teardown/reload. Это особенно похоже на локальную форму сбоя. Дополнительные upstream-риск-сигналы: [reload race #972](https://github.com/quickshell-mirror/quickshell/issues/972), [hotplug/incubation #885](https://github.com/quickshell-mirror/quickshell/issues/885), [resume/layer teardown #540](https://github.com/quickshell-mirror/quickshell/issues/540), [WlrLayershell close #910](https://github.com/quickshell-mirror/quickshell/issues/910) и [async widget incubation #941](https://github.com/quickshell-mirror/quickshell/issues/941).

Текущий Arch-пакет действительно [quickshell 0.3.1-1](https://archlinux.org/packages/extra/x86_64/quickshell/) и зависит от системных Qt6-библиотек. Поэтому гипотеза «сломано только локальное железо» сейчас слабее гипотезы «upstream Qt/Quickshell race, проявляющийся в нашем shell-графе».

### 2. kDrive — отдельная несовместимость, не NVMe

Текущий список upstream issues Infomaniak содержит свежие Linux/AppImage-проблемы: [AppImage на Debian](https://github.com/Infomaniak/desktop-kDrive/issues/1651), запуск на CachyOS [#1627](https://github.com/Infomaniak/desktop-kDrive/issues/1627), запуск/совместимость на других окружениях [#1631](https://github.com/Infomaniak/desktop-kDrive/issues/1631) и Hyprland-подобную проблему прозрачного окна [#1413](https://github.com/Infomaniak/desktop-kDrive/issues/1413). Сам проект указывает Linux-матрицу Ubuntu 22.04 amd64 / Ubuntu 24.04 arm64 и не обещает Arch как поддерживаемую платформу: [официальный репозиторий desktop-kDrive](https://github.com/Infomaniak/desktop-kDrive).

Это не доказывает, что именно upstream исправит локальный `Crashpad SIGBUS`, но делает постоянное использование AppImage на Omarchy слабым вариантом. Наиболее безопасная стратегия — не запускать его автоматически, пока не выбрана поддерживаемая замена или проверенный новый билд.

### 3. fstrim и LUKS

[Документация Arch по `fstrim`](https://man.archlinux.org/man/fstrim.8) считает еженедельный запуск достаточным для обычного desktop/server и предупреждает, что слишком частый trim может быть нежелателен для некоторых SSD. [Документация ядра dm-crypt](https://docs.kernel.org/admin-guide/device-mapper/dm-crypt.html) подтверждает: discard по умолчанию не передаётся; `allow_discards` это меняет, но раскрывает информацию о занятых блоках.

Следовательно, текущий результат — «timer исправен, root trim намеренно не проходит», а не «надо чинить fstrim». Включение discard потребует boot/initramfs-изменения и отдельного решения пользователя.

### 4. LocalSearch

[GNOME LocalSearch](https://gnome.pages.gitlab.gnome.org/localsearch/overview.html) — это индексатор для desktop search, а не обязательный компонент Linux/Omarchy. Документация также описывает запуск `localsearch-3` через systemd при входе в сессию и допускает не запускать его в сессиях, где поиск не нужен: [command line/service documentation](https://gnome.pages.gitlab.gnome.org/localsearch/commandline.html).

Локальный A/B-тест подтверждает реальную, хотя и не огромную, цену в RAM. Но удаление пакета сломает или ограничит Nautilus search, поэтому это вариант профиля использования, а не универсальная оптимизация.

## Варианты решений

### A. Quickshell/Qt

| Вариант | Что даёт | Риск | Рекомендация |
| --- | --- | --- | --- |
| A1. Ничего не менять, оставить текущий launcher containment | нет риска общего Qt downgrade; быстрый recovery сохраняется | дефект может повториться | базовый режим сейчас |
| A2. Контролируемый тест Qt 6.11.1 | проверяет свежую upstream-гипотезу #983 | Qt общий для desktop; нужных пакетов нет в локальном cache; возможен конфликт зависимостей | лучший следующий эксперимент при повторе, но только с snapshot/rollback |
| A3. Временный archive downgrade всего согласованного Qt-набора | сильнее проверяет причинность | высокий blast radius, ломает другие Qt-приложения, нужен точный набор пакетов | не закреплять без backup и окна восстановления |
| A4. Патч/сборка Quickshell из upstream | можно проверить фикс раньше Arch | сопровождение, подпись/воспроизводимость и совместимость с Omarchy | только после конкретного upstream fix |
| A5. Урезать сторонние widgets/plugins | может убрать reload/incubation trigger | можно потерять нужные функции; локальный root stack может быть core Omarchy | только по одному компоненту с rollback |

**Решение:** сейчас оставить A1. При новом core — сначала сохранить backtrace, проверить точный Qt-пакет и провести A/B A2; не применять `QML_DISABLE_DISK_CACHE=1` как «фикс», потому что свежий issue уже показывает отрицательный результат.

### B. fstrim/root discard

| Вариант | Плюс | Минус | Рекомендация |
| --- | --- | --- | --- |
| B1. Оставить текущий secure default | нет изменения boot/security; еженедельный timer работает | root discard не передаётся | рекомендуется по умолчанию |
| B2. Включить `allow-discards` для LUKS | trim root станет доступен | раскрытие block-occupancy pattern; нужен boot/initramfs/reboot | только осознанно и после backup |
| B3. Единичный live `cryptsetup refresh` A/B | быстрый эксперимент без постоянного boot change | privileged live mapper change; сложнее rollback и легко ошибиться | не выполнять без отдельного подтверждения |
| B4. Частый mount-time `discard` | постоянная immediate reclamation | лишняя write/latency cost и не требуется для desktop | не рекомендовать |

### C. память и сервисы

| Вариант | Плюс | Цена |
| --- | --- | --- |
| C1. Оставить LocalSearch | сохраняет Nautilus/GNOME search | около 70 MiB наблюдаемой A/B-разницы, плюс I/O |
| C2. `disable --now` LocalSearch | меньше фоновой RAM/I/O | desktop search перестанет быть штатно доступен; D-Bus activation может потребовать отдельной проверки |
| C3. Ограничить индексируемые пути | компромисс | требует проверить актуальный GNOME-конфиг и повторить A/B |

**Решение:** не трогать protected services. LocalSearch — единственный разумный кандидат для интерактивного выбора: если Nautilus search не используется, C2; если используется, C1 или C3.

### D. kDrive

1. **Удалить/не автозапускать AppImage** — минимум риска и минимум лишних crashpad cores.
2. **Проверить свежий официальный Linux build** — только в отдельном профиле, без замены текущих данных и без автозапуска до smoke-test.
3. **Собрать из upstream** — технически возможно через официальный Podman/Conan workflow, но это уже отдельный проект и не гарантирует поддержки Arch.
4. **Изолировать systemd-сервисом** — containment, но не исправление; имеет смысл только если kDrive обязателен.

Мой выбор по умолчанию: вариант 1, затем вариант 2 при необходимости. Не стоит маскировать Crashpad-cores увеличением лимитов или отключением coredump: это скроет симптом.

## Приоритетный план без лишнего риска

1. **Ничего не менять сегодня в Qt/LUKS/APST.** Текущая система работоспособна, launcher containment активен, failed units отсутствуют.
2. **Закрыть доказательную дыру по NVMe:** повторить SMART/NVMe read в интерактивном privileged-сеансе и отделить lifetime counters от текущих error entries.
3. **Сделать controlled suspend/resume series** и после каждого цикла проверять NVMe journal, coredumps и systemd. Только реальный timeout/reset меняет APST-план.
4. **При новом Quickshell core:** сохранять exact stack, сравнить Qt package set, затем A/B с согласованным Qt 6.11.1; не делать случайный частичный downgrade.
5. **Выбрать LocalSearch-профиль** по фактическому использованию Nautilus search.
6. **Принять решение по kDrive**: удалить AppImage, обновить в изоляции или оставить выключенным до поддерживаемого build.
7. **После решений:** повторить protected-stack healthcheck, Camofox cleanup, Chromium matrix, `./tools/ci-check.sh`, `git diff --check`; только затем обновить release status.

## Слепые зоны и ограничения

- Совпадение локального стека с upstream issue — корреляция, не минимальная воспроизводимая причина именно в профиле Omarchy.
- Кнопка/поверхность Codex Browser в текущей сессии недоступна; Chromium проверен изолированным локальным запуском, это не следует выдавать за UI-тест подключённого CUA-браузера.
- Десять доменов прошли транспортный тест через текущий VPN, но challenge/login/privacy-wall всё равно является функциональной блокировкой для агента.
- Telegram проверен на транспортный reconnect, но сообщение в Telegram намеренно не отправлялось.
- Lifetime `unsafe shutdowns` не датирует события и не доказывает текущую неисправность SSD.

## Источники

- [Quickshell #983 — Qt 6.11.2 QML binding SIGSEGV](https://github.com/quickshell-mirror/quickshell/issues/983)
- [Quickshell #956 — stale IpcHandler generation / dynamic_cast crash](https://github.com/quickshell-mirror/quickshell/issues/956)
- [Arch package: quickshell 0.3.1-1](https://archlinux.org/packages/extra/x86_64/quickshell/)
- [Infomaniak desktop-kDrive repository and support matrix](https://github.com/Infomaniak/desktop-kDrive)
- [Infomaniak kDrive current issues](https://github.com/Infomaniak/desktop-kDrive/issues)
- [Arch `fstrim(8)`](https://man.archlinux.org/man/fstrim.8)
- [Linux kernel dm-crypt discard documentation](https://docs.kernel.org/admin-guide/device-mapper/dm-crypt.html)
- [GNOME LocalSearch overview](https://gnome.pages.gitlab.gnome.org/localsearch/overview.html)
- [GNOME LocalSearch service/command-line documentation](https://gnome.pages.gitlab.gnome.org/localsearch/commandline.html)

## Дополнение: NVMe — очистка и профилактика

### Два разных счётчика

NVMe Error Information log и SMART lifetime counter нельзя смешивать:

- Error Information log содержит последние записи об ошибках; спецификация допускает его очистку при controller reset или power cycle. На этой машине актуальные записи уже не содержат ошибок: `error_count=0`, успешный status.
- `Number of Error Information Log Entries=14` — накопительный идентификатор/счётчик за жизнь контроллера. Его нельзя штатно обнулить через `nvme-cli`, reset или обычную перезагрузку. Обнуление этого числа не было бы исправлением.

Источники: [NVMe 1.3c, Error Information log](https://nvmexpress.org/wp-content/uploads/NVM-Express-1_3c-2018.05.24-Ratified.pdf) и [NVMe management/logging summary](https://nvmexpress.org/wp-content/uploads/June-2020-NVMe%E2%84%A2-SSD-Management-Error-Reporting-and-Logging-Capabilities.pdf).

### Текущий SN850X и доступные инструменты

Локально подтверждены: firmware `620361WD`, BIOS `UM3406KA.306`, APST enabled, NOPPM enabled, `/sys/.../power/control=on`, `nvme-cli 2.16`, `smartmontools 7.5`, `fwupd 2.1.7`. `fwupdmgr` не предлагает обновления для SSD или System Firmware.

Официальная страница [WD_BLACK SN850X](https://support-en.wd.com/app/products/detail/p/8695) предупреждает, что firmware updates доступны только если поддержаны соответствующим software tool; актуальная страница [SanDisk product support](https://support-en.sandisk.com/app/products/product-detailweb/p/8695) направляет к SanDisk Dashboard, а спецификация WD указывает Windows-only Dashboard. Это не основание ставить случайный `.fluf` или vendor-драйвер под Linux.

Правильный Linux-набор уже установлен:

- in-tree Linux `nvme` driver — драйвер устройства;
- `nvme-cli` — диагностика, features, firmware log и error log;
- `smartmontools` — SMART/health и температурный контроль;
- `fwupd` — только проверка поддержанных LVFS-обновлений.

`smartd` уже присутствовал, поэтому вместо нового скрипта включён один минимальный system service: только `/dev/nvme0`, проверка раз в 30 минут, journal-only, без почты и без автоматических reset/firmware/power changes. Конфигурация использует `-H -l error -W 5,70,80`; one-shot validation прошла с exit `0`, сервис active, memory около `1.5 MiB`.

Актуальная [smartd.conf documentation](https://man.archlinux.org/man/smartd.conf.5) подтверждает нужную реакцию для NVMe: `-H` отслеживает Critical Warning, `-l error` — рост `Number of Error Information Log Entries` и отличает сохранившуюся device-related ошибку от исчезнувшей/invalid-команды, `-W` задаёт температурные пороги. Состояние baseline хранится smartd в persistent state files, поэтому исторические `14` не превращаются в повторяющиеся тревоги.

### Что действительно снижает шанс новых событий

1. Оставить APST и NOPPM как есть: пять реальных AC `s2idle` циклов прошли без timeout/reset/I/O/Btrfs ошибок. Не добавлять `nvme_core.default_ps_max_latency_us=0`, `pcie_aspm=off` или `pcie_port_pm=off` без воспроизведения отказа.
2. Оставить runtime NVMe power control `on`; это уже консервативнее, чем разрешённый autosuspend.
3. Сохранять еженедельный `fstrim.timer`; он не связан с обнулением error counter и уже работает корректно.
4. Избегать hard power-off/forced reset; именно такие события наиболее правдоподобно увеличивают `unsafe_shutdowns`. Программные suspend/resume циклы сами по себе счётчик не увеличили.
5. Проверять SMART/NVMe после будущего реального сбоя, а не пытаться очищать историю. Тревожная комбинация: рост `14` + ненулевой `error_count` + kernel timeout/reset/I/O или Btrfs error.

### Как происходит реакция

- **Информационный уровень:** счётчик вырос, но новые записи уже исчезли после reset/power-cycle или относятся к invalid/unsupported command. smartd пишет событие в journal; автоматического вмешательства нет.
- **Критический уровень:** Critical Warning, media/data errors, температура выше критического порога или сохранившаяся device-related Error Information entry. Я сохраняю `smartctl`, `nvme error-log`, kernel journal и Btrfs evidence, затем останавливаю рискованные изменения.
- **Подтверждённый power/controller failure:** только после повторения timeout/reset/I/O выполняется отдельный A/B с ограниченным APST threshold; `pcie_aspm=off`, `pcie_port_pm=off`, firmware flash и замена SSD не применяются автоматически.
- **Откат мониторинга:** отключить `smartd.service`, удалить host-specific `/etc/smartd-zenbook.conf` и восстановить прежний `SMARTD_ARGS`; SSD и его counters от этого не меняются.

### Telegram-сторожок через Hermes

Для доставки уведомлений подключён штатный Hermes `cron` без LLM:

- script: `~/.hermes/scripts/zenbook-smartd-alert.sh`;
- schedule: `every 15m`;
- mode: `no-agent`;
- delivery: настроенный Telegram home target;
- источник: новые `smartd` и kernel NVMe/Btrfs/AER записи после последнего запуска;
- здоровое состояние даёт пустой stdout и не отправляет сообщение.

Manual run в здоровом состоянии завершился `succeeded` без Telegram-сообщения. Self-test скрипта также прошёл. Это не новый daemon и не прямой Bot API: Hermes переиспользует существующую Telegram-конфигурацию. Если Hermes gateway остановлен, доставка невозможна в этот момент, но `smartd` продолжает писать evidence в journal; после восстановления Hermes следующий cron tick снова проверит окно.

### Итоговое решение

Нового драйвера или утилиты, которая безопасно «лечит» текущие значения, не найдено. Текущее состояние — не неисправность SSD: исторические counters стабильны, актуальные entries чистые, firmware доступно в актуальном проверенном состоянии, а power-management эксперимент не воспроизвёл ошибку.
