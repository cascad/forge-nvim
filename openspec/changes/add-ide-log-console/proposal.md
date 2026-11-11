# Proposal

## Why

IDE-106: владелец не может из одного места понять, что в IDE сломалось или
не найдено. Уведомления, :messages, health и native журналы подсистем сейчас
разнесены; ранние ошибки не попадают в lazy-loaded Fidget history.

## What Changes

- Добавить общую консоль IDE Logs в существующий bottom slot, Space w i и
  :ForgeLogs. Общие focus/hide/help/zoom сохраняются.
- Сохранять ограниченную хронологию сообщений с временем/уровнем/источником,
  включая early startup, native ошибки и direct Fidget notifications.
- Дать из консоли доступ к штатным подробным журналам Neovim/LSP/DAP/Conform/
  Neotest/Neogit/Overseer/Mason/Fidget, текущим output buffers и health.
- Различать источник без записей, отсутствующий файл и отключённый источник;
  показать путь и действие. Поиск/фильтры/детали/копирование отчёта с клавиатуры.
- Просмотр пассивный: без установки, запуска tools/jobs и изменения log level.
  Ограничить хранение, обозначить session boundary, не собирать env/options data.
- IDE-107: поздний возврат после failed F5 сохраняет новую выбранную панель;
  controlled native callback regression воспроизводит прежнюю Problems на source84.
- Добавить permanent real editor E2E Windows/Ubuntu и отдельный native Mac/GUI gate.

## Capabilities

### New Capabilities

- `ide-log-console`: IDE-LOG-1/2/3/4 — общий доступ, причины/источники,
  поиск/панели, bounded passive history.

### Modified Capabilities

Нет: main specs пока описывают WezTerm/macOS installer; Neovim требования
в других changes не переписываются.

## Impact

Общий early message capture, native sources facade и console view;
существующие ide registry/controls/Edgy/keymaps, direct Fidget update_hook.
Новые плагины, LSP/backend, SDK или pins не нужны. Native логи остаются
у исходных владельцев; подробные project output не дублируются на диск.
OpenSpec/docs/FIXLOG/HISTORY/commands и тесты обновляются вместе с runtime.
