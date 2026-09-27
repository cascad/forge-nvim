# Proposal

## Why

Сверка базовой линии нашла места, где владение клавишами между WezTerm и nvim_forge расходится с намерением владельца. Решения владельец принял 2026-09-27 (Q7, Q9, Q10, Q11; записаны в design.md, Decisions). Сочетания nvim_forge, которые на Windows не доходят до nvim (Q8), вынесены в отдельный change `add-nvim-chords-on-windows`.

- **WT-KEYS-7, баг (divergence 16).** Нарушен инвариант из комментария `wezterm.lua:413-421`: «всё, что WezTerm перехватил, до Neovim уже не долетит», поэтому прямые привязки WezTerm берутся из сочетаний, которых нет в nvim_forge. На деле `wezterm.lua:342` (`phys:V` + CTRL → `PasteFrom Clipboard`) забирает Ctrl+V на всех платформах, а `nvim_forge/lua/config/keymaps.lua:450-455` вешает `<C-v>` в режимах n/v/i/c. Эти привязки никогда не вызываются. Воспроизведение: в nvim_forge под WezTerm выполнить `:nmap <C-v> :echo 'hit'<CR>` и нажать Ctrl+V. `hit` не появится: WezTerm вставит буфер обмена как вставленный текст. Вторая сверка: `wezterm show-keys` (`CTRL v (Physical) -> PasteFrom(Clipboard)`) против lhs nvim_forge.
- **WT-KEYS-3 (divergences 25, 26).** Привязки шрифта на Super (Win+= / Win+- / Win+0, с Shift и без) висят и на Windows. Комментарий `wezterm.lua:372-386` и docs/WEZTERM.md §9 считают их маковскими, а часть этих сочетаний Windows забирает себе.
- **WT-KBD-4.** Правый Alt на Windows с русской раскладкой — это AltGr: правый Alt+8 вводит «₽», правый Alt+буква до программы не доходит. `send_composed_key_when_right_alt_is_pressed = false` на Windows ничего не меняет. Первое предложение требования («Alt как Meta», SHALL) этого исключения не называет.
- **WT-KEYS-9 (divergence 34).** Перехват Alt+Space и Alt+F4 оконным слоем на Windows выведен из исходника WezTerm, в GUI не проверялся.

## What Changes

- **Ctrl+V (WT-KEYS-7), решение Q7 = A.** Мёртвые привязки `<C-v>` в режимах n/v/i/c удаляются из nvim_forge. Вставка и так приходит через WezTerm, блочное выделение — Ctrl+Q (FIXLOG 2026-05-31). WT-KEYS-7 становится строгим инвариантом: перехваты WezTerm пересекаются с lhs nvim_forge только в Ctrl+C на Windows. **BREAKING** для nvim_forge в других терминалах: там Ctrl+V вернётся к штатному смыслу Neovim.
- Инвариант WT-KEYS-7 проверяет тест `tests/wezterm/key-ownership.test.lua` из change `add-wezterm-spec-checks` (его design, решение 6). Здесь только сужается список исключений до Ctrl+C на Windows, второго теста нет.
- Из-за удаления `<C-v>` меняется сценарий WT-KBD-6 про Ctrl+; на русской раскладке: nvim по-прежнему получает `<C-v>`, но теперь это встроенное блочное выделение, а не вставка.
- **Super-привязки шрифта (WT-KEYS-3, WT-STATE-6, WT-STATE-7), решение Q9 = A.** Super-варианты вешаются только в ветке «не Windows». На Windows вне режимов 48 перехватов вместо 54, на macOS по-прежнему 61. **BREAKING**: Win+=/-/0 на Windows перестают менять шрифт в тех редких случаях, когда ОС их пропускала.
- **Правый Alt на Windows (WT-KBD-4), решение Q10 = A.** Поведение не меняется: правый Alt остаётся AltGr («₽» доступен), Meta — левый Alt. Это записывается как намерение: SHALL требования получает явное исключение и сценарий, комментарий `wezterm.lua:167-168` уточняется.
- **Alt+Space и Alt+F4 на Windows (WT-KEYS-9), решение Q11 = A.** Поведение и спека не меняются: перехват зашит в оконный слой WezTerm (`window/src/os/windows/window.rs`) и привязкой не отменяется, а nvim_forge эти сочетания не использует. Ручная проверка — пункт W2 чек-листа `review-baseline`.
- **Сочетания nvim_forge на Windows (WT-KEYS-4, WT-KBD-6), решение Q8 = A** — отдельным change `add-nvim-chords-on-windows`: подмена сочетаний в WezTerm только для панели с nvim_forge и проба через conpty.dll перед реализацией.
- Обновляются документы, описывающие эти клавиши (docs/WEZTERM.md, nvim_forge/HOTKEYS.md, nvim_forge/KEYBINDINGS.md), и для каждой группы задач дописывается запись FIXLOG со строками `Спека:`.

## Capabilities

### New Capabilities

Нет.

### Modified Capabilities

- `wezterm-key-ownership`:
  - WT-KEYS-3 — Super-сочетания шрифта только вне Windows, 48 перехватов на Windows;
  - WT-KEYS-7 — строгий инвариант, единственное пересечение — Ctrl+C на Windows, `<C-v>` у nvim_forge нет.
- `wezterm-keyboard-protocol`:
  - WT-KBD-4 — правый Alt на Windows с AltGr остаётся AltGr как намерение;
  - WT-KBD-6 — сценарий про Ctrl+; на русской раскладке (блочное выделение вместо вставки).
- `wezterm-window-state`:
  - WT-STATE-6 и WT-STATE-7 — Super-варианты шрифта только на macOS и Linux.

## Impact

- `wezterm.lua`: цикл шрифтовых привязок и комментарий к нему (`372-386`), комментарий к настройкам Alt (`167-168`).
- nvim_forge (пока без спек): `lua/config/keymaps.lua:445-455` — удаление `<C-v>`.
- `tests/`: ожидания в тестах `add-wezterm-spec-checks` (`key-ownership.test.lua`, `window-state.test.lua`), эталон `tests/wezterm/golden/keys.windows.lua`; ручные пункты в `tests/manual/wezterm-{windows,macos}.md` (W2, W18, новый пункт про правый Alt).
- Документы: docs/WEZTERM.md (таблицы шрифта, «Только macOS», раздел о том, что отдано nvim), nvim_forge/HOTKEYS.md, nvim_forge/KEYBINDINGS.md (в том числе строки `<C-q>`); nvim_forge/FIXLOG.md.
- Порядок: этот change архивируется раньше `add-nvim-chords-on-windows` (его delta написана поверх этой); WT-STATE-7 меняет и `fix-window-state-new-windows`.
- Вне охвата: другие F-клавиши с модификаторами (`<S-F5>`, `<C-F5>`, `<S-F11>` и т. п. приходят как `<F13>`–`<F48>`). Это спека клавиш nvim_forge, её пока нет; кандидат в PROBLEMS.md.
