# Proposal

## Why

На Windows часть сочетаний nvim_forge не доходит до nvim отдельными клавишами (WT-KBD-6, WT-KEYS-4; divergences 21–24, 31). WezTerm их пропускает, но между ним и nvim стоит ConPTY. Kitty там включить нельзя: ConPTY перекодирует клавиши сам, а kitty-кодировщик WezTerm ломает Shift+кириллицу (FIXLOG §41). Поэтому nvim получает другие клавиши и выполняет чужие привязки:

- Ctrl+Shift+F/P/E/D приходят как `<C-f>`/`<C-p>`/`<C-e>`/`<C-d>`: вместо панели поиска запускается поиск по буферу, вместо палитры — поиск файла, вместо отладки — прокрутка.
- Ctrl+Shift+F5 приходит как `<F41>`.
- Ctrl+. приходит как `<C-n>`, Ctrl+Enter — как `<NL>`. Ctrl+Enter в нормальном режиме переключает нижнюю панель (`<NL>` = `<C-j>`), а визуальный `<C-CR>` «Run selection in pwsh», сделанный как раз для Windows, не срабатывает.
- Ctrl+/ на русской раскладке приходит как `<C-n>`.
- Ctrl+Space не приходит вовсе.

Воспроизведение: в nvim_forge под WezTerm на Windows нажать Ctrl+Shift+F — запускается поиск по буферу, а не панель поиска. В `nvim --clean` выполнить `:lua print(vim.fn.keytrans(vim.fn.getcharstr()))` и нажать Ctrl+Shift+F — печатается `<C-F>`. Наблюдения сняты пробой через тот же conpty.dll, что поставляется с WezTerm; в реальном GUI сочетания не нажимались (divergence 31).

Где в коде:
- `wezterm.lua:163-164` — на Windows win32-input-mode и kitty выключен;
- привязки nvim_forge: `plugins/search.lua:8`, `plugins/telescope.lua:43`, `plugins/neo-tree.lua:197`, `plugins/dap.lua:1182, 1229, 1311`, `config/keymaps.lua:519-535` (`<C-/>`), `616-618` (`<C-.>`), `630` (`<C-CR>`), `plugins/completion.lua:141` (`<C-Space>`).

Владелец выбрал вариант Q8 = A (2026-09-27): WezTerm на Windows подменяет эти сочетания отдельными клавишами, которые проходят через ConPTY, по образцу Ctrl+[ → F13 (WT-KEYS-6), и только в панели, где работает nvim_forge. Выделено из `resolve-key-ownership-conflicts` в отдельный change.

## What Changes

- **Сначала проба, потом реализация.** Харнесс через `conpty.dll` из поставки WezTerm, в роли терминала, с настоящим nvim отвечает на три вопроса:
  - доходит ли до терминала объявление nvim (OSC 1337 SetUserVar) через ConPTY;
  - какие подменные клавиши nvim получает отдельными клавишами на обеих раскладках, так что они не совпадают ни с одним физическим нажатием;
  - как повторить исходное нажатие для остальных программ без изменений.

  Проба кладётся в `tests/`. Если на какой-то вопрос ответа нет, change останавливается и возвращается владельцу.
- **nvim_forge объявляет себя терминалу.** Пользовательская переменная панели `FORGE_NVIM` со значением — версией таблицы подмен — ставится при запуске и возврате из приостановки и снимается при выходе и приостановке. Образец — `IS_NVIM` у smart-splits.nvim. Есть выключатель на стороне nvim_forge.
- **WezTerm на Windows подменяет сочетания.** Ctrl+Shift+F, Ctrl+Shift+P, Ctrl+Shift+E, Ctrl+Shift+D, Ctrl+Shift+F5, Ctrl+., Ctrl+Enter, Ctrl+/ и Ctrl+Space (и другие сочетания того же рода, если их найдёт перечисление привязок nvim_forge на шаге пробы) привязаны по физической позиции.
  - В объявленной панели WezTerm шлёт вместо сочетания подменную клавишу.
  - В остальных панелях он повторяет исходное нажатие: шелл, Claude Code и nvim без nvim_forge разницы не видят.
  - На macOS и Linux ничего не меняется.
- **nvim_forge выполняет подменную клавишу так же, как исходное сочетание** во всех режимах, то есть так, как на macOS с kitty.
- **Проверки.** Фикстура пробы; тесты конфига на поддельном `wezterm` и привязок nvim_forge на инфраструктуре `add-wezterm-spec-checks`. Сверка пересечений WT-KEYS-7 не считает подмены пересечением. Итог — ручная проверка в GUI на Windows на обеих раскладках.
- Документы (docs/WEZTERM.md, nvim_forge/HOTKEYS.md, nvim_forge/KEYBINDINGS.md, комментарии `wezterm.lua` о клавиатуре) и запись FIXLOG со строками `Спека:`.
- Известное ограничение, записанное в спеке: если nvim_forge завершился аварийно и не снял объявление, шелл этой панели получает подменные клавиши, пока объявление не сбросят. Образец — WT-KBD-2, «флаги kitty после аварийного выхода».

## Capabilities

### New Capabilities

Нет.

### Modified Capabilities

- `wezterm-key-ownership`:
  - ADDED WT-KEYS-10 — подмена сочетаний nvim_forge на Windows;
  - MODIFIED WT-KEYS-1, WT-KEYS-3, WT-KEYS-4 — в панели nvim_forge на Windows эти сочетания больше не уходят как есть.
- `wezterm-keyboard-protocol`:
  - ADDED WT-KBD-9 — объявление nvim_forge (`FORGE_NVIM`) и требования к подменным клавишам;
  - MODIFIED WT-KBD-6 — что получает nvim на Windows без объявления и с ним;
  - MODIFIED WT-KBD-7 — клавиши, которые WezTerm шлёт сам, теперь не только F13 и Ctrl+C.

## Impact

- `wezterm.lua`: таблица подмен и привязки с колбэком в ветке Windows, событие `user-var-changed` для журнала, комментарии о клавиатуре.
- nvim_forge (пока без спек): новый модуль с таблицей подмен и объявлением, подключение в `init`/`config`; `lazy`-привязки не меняются.
- `tests/`:
  - `tests/wezterm/conpty/` — проба на Python (ctypes, только Windows) и фикстура;
  - ожидания в `tests/wezterm/key-ownership.test.lua` (`add-wezterm-spec-checks`);
  - ручные пункты в `tests/manual/wezterm-{windows,macos}.md`.
- Документы: docs/WEZTERM.md (раздел о том, что отдано nvim и что nvim получает), nvim_forge/HOTKEYS.md, nvim_forge/KEYBINDINGS.md; nvim_forge/FIXLOG.md.
- Зависимости и порядок:
  - `resolve-key-ownership-conflicts` архивируется раньше: delta WT-KEYS-3 и WT-KBD-6 здесь написана поверх его delta;
  - от `add-wezterm-spec-checks` нужны раннер, поддельный `wezterm` и `nvim_keymaps` — его группы 1–3;
  - `sync-docs-with-baseline` ставит в документах пометки «не доходит (WT-KBD-6)», этот change их снимает для сочетаний из таблицы.
- Вне охвата:
  - F-клавиши с модификаторами (`<S-F5>` → `<F17>` и т. п.) — они доходят отдельными клавишами, это правка имён на стороне nvim_forge;
  - Ctrl+; и Shift+Enter — nvim_forge на них ничего не вешает;
  - kitty на Windows;
  - поведение на macOS и Linux.
