# Omarchy 4: первопричины нестабильности хоста и репозитория — 2026-09-14

## Вывод

Методология и границы дальнейших изменений зафиксированы в [native extension contract](../omarchy-4-native-extension-contract.md), единый follow-up и GitHub workflow — в [Omarchy 4 unified improvement and GitHub sync plan](../superpowers/plans/2026-09-14-omarchy4-unified-improvement-and-github-sync.md), а input-детали — в [Omarchy 4 native input regression plan](../superpowers/plans/2026-09-14-omarchy4-native-input-regression.md): vendor source остаётся read-only, user overrides проходят через нативные Omarchy точки расширения, а input-исследование продолжает работу с сохранёнными Fcitx5 и D-Bus.

Это не одна «поломка Omarchy» и не проблема железа Zenbook. На Omarchy 4 одновременно пересеклись четыре независимых слоя:

1. новый единый долгоживущий shell на Quickshell;
2. upstream race/use-after-free в Quickshell/Qt 6.11.2;
3. конфликт владельцев раскладки между Hyprland XKB и Fcitx5;
4. отсутствие постоянного lifecycle-owner для локального SearXNG Docker stack.

Главная причина исторических падений `quickshell` подтверждена на уровне core: локальный `SIGSEGV` проходит через `__dynamic_cast` и `QQmlObjectCreator::finalize()` во время инкубации QML-объектов. Это совпадает с upstream Quickshell issue [#956](https://github.com/quickshell-mirror/quickshell/issues/956), где описан dangling `EngineGeneration`/`IpcHandlerRegistry` при teardown и reload. Отдельная локальная ошибка `SIGABRT` в GLib/GVFS имеет другую причину; объединять оба core в одну неисправность нельзя.

Пять последовательных штатных restart’ов shell прошли, а минимальный QML reproducer за шесть секунд не упал. Это доказывает восстановление и отсутствие детерминированного падения в данном окне наблюдения, но не исправление upstream race. В текущем Omarchy 4.0.3 upstream продолжает принимать отчёты о том же семействе `Repeater`/QML-incubation с Qt 6.11.2, включая [#11727](https://github.com/omacom/omarchy/issues/11727) и [#11755](https://github.com/omacom/omarchy/issues/11755).

Постоянное решение для Quickshell — patched package/Qt upstream, согласованный релиз Omarchy или безопасный downgrade/pin до проверенной пары как временное containment. Перезапуск shell, очистка кэша, изменение NVMe/APST и переустановка тех же пакетов не устраняют lifetime bug.

## Матрица подтверждённых причин

| Приоритет | Слой | Что доказано | Что является постоянным исправлением |
|---|---|---|---|
| P1 | Quickshell/Qt | `quickshell 0.3.1-1`, Qt 6.11.2; локальный core `SIGSEGV` в `__dynamic_cast → QQmlObjectCreator::finalize`; время core совпадает с plugin hot-reload | Обновление до upstream/package, где исправлен lifetime race; до этого — pin/downgrade согласованной пары и отключение опасных reload-trigger’ов как containment |
| P1 | Input ownership | Hyprland XKB и Fcitx5 действительно могут конфликтовать при multi-layout, но vendor-контракт Omarchy 4 намеренно держит Fcitx5 для XCompose/IME; runtime `keyboard-us` и virtual keyboard сами по себе не являются drift | Не отключать vendor service/D-Bus вслепую. Нужен совместимый synchronized Fcitx/XKB path либо отдельный явно объявленный профиль с принятой потерей XCompose; permanent fix пока не объявлен |
| P1 | SearXNG lifecycle | `127.0.0.1:8080` connection refused; Docker daemon `inactive/disabled`; пользователь не входит в `docker`, socket `root:docker`; отдельного `searxng.service` нет | Один boot-managed service для Compose (rootful Docker с `docker.service` или rootless Podman), `After=`/readiness dependency и healthcheck после готовности контейнера |
| P1 | Test gate | `ci-check` зелёный, но Zenbook check падает на host drift; unittest discovery нашёл 0 тестов и завершился кодом 5 | Явно запускать supported-profile checks и оба standalone test runner’а; запретить «0 tests» как зелёный результат |
| P1 | Publication | `profiles/.../runs/*.json` и `*.md` не покрываются текущим root-only `.gitignore` | Игнорировать `**/runs/` и проверять `git check-ignore` в CI до публикации raw hardware evidence |
| P2 | Omarchy 4 CLI | `omarchy debug --no-sudo --print` не существует в 4.0.3; рабочий бинарник — `omarchy-debug --no-sudo --print` | Feature-detect/direct binary в документации и профиле; не считать отсутствие dispatcher alias повреждением пакетов |
| P2 | Voice drift | Lemonade сейчас `HTTP 200`, telemetry off, модель `whisper-v3-turbo-FLM`=`ready/loaded` на NPU; Voxtype всё ещё `audio.device=pipewire`, `output.mode=paste`, mic=5% | Один повторяемый `voice/apply.sh --apply` из versioned policy, затем live doctor и end-to-end capture; NPU не переустанавливать |
| P2 | Repository contract | `PROFILE_PACKAGE_MANIFESTS=""`, `platform.txt` reference-only; plan для `packages`/`doctor` всё ещё печатает Branding; JSON stages без `enabled` у terminal/update/doctor | Либо сделать manifest исполняемым, либо честно назвать reference-only; исправить plan/schema и добавить dependency guard для `gnome-control-center` |

## Эксперименты и наблюдения

### 1. Версии и граница Omarchy 4

Подтверждено на живом хосте:

```text
Omarchy 4.0.3-1
Hyprland 0.56.2-2
quickshell 0.3.1-1
qt6-base 6.11.2-3
qt6-declarative 6.11.2-1
kernel 7.2.3-arch1-3
```

Официальный релиз Omarchy 4 описывает переход к одному долгоживущему Quickshell-процессу для bar, launcher, panels, notifications, lock screen и polkit. Это архитектурно увеличивает blast radius одной ошибки QML: падение одного процесса затрагивает сразу весь desktop shell. [Release v4.0.0/v4.0.3](https://github.com/omacom/omarchy/releases) подтверждает эту архитектуру; v4.0.3 не заявляет исправления Quickshell/Qt lifetime race.

### 2. Исторический Quickshell `SIGSEGV`

`coredumpctl info 29033` дал:

```text
Signal: 11 (SIGSEGV)
Command Line: quickshell -n -p /usr/share/omarchy/shell
__dynamic_cast
quickshell internal frame
QQmlObjectCreator::finalize
QQmlIncubatorPrivate::incubate
QQmlIncubationController::incubateFor
```

Непосредственно перед падением journal зафиксировал многократный `Local plugin changed, reloading`, затем IPC exit и автоматический restart. Это не похоже на OOM, NVMe timeout, GPU reset или ошибку пользовательской конфигурации. Upstream #956 описывает тот же порядок: объект с `IpcHandler` завершается одновременно с уничтожением QML generation, после чего `dynamic_cast` читает уже освобождённый extension.

Отдельный core `1252324` — `SIGABRT` в GLib/GVFS directory-monitor path. Это другой дефект, связанный с построением D-Bus directory monitor, а не тот же Quickshell teardown defect.

### 3. Контролируемый reproducer и recovery

Запущен изолированный 20-line QML reproducer из upstream #983 с:

```text
QML_DISABLE_DISK_CACHE=1
QS_DISABLE_CRASH_HANDLER=1
ulimit -c 0
timeout 6s quickshell -n -p <temporary-qml>
```

Результат: `Configuration Loaded`, timeout 124, новых core нет. Это не опровергает race: upstream отмечает зависимость от конкретного графа, интервала incubation и hardware/session timing. После него выполнено пять `omarchy restart shell`: каждый завершился с code 0, `omarchy-shell shell ping` вернул `ok`, число исторических Quickshell core осталось равным двум.

Результат эксперимента: launcher/restart path обеспечивает recovery, но containment не является permanent fix. Переменная `QS_DISABLE_FILE_WATCHER=1` в установленном launcher снижает риск reload во время обновления файлов, но не может исправить use-after-free внутри Quickshell/Qt.

### 4. Input: XKB и Fcitx действительно имеют двух владельцев

Live checks:

```text
hyprctl getoption input:kb_layout  -> us,ru
hyprctl getoption input:kb_options -> compose:caps,grp:alt_shift_toggle_bidir
systemctl --user is-active omarchy-fcitx5.service -> active
fcitx5-remote -n -> keyboard-us
```

`~/.config/fcitx5/profile` содержит `Name=keyboard-us`; versioned profile в репозитории намеренно содержит пустой `Default Layout` и пустой `DefaultIM`. Это не является достаточным доказательством drift: `keyboard-us` может быть runtime fallback ожидаемого Fcitx virtual keyboard. Проверять нужно фактический текстовый ввод и переключение, а не только имя backend-а.

Это не только локальный stale file. Omarchy issue [#9552](https://github.com/omacom/omarchy/issues/9552) описывает тот же конфликт на Omarchy 4: bar и `hyprctl devices` могут показать переключение XKB, пока Fcitx virtual keyboard продолжает отдавать приложениям собственную раскладку. Поэтому постоянный контракт должен согласовать владельцев, сохранив Fcitx/XCompose по умолчанию; для обычных `us/ru` нельзя выбирать XKB-only по одному статическому имени `keyboard-us`.

#### 4.1. Review correction: vendor contract restored

Первоначальный containment был неверным: он сделал зелёными проверки XKB ценой удаления предусмотренного Omarchy input-method слоя. После review этот результат признан недоказательным и отозван.

OSINT по исходному Omarchy 4.0.3 показывает намеренную архитектуру:

1. `omarchy-fcitx5.service` описан как сервис Fcitx5 для XCompose, запускается только в Wayland-сессии, имеет `Restart=always` и включается через `graphical-session.target`.
2. First-run script вендора делает `systemctl --user enable --now omarchy-fcitx5.service`; migration `1785167800.sh` прямо объясняет это supervision-ом, чтобы CapsLock/XCompose не «молча умирал».
3. Vendor environment выставляет `INPUT_METHOD=fcitx`, `QT_IM_MODULE=fcitx`, `SDL_IM_MODULE=fcitx`, `XMODIFIERS=@im=fcitx`; Quickshell KeyboardLayout отдельно знает и фильтрует `hl-virtual-keyboard-fcitx5` как ожидаемую виртуальную клавиатуру Fcitx.

Следовательно, `hl-virtual-keyboard-fcitx5` и D-Bus autoactivation не являются сами по себе нарушением. D-Bus — штатный fallback/activation path Fcitx; удалять его можно только вместе с осознанным отказом от XCompose/IME, а не как «защиту» от stale layout.

Host state после отката неправильного containment:

```text
systemctl --user is-enabled omarchy-fcitx5.service   enabled
systemctl --user is-active omarchy-fcitx5.service    active
fcitx5 process                                       /usr/bin/fcitx5 --disable notificationitem
fcitx5-remote -n                                     keyboard-us
hl-virtual-keyboard-fcitx5                            present/expected
user environment                                     INPUT_METHOD=fcitx
                                                     QT_IM_MODULE=fcitx
                                                     SDL_IM_MODULE=fcitx
                                                     XMODIFIERS=@im=fcitx
user no-fcitx override                                absent
```

Repository changes, которые маскировали service, удаляли D-Bus autoactivation и подменяли окружение на `none`, также отозваны. `apply.sh`/`doctor.sh` снова не уничтожают vendor ownership и не используют отключение Fcitx как permanent contract.

После восстановления native service выяснился отдельный false positive в собственном gate: Fcitx нормализует пустой профиль в допустимый single `keyboard-us` fallback. Поэтому `apply.sh`/`doctor.sh` теперь принимают только этот vendor-compatible fallback, но по-прежнему отвергают `keyboard-ru`, duplicate keyboard items и language-toggle binding. Regression test зафиксирован в `input/test_input_policy.sh` и включён в CI.

Issue [#9552](https://github.com/omacom/omarchy/issues/9552) и исторический [#483](https://github.com/basecamp/omarchy/issues/483) подтверждают реальный compatibility bug: Hyprland/XKB может показывать переключение, пока Fcitx отдаёт приложениям старую раскладку. Но это доказывает необходимость согласовать владельцев и тестировать input end-to-end, а не право ломать предусмотренный vendor IME слой.

Отдельный тест через `wtype` отозван как evidence физической раскладки: `wtype` сам вводит виртуальные key events и не проверяет аппаратный Alt+Shift/key-order путь. Пользовательский физический acceptance в native Foot подтвердил оба порядка Alt+Shift, Latin/Cyrillic ввод и CapsLock/XCompose; введённый текст не сохранялся. Дополнительный эмулированный Wayland input path прошёл в GTK, Qt/QML и Chromium; это подтверждает доставку текста приложениям, но не заменяет физическую проверку layout switching.

#### 4.2. D-Bus autoactivation red-team

Изолированный эксперимент подтвердил, почему удалять D-Bus autoactivation было архитектурной ошибкой:

1. Baseline: unit `enabled/active`, один процесс `/usr/bin/fcitx5 --disable notificationitem`.
2. После `systemctl --user stop omarchy-fcitx5.service` unit стал `inactive/dead`.
3. Штатный `fcitx5-remote -n` вернул code 0 и поднял отдельный `/usr/bin/fcitx5` через D-Bus, при этом systemd unit остался `inactive/dead`.
4. Запуск unit при существующем stray-процессе дал `activating/auto-restart`, `NRestarts=6`: два владельца действительно конфликтуют.
5. После завершения только экспериментального stray-процесса и `systemctl --user restart omarchy-fcitx5.service` восстановился один owner: unit `active/running`, `NRestarts=0`, процесс снова имел vendor args `--disable notificationitem`.

Это подтверждает vendor migration: D-Bus autoactivation не «лишний хвост», а реальный путь возврата Fcitx, поэтому permanent XKB fix должен согласовывать владельцев, а не удалять механизм активации.

### 5. SearXNG: причина ниже HTTP endpoint установлена

Наблюдения:

```text
curl http://127.0.0.1:8080/healthz -> connection refused
systemctl is-active docker.service -> inactive
systemctl is-enabled docker.service -> disabled
id -nG -> totem wheel   (без docker)
/var/run/docker.sock -> root:docker, 0660
systemctl --user status searxng.service -> unit not found
```

`hermes-healthcheck.timer` запускает только oneshot-проверку; он не запускает Compose stack. `hermes-start-searxng` умеет ручной fallback на `sudo docker compose up -d`, но это не boot lifecycle и не readiness dependency. Поэтому failed healthcheck является ожидаемым следствием отсутствия владельца запуска, а не доказательством повреждения SearXNG settings или плохого OSINT engine.

Постоянная схема: создать единственный system-level `searxng.service`, который владеет `docker compose up/down`, зависит от Docker и сети, использует фиксированный образ/digest, ждёт `/healthz`, а Hermes healthcheck запускать после его readiness. Простое добавление пользователя в `docker` устранит permission error для ручной команды, но само по себе не запустит stack после reboot.

#### 5.1. Исправление шагом 2: подготовлено, host apply заблокирован auth

Эксперимент подтвердил, что контейнеры не стартуют не из-за SearXNG settings:

```text
docker 1:29.7.2-1; docker-compose 5.5.1-1
docker.service                       disabled / inactive
127.0.0.1:8080/healthz              connection refused
SEARXNG_HOST                         127.0.0.1
SEARXNG_PORT                         8080
SEARXNG_VERSION                      2026.9.10-931fd9787 (already pinned)
```

В репозитории подготовлены `search/searxng.service` и user-facing
`search/apply.sh`: unit требует Docker и network-online, запускает Compose с
`--wait`, остаётся boot-enabled, а doctor проверяет Docker, systemd owner,
healthz и loopback-only bind. `systemd-analyze verify` и shell syntax проходят.

Фактический `--apply` остановился до изменения host state: `pkexec` не получил
доступный polkit auth agent/visible prompt в этой автоматизированной сессии.
Проверка после остановки подтвердила, что unit не установлен, Docker не
включён, `8080` по-прежнему закрыт. Это честный blocker привилегии, а не
неуспешная попытка замаскировать ручной запуск под permanent fix.

### 6. Voice/NPU: прежний вывод был stale

Повторный live probe дал:

```json
{
  "telemetry": {"enabled": false},
  "all_models_loaded": [
    {"model_name":"whisper-v3-turbo-FLM","recipe":"flm",
     "device":"npu","backend_health":"ready","loaded":true}
  ]
}
```

Также `lemond.service` system-level enabled/active, а `flm-real` слушает локальный backend. Поэтому NPU сейчас исправен. Doctor всё ещё честно ловит три drift-факта: `audio.device=pipewire` вместо `default`, `output.mode=paste` вместо `type`, физический микрофон 5% вместо профиля 30%. Feedback sink HDMI — предупреждение о маршрутизации, не доказательство неисправности NPU.

### 7. Repository gates

Повторно подтверждено:

```text
./scripts/bootstrap.sh --profile generic --check       PASS
./scripts/bootstrap.sh --profile zenbook-um3406ka --check PASS (input doctor still requires physical Wayland acceptance)
python -m unittest discover -s profiles -p 'test_*.py'  NO TESTS RAN, exit 5
python profiles/zenbook-um3406ka/search/test_searxng_search.py -v  6 PASS
```

`ci-check.sh` проверяет syntax, byte-compilation, public scan и plan output, но не выполняет Zenbook live doctor, SearXNG tests или Xerox test runner. Поэтому зелёный CI не означает, что поддерживаемый профиль проходит собственный check.

Проверки, выполненные после ошибочного mask/no-IME containment, были зелёными только потому, что vendor service и его virtual keyboard были удалены из графа; это не считается подтверждением исправления. После review этот результат классифицирован как invalidated experiment. Действительным результатом остаются repository gates и отдельные SearXNG tests; input acceptance ещё требует реального физического end-to-end теста при сохранённом vendor contract.

Дополнительные подтверждённые несоответствия:

- `.gitignore` содержит `runs/*.json` и `runs/*.md`, что покрывает только root-level `runs`, но не `profiles/.../runs`;
- `bootstrap.sh --stage packages --plan` и `--stage doctor --plan` печатают Branding, хотя эти стадии его не выполняют;
- JSON manifest не содержит `enabled` для `terminal`, `update`, `doctor`;
- `platform.txt` не исполняется, потому что `PROFILE_PACKAGE_MANIFESTS=""`;
- shortcut в `bindings-block.lua` требует `gnome-control-center`, а ownership пакета находится в отдельном `scripts/gmail.sh`;
- установленный dispatcher не знает `omarchy debug`; upstream #9373 подтверждает, что в Omarchy 4 такие binaries могут существовать только как `omarchy-*` без symlink в dispatcher directory.

## План постоянного исправления

### A. Quickshell

1. Не объявлять исторические core «почищенными» и не переустанавливать ту же пару `quickshell 0.3.1/Qt 6.11.2` как fix.
2. Следить за upstream fixes для #956, #983, #11727 и #11755 и переходить на пакет, где lifetime/Repeater race исправлен и воспроизводимость проверена.
3. До этого оставить launcher containment (`QS_DISABLE_FILE_WATCHER=1`, clean stop before restart), запретить агрессивный local-plugin hot-reload и хранить каждый новый core как отдельный signature.
4. Acceptance: controlled reload/restart matrix, zero new unexplained core за observation window, shell ping после каждого restart, без claim «fixed» до package-level verification.

### B. Input

1. Выполнено: vendor `omarchy-fcitx5.service`, Fcitx environment и D-Bus autoactivation восстановлены; неправильные mask/no-IME repo changes отозваны.
2. Не делать: не превращать «обычная XKB-раскладка переключается» в основание для отключения Fcitx, пока не определён совместимый XCompose/IME contract.
3. Выполнено: физический Foot acceptance и эмулированная доставка текста в GTK, Qt/QML и Chromium при сохранённых `fcitx5`/D-Bus.
4. Следующий контроль: повторить fixture-тесты после fresh graphical login и Omarchy update; менять input ownership только если появится новый cross-toolkit mismatch.

### C. SearXNG/Hermes

1. Подготовлено: один systemd unit для Compose stack вместо ручного launcher; установка ожидает visible privileged authentication.
2. Подтверждено: image tag уже pinned, bind остаётся loopback-only.
3. Подготовлено: `Requires=docker.service`, `After=network-online.target docker.service`, Compose `--wait`, затем doctor/healthcheck.
4. После получения auth выполнить apply и проверить HTML, JSON, normalized `searxng-search`, domain allowlist и Hermes healthcheck; engine quality тестировать отдельно от container readiness.

### D. Repository

1. Добавить `**/runs/` в ignore и CI assertion, что nested raw output ignored.
2. Явно запускать `python profiles/zenbook-um3406ka/search/test_searxng_search.py -v` и `tools/test-xerox-workcentre.sh`; не принимать zero-test discovery.
3. Развести plan по стадиям, добавить единый `enabled` schema и устранить двусмысленность `platform.txt`.
4. Для package-dependent bindings либо добавить package в тот же ownership contract, либо сделать binding conditional/optional.
5. В документации Omarchy 4 использовать `omarchy-debug --no-sudo --print` с fallback detection, а не несуществующий alias `omarchy debug`.
6. Обновить package inventory после текущего образа, включая foreign packages, split `linux-firmware-*` и install reasons. Не удалять `brave-bin`, `uhubctl` или кэши без отдельного user-approved cleanup.

## Что не является причиной

- NVMe/APST: нет текущих timeout/reset/AER/I/O ошибок; lifetime counters не объясняют QML `__dynamic_cast`.
- RAM/swap: pressure и OOM не наблюдаются.
- DP-1/VRR: display doctor проходит, live state соответствует профилю.
- Lemonade/NPU: текущий health payload подтверждает ready/loaded NPU model.
- kDrive Crashpad `SIGBUS`: это отдельный AppImage-bundled Crashpad/LDAP incident и не причина Quickshell core.
- «Просто перезапустить shell»: это recovery path, не root-cause fix.

## Evidence commands

```text
omarchy version
pacman -Q omarchy quickshell qt6-base qt6-declarative
coredumpctl list --no-pager
coredumpctl info 29033 --no-pager
omarchy-shell shell ping
for i in 1 2 3 4 5; do omarchy restart shell; done
QML_DISABLE_DISK_CACHE=1 QS_DISABLE_CRASH_HANDLER=1 timeout 6s quickshell -n -p <temporary-qml>
hyprctl getoption input:kb_layout
hyprctl getoption input:kb_options
systemctl --user status omarchy-fcitx5.service
./profiles/zenbook-um3406ka/input/apply.sh --check
./profiles/zenbook-um3406ka/input/doctor.sh
/usr/lib/systemd/user-environment-generators/30-systemd-environment-d-generator
curl http://127.0.0.1:8080/healthz
systemctl is-active docker.service
systemctl is-enabled docker.service
id -nG
./profiles/zenbook-um3406ka/input/doctor.sh
./profiles/zenbook-um3406ka/voice/doctor.sh
./scripts/bootstrap.sh --profile zenbook-um3406ka --check
python -m unittest discover -s profiles -p 'test_*.py'
python profiles/zenbook-um3406ka/search/test_searxng_search.py -v
./tools/ci-check.sh
./tools/check-public-repo.sh
git diff --check
```

## OSINT sources

1. Omarchy, [v4.0.0/v4.0.3 release history and Quickshell architecture](https://github.com/omacom/omarchy/releases).
2. Omarchy, [#11727 — Repeater/QML incubation SIGSEGV on Omarchy 4.0.3](https://github.com/omacom/omarchy/issues/11727).
3. Omarchy, [#11755 — audio Repeater race after PipeWire restart on 4.0.3](https://github.com/omacom/omarchy/issues/11755).
4. Quickshell, [#956 — freed EngineGeneration extension and `__dynamic_cast`](https://github.com/quickshell-mirror/quickshell/issues/956).
5. Quickshell, [#983 — Qt 6.11.2 `QUntypedPropertyBinding` reproducer](https://github.com/quickshell-mirror/quickshell/issues/983).
6. Omarchy, [#9552 — Fcitx5 and Hyprland XKB ownership conflict](https://github.com/omacom/omarchy/issues/9552).
7. Omarchy v4.0.3, [vendor `omarchy-fcitx5.service`](https://raw.githubusercontent.com/omacom/omarchy/v4.0.3/default/systemd/user/omarchy-fcitx5.service).
8. Omarchy v4.0.3, [first-run user-unit enablement](https://raw.githubusercontent.com/omacom/omarchy/v4.0.3/install/user/first-run/enable-user-units.sh).
9. Omarchy v4.0.3, [Fcitx supervision migration](https://raw.githubusercontent.com/omacom/omarchy/v4.0.3/migrations/1785167800.sh).
10. Omarchy v4.0.3, [KeyboardLayout virtual-keyboard handling](https://raw.githubusercontent.com/omacom/omarchy/v4.0.3/shell/plugins/bar/widgets/KeyboardLayout.qml).
11. Omarchy, [keyboard and mouse manual](https://github.com/omacom/omarchy/blob/quattro/manual/34-keyboard-mouse-trackpad.md).
12. Omarchy, [#483 — Fcitx5 and multiple Hyprland layouts](https://github.com/basecamp/omarchy/issues/483).
13. Omarchy, [#9373 — binaries unavailable through the 4.x dispatcher](https://github.com/omacom/omarchy/issues/9373).
14. Omarchy, [#8438 — incompatible Qt/quickshell package pairing during 4.0.1 migration](https://github.com/omacom/omarchy/issues/8438).
15. Fcitx, [Wayland guidance on GTK/Qt environment variables and native text input](https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland/en).
16. ArchWiki, [Input method guidance for disabling an input-method framework](https://wiki.archlinux.org/title/Input_method).
17. SearXNG, [official Docker/Compose installation and management](https://docs.searxng.org/admin/installation-docker.html).
18. SearXNG, [server bind address, port, and secret settings](https://docs.searxng.org/admin/settings/settings_server.html).
