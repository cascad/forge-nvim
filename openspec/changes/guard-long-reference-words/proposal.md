# Proposal

## Why

IDE-041: открытие слова 512 КиБ приводит к E339 и hit-enter/RPC timeout.
Actual pinned vim-illuminate regex provider воспроизводит E339 при match_line;
простая компиляция vim.regex ещё проходит. Сборка должна сохранять редактирование
таких файлов и обычные переходы по коротким словам (новый IDE-HL-1).

## What Changes

- Общий ресурсный предел подсветки слова: 4096 UTF-8 bytes. На более длинном
  слове отключается только подсветка вхождений; редактирование остаётся доступно.
- Использовать публичный should_enable vim-illuminate, общий callback и для
  large_file_overrides; существующее исключение внешних Rust буферов сохранить.
- Проверить большой token, возврат к обычному слову, границу 4096/4097 bytes,
  файл 5000+ строк и длинную строку с короткими Unicode словами.
- Сохранить настоящий UI RED и E2E Windows/Ubuntu, историю и инструкцию.

## Capabilities

### New Capabilities

- `editor-highlighting`: IDE-HL-1, ограниченная по размеру слова подсветка
  вхождений с сохранением редактирования/переходов.

### Modified Capabilities

Нет: main specs редактора ещё не сняты; существующей highlighting capability
в main/changes нет. Prefix IDE-HL добавляется в контекст проекта.

## Impact

Общий config vim-illuminate в plugins/ide.lua, новый editor E2E/registry,
QUICKSTART/README и FIXLOG/HISTORY/roadmap/commands. Pin/SDK/установка и
платформенные адаптеры не меняются; новый backport и зависимости не нужны.
