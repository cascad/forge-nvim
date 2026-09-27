# Proposal

## Why

При проверке базовой линии нашлись 32 расхождения документации и комментариев с кодом: divergences 11, 12, 17–27, 38–45, 54–59 и 67–71 из `baseline_divergences.json`. Главные из них такие. `docs/WEZTERM.md` описывает удалённый одноразовый LEADER, а на Ctrl+Shift+K/L у него старые действия: на деле это фокус на панель выше и правее (WT-KEYS-3, WT-PANE-2). Документ обещает, что Ctrl+., Ctrl+; и Shift+Enter доходят до nvim через kitty, хотя на Windows kitty выключен (WT-KBD-6). `nvim_forge/README.md` неверно описывает установщики (MAC-INST-10, WT-LOAD-13). В `wezterm.lua` комментарии противоречат коду: Ctrl+Shift+J назван клавишей Neovim, стоит фраза «оставляем стандартные хоткеи», упомянута несуществующая `min_content_width`. Теперь у поведения есть спеки с ID. Поэтому руководство можно вывести из них, а комментарии заменить ссылками на требования. Сейчас документ посылает пользователя к клавишам, которые делают не то, что в нём написано.

## What Changes

Поведение не меняется. Правятся только тексты, плюс удаляется одна строка кода, которая ничего не делает.

- `docs/WEZTERM.md` переписывается как руководство, выведенное из спек `wezterm-*` (код на момент применения). У каждого раздела указаны ID требований, у таблиц клавиш есть колонка «Спека». Модель LEADER заменяется режимом WINDOWS: вход, выход, таймаут, бейджи, какие команды оставляют режим (WT-WIN-*, WT-UI-12). Исправляются Ctrl+Shift+H/J/K/L, Ctrl+Shift+Delete и `d` (debug overlay). Уточняются: подтверждение закрытия панели (WT-PANE-4), Super-сочетания шрифта на Windows (WT-KEYS-3), тип поиска Ctrl+R, память шаблона и Esc в поиске (WT-SCROLL-9, WT-SCROLL-11), H/M/L (WT-SCROLL-6), метки QuickSelect на русской раскладке и Shift+метка (WT-SCROLL-12), выгрузка `b` (WT-SCROLL-13, WT-SCROLL-14). Раздел «отдано nvim» переписывается по WT-KEYS-4, WT-KEYS-7 и WT-KBD-6. Divergences 18, 19, 22, 23, 26, 40–45, 55, 57, 58, 70.
- `nvim_forge/README.md`. Абзац об установке на macOS пишется по MAC-INST-2/3/10, пометка «macOS script: fixed» убирается. В списке переменных `FORGE_NVIM_DEPS_ONLY` и `FORGE_NVIM_SKIP_WEZTERM` становятся общими для Linux и macOS, добавляется `FORGE_NVIM_FORCE_WEZTERM` (Linux). Divergences 11 и 12.
- Справочники `nvim_forge/HOTKEYS.md` и `nvim_forge/KEYBINDINGS.md` получают пометку «на Windows под WezTerm не работает (WT-KBD-6)» с альтернативой у каждой строки, где такое сочетание есть. Руководства `nvim_forge/QUICKSTART.md`, `PANELS.md` и `COOKBOOK.md` получают по одной такой оговорке в начале. Divergences 23 и 24.
- В `wezterm.lua` исправляются комментарии. Шапка и секция клавиатуры про kitty (WT-KBD-1/2/6). Список «занятых Neovim» заменяется ссылкой на WT-KEYS-4. Убирается фраза «оставляем стандартные хоткеи» (WT-KEYS-1). Исправляются комментарии про шрифтовые Super-привязки (WT-KEYS-3), `SendKey` и Ctrl+C (WT-KBD-7), полосу прокрутки (WT-SCROLL-3, WT-UI-7), анимацию курсора (WT-UI-9), бейдж (WT-UI-12), имена шрифта (WT-UI-4), каталог новой панели (WT-PANE-12) и выгрузку `b` (WT-SCROLL-13). Удаляется строка `text:gsub("%s+$", "\n")`: на целевой версии WezTerm она ничего не меняет. Divergences 17, 20, 21, 25, 27, 38, 39, 54, 56, 59, 67, 68, 69, 71.
- `nvim_forge/FIXLOG.md` получает новую запись. В ней перечислено, какие утверждения в §16, §17 и записях 2026-05-31 и 2026-08-01 неточны и где теперь верное описание (по ID). Старые записи не правятся. Divergence 27, а также исторические части 38, 57, 67, 69 и 71.

## Capabilities

### New Capabilities

Нет.

### Modified Capabilities

Нет. Требования не меняются, delta-спек нет, в `.openspec.yaml` стоит `skip_specs: true`.

## Impact

- Файлы: `docs/WEZTERM.md` (переписывается целиком), `nvim_forge/README.md`, `nvim_forge/HOTKEYS.md`, `nvim_forge/KEYBINDINGS.md`, `nvim_forge/QUICKSTART.md`, `nvim_forge/PANELS.md`, `nvim_forge/COOKBOOK.md`, `wezterm.lua` (комментарии и одна строка без эффекта), `nvim_forge/FIXLOG.md` (дописывается запись).
- Не затрагиваются: `openspec/specs/**`, установщики, привязки клавиш и поведение WezTerm. `wezterm show-keys` до и после даёт одинаковый набор.
- Связь с соседними changes. `fix-windows-mode-modality`, `change-search-enter-accept`, `fix-window-state-new-windows`, `resolve-key-ownership-conflicts`, `fix-copy-clobbers-clipboard`, `fix-macos-installer` и `add-linux-installer-parity` меняют поведение и будут править те же разделы `docs/WEZTERM.md` и `nvim_forge/README.md`. ID в заголовках разделов показывают, где именно. Эти changes решают, каким поведение должно быть (например, Super-шрифт на Windows и клавиши WT-KBD-6 — в `resolve-key-ownership-conflicts`); здесь описывается то, что есть. Дрейф комментариев в установщиках (divergences 13–15) и WT-WIN-11 (divergence 60) исправляется в своих changes, не здесь.
