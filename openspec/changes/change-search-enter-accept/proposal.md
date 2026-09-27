# Proposal

## Why

Enter в search mode не принимает шаблон (WT-SCROLL-10, divergence 35 сверки базовой линии). Сейчас на Enter висит `CopyMode(PriorMatch)` из встроенной таблицы WezTerm 20240203: выделение прыгает на совпадение выше, строка ввода остаётся активной, и следующая `n` дописывается в шаблон. Владелец решил (решение №3): Enter принимает шаблон и возвращает в copy mode на совпадении, как Enter после `/` в vim. Комментарий `wezterm.lua:531-535` и раздел «Поиск» в `docs/WEZTERM.md` («`Enter` — вернуться в copy mode на совпадении») уже описывают это поведение, а код ему не следует.

Как воспроизвести: Ctrl+Shift+X → `/` → набрать `error` → Enter. Индикатор остаётся SEARCH, выделение уходит на вхождение выше, а `n` превращает шаблон в `errorn`. Статически: `wezterm --config-file wezterm.lua show-keys --lua --key-table search_mode` выдаёт `{ key = 'Enter', mods = 'NONE', action = act.CopyMode 'PriorMatch' }`.

Где в коде: `wezterm.lua:514-529`. Таблица search_mode берётся из `wezterm.gui.default_key_tables()` и только переводится на физические клавиши, Enter не переопределяется. Действие `CopyMode("AcceptPattern")` в 20240203 есть (`wezterm-gui/src/overlay/copy.rs`, `accept_pattern`), но ни на одну клавишу не привязано.

## What Changes

- Enter в search mode принимает шаблон. Search mode сменяется copy mode, курсор стоит на текущем совпадении, совпадение выделено, `n` и `N` ходят по совпадениям шаблона, строка с шаблоном остаётся видна. Так же работает поиск, открытый клавишей `f` из режима WINDOWS. Если совпадений нет, Enter просто переводит панель в copy mode.
- ↑ и Ctrl+P в search mode по-прежнему ведут к совпадению выше. Enter больше не дублирует их.
- Не меняются: Esc в search mode (WT-SCROLL-11, закрывает поиск вместе с copy mode), PageUp и PageDown (WT-SCROLL-15), переход из поиска в copy mode по Ctrl+Shift+X (WT-SCROLL-11).
- В `tests/` появляется проверка: в таблице search_mode, которую видит WezTerm, ровно одна запись Enter, и это `CopyMode 'AcceptPattern'`.
- В `nvim_forge/FIXLOG.md` дописывается запись со строкой `Спека: WT-SCROLL-10 (MODIFIED)`. Раздел «Поиск» в `docs/WEZTERM.md` сверяется с новым требованием.

## Capabilities

### New Capabilities

Нет.

### Modified Capabilities

- `wezterm-scrollback`: WT-SCROLL-10 «Search mode: Enter». Enter принимает шаблон и переводит в copy mode на текущем совпадении, а не прыгает к совпадению выше, оставаясь в поиске.

## Impact

- `wezterm.lua`: сборка `config.key_tables.search_mode` после перевода встроенных таблиц на `phys:` (заменяется одна запись) и комментарий к поиску (`wezterm.lua:531-535`), который после правки станет верным.
- `tests/`: новый сценарий проверки таблицы search_mode.
- Документы: `docs/WEZTERM.md`, раздел «Поиск» (сверка, при расхождении — правка); `nvim_forge/FIXLOG.md` (новая запись).
- Соседние changes: `fix-windows-mode-modality` описывает режим WINDOWS поверх search mode (WT-WIN-21), `fix-copy-clobbers-clipboard` меняет `y` в copy mode (WT-SCROLL-7), `sync-docs-with-baseline` переписывает тот же раздел docs. Требования в их delta с этим change не пересекаются.
