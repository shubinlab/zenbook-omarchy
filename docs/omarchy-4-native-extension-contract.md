# Omarchy 4: native extension contract

Статус: рабочий контракт проекта, проверен по установленному Omarchy `4.0.3-1` и исходникам ветки `quattro` 2026-09-14.

Актуальный umbrella execution plan: [`docs/superpowers/plans/2026-09-14-omarchy4-unified-improvement-and-github-sync.md`](superpowers/plans/2026-09-14-omarchy4-unified-improvement-and-github-sync.md). Input-specific subplan: [`docs/superpowers/plans/2026-09-14-omarchy4-native-input-regression.md`](superpowers/plans/2026-09-14-omarchy4-native-input-regression.md).

Этот документ ограничивает доработки `zenbook-omarchy` нативной архитектурой Omarchy 4. Он нужен, чтобы локальный профиль переживал обновления Omarchy и не исправлял симптом удалением vendor-компонента.

## Что является vendor-контрактом

Omarchy 4 — это Arch Linux + Hyprland + Lua-конфигурация Hyprland + один долгоживущий `omarchy-shell` на Quickshell. Пакетный источник находится в `$OMARCHY_PATH` (`/usr/share/omarchy` на этом хосте). Этот путь читается для анализа, но не редактируется профилем.

Vendor documentation:

- [Dotfiles](https://github.com/omacom/omarchy/blob/quattro/manual/31-dotfiles.md) определяет `~/.config` как пространство пользовательских изменений и запрещает считать `/usr/share/omarchy` пользовательским конфигом.
- [Hyprland config](https://github.com/omacom/omarchy/blob/quattro/config/hypr/hyprland.lua) сначала загружает defaults, затем `hypr.monitors`, `hypr.input`, `hypr.bindings`, `hypr.looknfeel` и `hypr.autostart`.
- [Keyboard manual](https://github.com/omacom/omarchy/blob/quattro/manual/34-keyboard-mouse-trackpad.md) задаёт обычные раскладки через `~/.config/hypr/input.lua` и одновременно говорит, что Fcitx5 запускается в каждой сессии для CapsLock/XCompose и будущих IME.
- [Shell plugins manual](https://github.com/omacom/omarchy/blob/quattro/manual/32-shell-plugins.md) определяет пользовательские плагины в `~/.config/omarchy/plugins/`, их manifest и проверку `omarchy plugin validate`.
- [Shell source contract](https://github.com/omacom/omarchy/blob/quattro/docs/omarchy-shell.md) описывает один процесс Quickshell, IPC и persisted state в `~/.config/omarchy/shell.json`.

Из этого следуют обязательные правила:

| Слой | Нативное место | Правильный способ расширения | Что запрещено профилю |
|---|---|---|---|
| Hyprland | `~/.config/hypr/*.lua` | user override после vendor defaults; `hyprctl reload`, затем `hyprctl configerrors` | править `/usr/share/omarchy/default/hypr/*` |
| Shell/bar | `~/.config/omarchy/shell.json` | `omarchy bar ...`, затем реальный shell/IPC check | редактировать vendor `shell.json`; рассчитывать на deep merge |
| Built-in plugin | `~/.config/omarchy/plugins/<user>.*` | `omarchy plugin clone`, `validate`, `restart shell` | править `$OMARCHY_PATH/shell/plugins/*` |
| Third-party plugin | `~/.config/omarchy/plugins/<id>` | `omarchy plugin add/update/enable`, review diff, `validate` | включать непроверенный unsandboxed QML в долгоживущий shell |
| Menu extension | `~/.config/omarchy/extensions/omarchy-menu.jsonc` | native menu extension + command check | заменять vendor menu source |
| Event automation | `~/.config/omarchy/hooks/<event>.d/` | `omarchy hook install`; idempotent executable hook | system-wide ad-hoc autostart, если есть native hook |
| User session app | `~/.config/hypr/autostart.lua` | `o.launch_on_start`, проверка cleanup после logout | самостоятельный duplicate lifecycle-owner |
| Vendor user service | systemd user unit из Omarchy | оставить `enable`, `graphical-session.target`, D-Bus и vendor env; добавлять только совместимый override | `mask`, удаление autoactivation или no-IME override без доказанного opt-out contract |
| Packages/installers | Omarchy package/native installer | `omarchy pkg add`, `omarchy install`, native installer | ручной пакетный обход, если он меняет ownership или lifecycle |

## Input contract для текущего Zenbook

Нативное разделение такое:

1. Hyprland XKB владеет физическим выбором обычных раскладок `us,ru`.
2. `omarchy-fcitx5.service` остаётся включённым и активным, потому что vendor использует Fcitx5 для XCompose/IME.
3. `INPUT_METHOD=fcitx`, `QT_IM_MODULE=fcitx`, `SDL_IM_MODULE=fcitx`, `XMODIFIERS=@im=fcitx` не подменяются на `none`.
4. Runtime `keyboard-us` и `hl-virtual-keyboard-fcitx5` не считаются drift только по имени. Проверяется фактический текст в Wayland-приложении.
5. Если Fcitx keyboard engine начинает отдавать приложению не ту раскладку, это compatibility defect между XKB и Fcitx, а не основание уничтожать XCompose-путь.

Именно поэтому текущий профиль сохраняет пустые объявленные keyboard layouts в `profiles/zenbook-um3406ka/input/fcitx5-profile`, но не отключает Fcitx. Эмулированная доставка текста уже прошла в GTK, Qt/QML и Chromium; физическое переключение layout внутри каждого toolkit остаётся отдельным hardware acceptance. Всплывашка `ru/en` возле курсора не является текущим vendor-индикатором: для обычных `us/ru` Omarchy показывает раскладку в top bar, а Fcitx запускается с отключённым `notificationitem`, чтобы не дублировать этот bar. Возврат cursor popup потребует отдельного opt-in эксперимента с доказательством, что Fcitx не становится вторым владельцем раскладки.

## Методология одной доработки

Каждое изменение выполняется одной гипотезой за раз:

1. **Source boundary.** Сначала прочитать установленный vendor source и официальный manual/source той же ветки. Зафиксировать версию Omarchy и выяснить, является ли поведение обязательным, default или opt-in.
2. **Owner map.** Назначить владельца: Hyprland, `omarchy-shell`, user hook, systemd user unit, native installer или профиль. Не создавать второй lifecycle-owner.
3. **Baseline.** Сохранить read-only факты: live config, service state, environment, process graph, IPC health и реальное UI/device состояние. Raw hardware output хранить только в ignored `runs/`.
4. **Smallest extension.** Выбрать минимальную user-scoped точку расширения. Для shell использовать `clone`/plugin API, для Hyprland — отдельный Lua override, для событий — hook, для пакета — `omarchy` helper.
5. **Static gate.** Выполнить syntax/schema/manifest checks. Для Hyprland обязательно `hyprctl reload` + `hyprctl configerrors`; для plugin — `omarchy plugin validate`; для shell — `omarchy-shell shell ping`.
6. **Runtime acceptance.** Проверить реальный target: окно, текст, click, service readiness, physical device или app behavior. `hyprctl devices`, `wtype` и наличие файла не заменяют physical acceptance.
7. **Red team.** Проверить restart/relogin/update boundary, D-Bus activation, duplicate processes, stale state, rollback и поведение при частично недоступной зависимости.
8. **OSINT cross-check.** Сравнить результат с vendor manual/source и открытыми upstream issues. Отдельно отметить факт, интерпретацию, гипотезу и неизвестное.
9. **Persistence.** Только после успешного red-team записать правило в профиль, doctor и этот контракт. Документировать оставшийся риск; не называть containment permanent fix.

## Red-team gates для этого репозитория

Перед завершением Omarchy-изменения должны пройти:

```bash
./scripts/bootstrap.sh --profile zenbook-um3406ka --check
./profiles/zenbook-um3406ka/input/doctor.sh
./tools/ci-check.sh
./tools/check-public-repo.sh
git diff --check
```

Для конкретного слоя добавляются:

```bash
# Hyprland/input
hyprctl reload
hyprctl configerrors
hyprctl getoption input:kb_layout
hyprctl getoption input:kb_options
systemctl --user is-enabled omarchy-fcitx5.service
systemctl --user is-active omarchy-fcitx5.service
fcitx5-remote -n

# Omarchy shell/plugins
omarchy plugin list --json
omarchy plugin validate ~/.config/omarchy/plugins/<id>
omarchy-shell shell ping

# Actual acceptance
# physical keyboard in GTK, Qt, Chromium and launcher;
# actual click/handler/window/service operation;
# re-check after shell restart and a fresh graphical login.
```

## Current input investigation state

Confirmed:

- Omarchy `4.0.3-1` is installed.
- Vendor Fcitx service is `enabled/active` with `/usr/bin/fcitx5 --disable notificationitem`.
- Vendor Fcitx environment is restored.
- Repository input files no longer mask or disable the vendor service.
- `input/doctor.sh` accepts the vendor-compatible single `keyboard-us` runtime fallback and rejects `keyboard-ru` or duplicate keyboard layouts.
- The earlier `wtype` result is invalid as proof of physical layout behavior.
- User physically verified both Alt+Shift orders, expected Latin/Cyrillic input, and CapsLock/XCompose in the native Foot test window; no typed content was persisted.

Not yet confirmed:

- Whether physical layout switching needs separate acceptance inside GTK, Qt and Chromium rather than the already-passed Foot test.
- Whether a Fcitx restart changes the active group or only restores the XCompose service.

Confirmed by red-team: after stopping the unit, `fcitx5-remote -n` starts a separate Fcitx process through D-Bus; starting systemd while that stray process exists enters `auto-restart`. The single-owner state is restored only after the stray process is terminated and the vendor unit is restarted. The physical Foot acceptance passed, and the emulated Wayland input path passed in GTK, Qt/QML and Chromium. Only a cross-toolkit mismatch in a future reproduction can justify a synchronized Fcitx/XKB adjustment or an explicitly documented opt-in XKB-only profile.

Reusable toolkit fixtures are `profiles/zenbook-um3406ka/input/gtk-input-acceptance.py`, `qt-input-acceptance.qml`, and `chromium-input-acceptance.html`. Launch each as a native Wayland window, focus it explicitly, inject a unique string with `wtype`, and read the GTK signal, Qt title, or Chromium title. This proves application input delivery, while physical layout switching remains a separate hardware test.

## Project policy

The repository's profile scripts may install user-scoped configuration and narrowly owned system services, but they must preserve Omarchy's native service, shell, plugin and update boundaries. Any exception requires a separate evidence record, an explicit opt-out name, rollback, and an upstream/source justification.
