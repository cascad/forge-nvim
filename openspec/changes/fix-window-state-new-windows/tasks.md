# Tasks

## 1. Тестовая обвязка и красные тесты

- [x] 1.1 Взять общий поддельный `wezterm` (`tests/wezterm/fake_wezterm.lua`), если его уже принёс `add-wezterm-spec-checks` или `fix-copy-clobbers-clipboard`. Если его нет — завести по design `add-wezterm-spec-checks`, решение 3; второй подделки не заводить. Дополнить тем, что нужно по design D7: `gui.screens()` с заданным активным экраном или с ошибкой; поддельное окно, которое отдаёт заданные overrides и записывает вызовы `set_inner_size`, `set_position`, `set_config_overrides`; файл состояния как таблица в памяти. Проверка: `nvim -l tests/wezterm/window-state.test.lua` загружает `wezterm.lua` для видов `x86_64-pc-windows-msvc` и `aarch64-apple-darwin` без ошибок, проверка «загрузка» зелёная (windows).
- [x] 1.2 Написать в `tests/wezterm/window-state.test.lua` проверки (а)–(ж) из design D7. Проверка: на текущем `wezterm.lua` запуск завершается с кодом ≠ 0; красные (а), (б), (в), (г), (д), (ж), зелёная (е). Так видно, что тест ловит все три расхождения (windows).
- [x] 1.3 Если `add-wezterm-spec-checks` ещё не применён — добавить команду `nvim -l tests/wezterm/window-state.test.lua` в раздел «Проверки» `CLAUDE.md`; если применён — убедиться, что файл подхватывает `nvim -l tests/run.lua --id WT-STATE-2`. Проверка: команда, запущенная дословно из корня репо, печатает список проверок (windows).

## 2. Размер и положение новых окон (WT-STATE-2, WT-STATE-4, WT-PANE-7)

- [x] 2.1 Реализовать «принять окно» по design D3 и D4: чистые функции размера и положения; обработчик `window-config-reloaded`, который работает только для окна с overrides `nil`; последний шаг — overrides `{}`, и при ошибке тоже; `wezterm.log_info` с id окна, источником размера и итогом, `wezterm.log_warn` при ошибке. Удалить обработчик `gui-startup`, второго места, где задаётся размер окна, не оставлять. Проверка: зелёные (а), (б), (в), (г), (ж) в `nvim -l tests/wezterm/window-state.test.lua`; `wezterm --config-file F:/repo/forge-nvim/wezterm.lua ls-fonts` — в stderr нет `ERROR` (windows).
- [ ] 2.2 Проверить вручную на Windows после полного перезапуска WezTerm (все окна закрыты; см. design, Migration Plan). Сценарии WT-STATE-2:
  - Ctrl+Shift+N;
  - `wezterm cli spawn --new-window` из панели;
  - повторный запуск ярлыком, пока WezTerm работает;
  - «Размер ещё не сохранён» — файл состояния временно переименован;
  - «Сохранено в этой же сессии»;
  - «Уже открытые окна не двигаются» — Ctrl+Shift+S, Ctrl+Shift+R, Ctrl+`=`, Ctrl+`0`;
  - «Возврат в воркспейс».

  Там же сценарий WT-PANE-7 «Новое окно» и сценарии WT-STATE-1 «Запуск с программой вместо шелла» (`wezterm start -- nvim`) и «Положение из командной строки» (`wezterm start --position 10,10`). Размер сверяется по строке журнала «принять окно» в debug overlay (режим WINDOWS, `d`), положение — по центру экрана. Проверка: все сценарии совпали со спекой этого change, в журнале по строке на каждое новое окно и нет `log_warn`, результаты записаны для FIXLOG (windows).
- [ ] 2.3 Передать владельцу шаги для Mac: Cmd+N, повторный запуск из Dock при работающем WezTerm, `wezterm cli spawn --new-window`, «Возврат в воркспейс», там же прогнать `nvim -l tests/wezterm/window-state.test.lua`. Проверка: результат владельца записан в запись FIXLOG из 2.6; пока его нет, там стоит «на Mac не проверено» (macos).
- [x] 2.4 Поправить комментарии `wezterm.lua` по design D8: шапку (сейчас строки 29-33) — новые окна ставятся в центр, уже открытые сохранение не меняет; комментарий у долей экрана (сейчас 38-39) — доля действует для каждого окна, пока размер не сохранён. Проверка: `grep -n "ТОЛЬКО для первого запуска" wezterm.lua` пуст, шапка не противоречит WT-STATE-2 (windows).
- [x] 2.5 Обновить в `docs/WEZTERM.md` строку `Ctrl+Shift+S`: «так открываются все новые окна — по центру экрана; уже открытые окна не меняются». Сейчас это §8; если `sync-docs-with-baseline` уже переписал файл, строка ищется в его разделе «Окно и шрифт». Проверка: строка не противоречит WT-STATE-2 и WT-STATE-3 из `openspec/changes/fix-window-state-new-windows/specs/`, `grep -n "уже открытые окна не меняются" docs/WEZTERM.md` находит её (windows).
- [x] 2.6 Дописать в `nvim_forge/FIXLOG.md` новую нумерованную запись «Проблема → Причина → Решение → Файлы» про размер и шрифт новых окон и повторный сброс шрифта (одна запись на весь change). В ней строки `Спека: WT-STATE-2 (MODIFIED)`, `Спека: WT-STATE-4 (MODIFIED)`, `Спека: WT-PANE-7 (MODIFIED)` и «Проверено: …» с результатами 1.2, 2.2 и 2.3; §32 не переписывать. Проверка: `grep -n "Спека: WT-STATE-2 (MODIFIED)" nvim_forge/FIXLOG.md` находит запись, прежние записи в `git diff` не изменены (windows).

## 3. Шрифт новых окон и сброс шрифта (WT-STATE-5, WT-STATE-7)

- [x] 3.1 Переделать сброс в `change_font_size(nil)` по design D6: два вызова overrides — с `font_size` из файла (без файла 12), затем без `font_size`; прочие поля overrides сохраняются, `nil` не передаётся никогда. Проверка: зелёные (д) и (е), весь `nvim -l tests/wezterm/window-state.test.lua` зелёный (windows).
- [ ] 3.2 Проверить вручную на Windows сценарии:
  - WT-STATE-5 «Сохранение в этой же сессии и новое окно» и «Перечитывание не трогает шрифт, изменённый клавишами»;
  - WT-STATE-7 «Повторный сброс не видит новое сохранение» и «Сброшенное окно следует за файлом»;
  - регресс WT-STATE-3 «Режим WINDOWS не выключается».

  Шрифт сравнивается по числу столбцов (`$Host.UI.RawUI.WindowSize.Width` в pwsh) в окнах одного размера. Проверка: все сценарии совпали со спекой этого change, результаты записаны для FIXLOG (windows).
- [ ] 3.3 Передать владельцу шаги для Mac: Cmd+`=`, Cmd+Shift+S, Cmd+N — новое окно с сохранённым шрифтом; Cmd+`0` дважды с сохранением из другого окна между нажатиями — шрифт из файла. Проверка: результат владельца записан в запись FIXLOG; пока его нет, там стоит «на Mac не проверено» (macos).
- [x] 3.4 Поправить комментарий у `change_font_size` (сейчас строки 323-328): сброс при каждом нажатии пересчитывает конфиг окна в два шага, после сброса окно снова следует за файлом. Проверка: комментарий над `local function change_font_size` называет оба шага и не противоречит WT-STATE-7 и design D6; фразы «сброс к config.font_size» в файле нет (`grep -n "сброс к config.font_size" wezterm.lua` пуст) (windows).
- [x] 3.5 Обновить в `docs/WEZTERM.md` строку `Ctrl/Cmd + 0` на «сбросить шрифт к сохранённому — при каждом нажатии, в том числе повторном» и дополнить строку `Ctrl+Shift+S`: новые окна открываются с сохранённым шрифтом, открытые — после `Ctrl+Shift+R`. Раздел — как в 2.5. Проверка: обе строки не противоречат WT-STATE-5 и WT-STATE-7 из `openspec/changes/fix-window-state-new-windows/specs/`, `grep -n "в том числе повторном" docs/WEZTERM.md` находит строку (windows).
- [x] 3.6 Дописать в запись FIXLOG из 2.6, пока она не закоммичена, строки `Спека: WT-STATE-5 (MODIFIED)` и `Спека: WT-STATE-7 (MODIFIED)` и результаты 3.2 и 3.3. Если группа 2 уже закоммичена отдельно, сделать новую запись со ссылкой на § из 2.6, а старую не трогать. Проверка: `grep -n "Спека: WT-STATE-7 (MODIFIED)" nvim_forge/FIXLOG.md` находит строку, закоммиченные записи в `git diff` не изменены (windows).

## 4. Интеграция

- [x] 4.1 Финальный прогон. Проверка (windows):
  - `nvim -l tests/wezterm/window-state.test.lua` — все проверки зелёные, код 0;
  - если `add-wezterm-spec-checks` применён — `nvim -l tests/run.lua` зелёный, эталон `tests/wezterm/golden/config.*.lua` обновлён осознанно через `--update-golden` (в списке событий нет `gui-startup`, есть `window-config-reloaded`), diff эталона просмотрен;
  - `wezterm --config-file F:/repo/forge-nvim/wezterm.lua ls-fonts` — stderr без `ERROR`;
  - `openspec validate fix-window-state-new-windows --type change --strict --no-interactive` — valid.
