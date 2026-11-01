# Proposal

## Why

IDE-028 нарушает IDE-GIT-3: быстрый visit между worktree с разными HEAD даёт `No commit found for oid` в Neogit log.lua:218. В активной базовой линии git-workflow обычный путь уже проверен, но ждёт Head перед следующей операцией и скрывает гонку; нужна безопасная работа без такого ожидания.

## What Changes

- История и её граф должны относиться к одному снимку Git даже при смене worktree во время refresh.
- Использовать штатный Unicode renderer Neogit, строящий граф из уже полученных commit; проверить это исправление real Git gate и естественными быстрыми visit.
- Проверить конечные cwd/Head/recent/log, сохранность файлов и Git index; не подавлять backend ошибки.
- Записать red/green, причину и ограничения в FIXLOG/HISTORY, команды и roadmap.

## Capabilities

### New Capabilities

- `git-workflow`: IDE-GIT-6 — быстрое переключение рабочих папок и согласованная история; дополнение активной базовой линии integrate-git-workflow, ещё не перенесённой в main specs.

### Modified Capabilities

Нет: в openspec/specs сейчас только WezTerm и macOS installer.

## Impact

Общие настройки Neogit в nvim_forge/lua/plugins/git.lua, новый e2e и прозрачная Git-прокладка через public git_executable только в private test config, registry и документация. Системные различия ограничены wrapper launcher Windows/POSIX. Pin зависимостей сохраняется; собственный Git backend и monkey patch Neogit не вводятся. IDE-027, push/merge/rebase ошибки и Mac-проверка остаются отдельной работой.
