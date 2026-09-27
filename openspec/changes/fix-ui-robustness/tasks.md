# Tasks

## 1. Пробы и тестовая обвязка

- [x] 1.1 Пробы на машине владельца, до кода (design D3). Пробный конфиг лежит вне репо, в `%TEMP%`, и выводит результаты через `wezterm.log_error` в stderr `wezterm --config-file <проба> ls-fonts`. Что проверить:
  - видит ли `wezterm.glob("<LOCALAPPDATA>/Microsoft/WindowsApps/pwsh.exe")` псевдоним;
  - есть ли `pwsh.exe` в `wezterm.read_dir("<LOCALAPPDATA>/Microsoft/WindowsApps")`;
  - время `ls-fonts` с проверкой и без;
  - `wezterm start -- "%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe" -NoLogo` открывает окно, где `$PSVersionTable.PSVersion.Major` — 7.

  Проверка: для каждого пункта записан результат (видит / не видит, миллисекунды, версия) для FIXLOG; по ним выбран способ из design D3. Если ни один способ не видит псевдоним или запуск по полному пути не работает, задачи группы 2 не начинаются, change возвращается владельцу через `/opsx:update` (windows).
- [x] 1.2 Взять общий поддельный `wezterm` (`tests/wezterm/fake_wezterm.lua`), если его уже принёс `add-wezterm-spec-checks` или `fix-copy-clobbers-clipboard`. Если его нет — завести по design `add-wezterm-spec-checks`, решение 3; второй подделки не заводить. Дополнить по design D7:
  - `glob` и `read_dir` поверх таблицы каталогов;
  - `io.open`, который на псевдониме падает, как CRT;
  - `font_with_fallback`, который записывает имена;
  - `mux.get_active_workspace`, `column_width`, `truncate_right`;
  - поддельные вкладки и панели для `format-tab-title`.

  Проверка: `nvim -l tests/wezterm/ui.test.lua` загружает `wezterm.lua` для `x86_64-pc-windows-msvc`, `aarch64-apple-darwin` и `x86_64-unknown-linux-gnu` без ошибок, проверка «загрузка» зелёная (windows).
- [x] 1.3 Написать в `tests/wezterm/ui.test.lua` проверки (а)–(д) из design D7. Проверка: на текущем `wezterm.lua` запуск завершается с кодом ≠ 0; красные (а) (псевдоним не найден), (б) (в списке пять имён), (в), (г) и (д) (обработчика `format-tab-title` нет); зелёная только «загрузка» (windows).
- [x] 1.4 Если `add-wezterm-spec-checks` ещё не применён — добавить команду `nvim -l tests/wezterm/ui.test.lua` в раздел «Проверки» `CLAUDE.md`; если применён — убедиться, что файл подхватывает `nvim -l tests/run.lua --id WT-UI-15`. Проверка: команда, запущенная дословно из корня репо, печатает список проверок (windows).

## 2. PowerShell 7 шеллом по умолчанию (WT-UI-1)

- [x] 2.1 Вне репо, до правки кода (design D4, Migration Plan): добавить в `Documents\PowerShell\Microsoft.PowerShell_profile.ps1` строку dot-source профиля Windows PowerShell. Путь считается от `$PROFILE` через `Split-Path`, срабатывает только при `Test-Path`. Строки профиля 5.1, которые pwsh 7 не понимает, обвести проверкой `$PSVersionTable.PSVersion.Major`. Проверка вручную, в `pwsh -NoLogo`, запущенном из Пуска (windows):
  - при старте нет ошибок;
  - `(Get-PSReadLineKeyHandler -Chord Tab).Function` — `MenuComplete`;
  - `[Console]::OutputEncoding.WebName` — `utf-8`;
  - `Get-Content` русского UTF-8-файла без BOM читается без кракозябр;
  - `powershell.exe` ведёт себя как раньше.
- [x] 2.2 Переписать поиск шелла по design D3 выбранным в 1.1 способом:
  - PATH читается там же, где остальные факты о платформе;
  - функция поиска получает строку PATH и функцию «есть ли файл»;
  - в `default_prog` идёт найденный полный путь, без находки — `powershell.exe -NoLogo`.

  Проверка: зелёная (а) в `nvim -l tests/wezterm/ui.test.lua`; `wezterm --config-file F:/repo/forge-nvim/wezterm.lua ls-fonts` — в stderr нет `ERROR` (windows).
- [ ] 2.3 Проверить вручную на Windows после перезапуска WezTerm сценарии WT-UI-1 «PowerShell 7 из Microsoft Store» и «Смена диска командой cd». Там же — что всё из 2.1 действует в новой вкладке WezTerm. И регрессы: WT-PANE-4 «Только шелл» (Ctrl+Shift+W закрывает панель с pwsh без вопроса), WT-PANE-12 (каталог новой панели) и WT-SCROLL-13 (выгрузка истории в nvim из панели pwsh). Проверка: `$PSVersionTable.PSVersion.Major` — 7, `(Get-Process -Id $PID).Parent.ProcessName` — `wezterm-gui`, остальные сценарии совпали со спекой, результаты записаны для FIXLOG (windows).
- [x] 2.4 Поправить комментарии у `exe_in_path` и `default_prog` (сейчас `wezterm.lua:113-136`) по design D8. Проверка: `grep -n "реально есть в PATH" wezterm.lua` пуст, комментарий называет псевдоним Store и запуск найденного пути (windows).
- [x] 2.5 Обновить `docs/WEZTERM.md`. Строка про шелл (сейчас §9, строка 218): «PowerShell 7 (`pwsh`), если он установлен — из Microsoft Store или MSI/winget, иначе `powershell.exe`». Добавить абзац «Профиль PowerShell 7» со строкой dot-source из 2.1 и тремя командами проверки. Если `sync-docs-with-baseline` уже переписал файл — в его разделе «Различия Windows и macOS». Проверка: строка не противоречит WT-UI-1 из `openspec/changes/fix-ui-robustness/specs/`; `grep -n "Microsoft.PowerShell_profile.ps1" docs/WEZTERM.md` находит абзац (windows).
- [x] 2.6 Дописать в `nvim_forge/FIXLOG.md` новую нумерованную запись «Проблема → Причина → Решение → Файлы» (одна на весь change). В ней:
  - строка `Спека: WT-UI-1 (MODIFIED)`;
  - «Проверено: …» с результатами 1.1, 1.3, 2.1 и 2.3;
  - в «Файлах» — `wezterm.lua` и профиль `Documents\PowerShell\Microsoft.PowerShell_profile.ps1` (вне репо).

  Записи 2026-05-31 и §18 не переписывать. Проверка: `grep -n "Спека: WT-UI-1 (MODIFIED)" nvim_forge/FIXLOG.md` находит запись, прежние записи в `git diff` не изменены (windows).

## 3. Запасные шрифты без окна ошибки (WT-UI-4)

- [x] 3.1 Оставить в `config.font` только «CaskaydiaCove NF» и «CaskaydiaCove Nerd Font» (design D5). Проверка (windows):
  - зелёная (б) в `nvim -l tests/wezterm/ui.test.lua`;
  - `wezterm --config-file F:/repo/forge-nvim/wezterm.lua ls-fonts` — stderr без `ERROR`, в списке CaskaydiaCove и встроенные шрифты;
  - `wezterm --config-file F:/repo/forge-nvim/wezterm.lua ls-fonts --text "abc"` — CaskaydiaCove.
- [x] 3.2 Проверить сценарий «Основной шрифт не установлен» пробным конфигом вне репо. Это копия `wezterm.lua`, где оба имени основного шрифта заменены несуществующим. Проверка (windows):
  - `ls-fonts --text "abc"` с пробой — JetBrains Mono;
  - `wezterm --config-file <проба> start` — окно «wezterm Configuration Error» с сообщением только про это имя, текст рисуется JetBrains Mono;
  - результат записан для FIXLOG.
- [ ] 3.3 Передать владельцу шаги для Mac: запустить WezTerm после `install-macos.sh` — окна «wezterm Configuration Error» нет; `wezterm ls-fonts --text "abc"` — CaskaydiaCove; прогнать `nvim -l tests/wezterm/ui.test.lua`. Проверка: результат владельца записан в запись FIXLOG; пока его нет, там стоит «на Mac не проверено» (macos).
- [x] 3.4 Поправить комментарий у `config.font` (сейчас `wezterm.lua:189-192`) по design D8 и проверить, что docs не описывают список запасных шрифтов. Проверка (windows):
  - `grep -n "Inconsolata\|Consolas\|Cascadia Mono" wezterm.lua docs/*.md README.md` находит только новое объяснение в комментарии, почему этих имён нет;
  - комментарий не противоречит WT-UI-4.
- [x] 3.5 Дописать в запись FIXLOG из 2.6, пока она не закоммичена, строку `Спека: WT-UI-4 (MODIFIED)` и результаты 3.1–3.3. Если запись уже закоммичена — новая запись со ссылкой на неё. Проверка: `grep -n "Спека: WT-UI-4 (MODIFIED)" nvim_forge/FIXLOG.md` находит строку, закоммиченные записи в `git diff` не изменены (windows).

## 4. Бейдж и имя воркспейса видны всегда (WT-UI-15, WT-UI-10, WT-UI-12, WT-UI-13)

- [x] 4.1 Добавить обработчик `format-tab-title` по design D6. Бейдж строит одна функция из одной таблицы режимов, её используют `update-right-status` и расчёт резерва. Прочие параметры панели вкладок не меняются. Проверка: зелёные (в), (г), (д) и весь `nvim -l tests/wezterm/ui.test.lua`; `wezterm --config-file F:/repo/forge-nvim/wezterm.lua ls-fonts` — stderr без `ERROR` (windows).
- [ ] 4.2 Проверить вручную на Windows после Ctrl+Shift+R. Окно растянуть до 120 столбцов по `$Host.UI.RawUI.WindowSize.Width` в pwsh. Сценарии:
  - WT-UI-15 «Бейдж обрезан» (4 вкладки), «Вкладки не помещаются» (5), «Мало вкладок» (2);
  - «Вход в режим не сдвигает вкладки» — Ctrl+Shift+Space и Ctrl+Shift+X;
  - «Окно уже правой части» — окно сужено мышью;
  - WT-UI-10 «Одна вкладка» и «Длинное название вкладки»;
  - в debug overlay нет предупреждений `format-tab-title`.

  Проверка: все сценарии совпали со спекой этого change, результаты записаны для FIXLOG (windows).
- [ ] 4.3 Передать владельцу шаги для Mac: те же сценарии WT-UI-15 с Cmd+T для вкладок. Проверка: результат владельца записан в запись FIXLOG; пока его нет, там стоит «на Mac не проверено» (macos).
- [x] 4.4 Поправить комментарии у панели вкладок (сейчас `wezterm.lua:238-242`) и у бейджа (сейчас 751-757): место справа резервируется в `format-tab-title`, бейдж виден всегда. Проверка: комментарии не противоречат WT-UI-15; `grep -n "format-tab-title" wezterm.lua` находит обработчик и ссылку на него у бейджа (windows).
- [x] 4.5 Обновить в `docs/WEZTERM.md` строку «Имя текущего воркспейса всегда видно справа в панели вкладок» (сейчас §4, строка 89): бейдж режима и имя воркспейса видны всегда, при нехватке места сужаются вкладки. Если `sync-docs-with-baseline` уже переписал файл — в его разделе про панель вкладок и режимы. Проверка: строка не противоречит WT-UI-15 и WT-UI-12 из `openspec/changes/fix-ui-robustness/specs/`, `grep -n "сужаются вкладки" docs/WEZTERM.md` находит её (windows).
- [x] 4.6 Дописать в запись FIXLOG из 2.6, пока она не закоммичена, строки `Спека: WT-UI-15 (MODIFIED)`, `Спека: WT-UI-10 (MODIFIED)`, `Спека: WT-UI-12 (MODIFIED)`, `Спека: WT-UI-13 (MODIFIED)` и результаты 4.2 и 4.3. Если запись уже закоммичена — новая запись со ссылкой на неё; запись 2026-08-01 не переписывать. Проверка: `grep -n "Спека: WT-UI-15 (MODIFIED)" nvim_forge/FIXLOG.md` находит строку, закоммиченные записи в `git diff` не изменены (windows).

## 5. Интеграция

- [x] 5.1 Финальный прогон. Проверка (windows):
  - `nvim -l tests/wezterm/ui.test.lua` — все проверки зелёные, код 0;
  - если `add-wezterm-spec-checks` применён — `nvim -l tests/run.lua` зелёный, эталон `tests/wezterm/golden/config.*.lua` обновлён осознанно через `--update-golden` (новые `default_prog` и `font`, событие `format-tab-title`), diff эталона просмотрен;
  - `wezterm --config-file F:/repo/forge-nvim/wezterm.lua ls-fonts` — stderr без `ERROR`;
  - `openspec validate fix-ui-robustness --type change --strict --no-interactive` — valid.
