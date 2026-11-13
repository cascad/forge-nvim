# Design

## Context

Два go env и dlv version используют vim.fn.system. Explicit info вызывает
unique candidates и затем resolve, который повторяет весь обход. Native Go
adapter callback синхронен в закреплённом dap-go, вызывается из coroutine DAP;
явная user command начинается на main thread.

## Goals / Non-Goals

**Goals:** async metadata, один Go env JSON и один список для info; сохранить
готовые plugins, version sorting/overrides, startup0 и настоящий debug.

**Non-Goals:** новая система tool discovery/cache, изменение SDK selection
для сборки/debug, отмена активной сессии или Windows-only resolver.

## Decisions

Один local await helper вокруг vim.system; native dap.async.run обеспечивает
coroutine в command и adapter callback, без собственного менеджера. Go env
получает -json GOBIN GOPATH, metadata subprocess получает GOTOOLCHAIN=local.
Действующий глобальный env не меняется. Выбор по версии прежний, resolve может
получить уже собранный список из info. Spawn/неуспешный probe даёт прежний
unknown/missing fallback, а не новый installer.

Existing go-passive observer расширяется на native Delve version и held Go
env callback. Реальные stdout/exit не подменяются. Исходная версия подтверждает
sync boundary; target проверяет input, фактический результат, отсутствие дублей.
Отдельные controls: passive edit и первый/повторный debug/output. Windows и
Ubuntu serial, только готовые SDK. Native Windows .cmd smoke уже показал,
что vim.system и прежний vim.fn.system запускают owned shim с Unicode/space;
новая shell boundary не нужна.

## Risks / Trade-offs

Command завершается позднее, но ввод доступен. Metadata не выбирает SDK
проекта; запуск Go debug продолжает использовать явный GOTOOLCHAIN. Это не
доказательство исправления Mac shell startup или всех зависаний. Mac/physical
и большие рабочие проекты остаются отдельными отложенными проверками.
