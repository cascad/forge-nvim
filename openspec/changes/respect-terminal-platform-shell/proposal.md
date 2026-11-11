# Proposal

## Why

IDE-102 найден в проверке переносимости Terminal (IDE-009/080):
plugins/terminal.lua обещает pwsh только на Windows, но без проверки ОС
выбирает его везде, где executable('pwsh')==1. На macOS/Linux с установленным
PowerShell обычный managed terminal поэтому подменяет настроенный vim.o.shell.
Это расходится с принятой универсальной сборкой и текущим комментарием.
IDE-PANEL-19 закрепит границу выбора shell; исходное воспроизведение должно
запустить реальный ToggleTerm с optional pwsh рядом с POSIX shell.

## What Changes

- Ограничить существующее предпочтение pwsh -NoLogo Windows-платформой.
- На POSIX сохранять выбранный при старте vim.o.shell даже при наличии pwsh.
- На Windows оставить прежнее предпочтение и fallback без pwsh; jobs,
  common controls и история терминала сохраняются.
- Постоянный native E2E shell policy: POSIX optional pwsh/fallback и Windows
  preference/fallback, actual process/command side effects и hide/reopen.
  Source RED и controls на immutable2fb9f8d, затем Windows/Ubuntu serial
  regression, FIXLOG/HISTORY/команды и самостоятельный commit.

## Capabilities

### New Capabilities

- `terminal-platform-shell`: IDE-PANEL-19, выбор интерактивного shell на
  границе Terminal с сохранением его работы через общие controls.

### Modified Capabilities

Нет: main nvim baseline ещё не снят; прежние IDE-PANEL-1…18 сохраняются.

## Impact

Одна OS-проверка в plugins/terminal.lua, native E2E/registry, документация и
история. Без нового platform framework, shell wrapper в продукте, плагинов,
SDK/pins/setup изменений. Windows temp на F:, Mac/GUI требуют реального
отдельного запуска. Уже запущенный Docker engine можно использовать;
Desktop/WSL lifecycle не управляется.
