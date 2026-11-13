# Design

## Context

Resolver сам собирает список целей по Cargo JSON и использует native DAP
coroutine только для неоднозначного выбора. Upstream eval_option поддерживает
coroutine для всего program, а preLaunchTask уже передан Overseer.

## Goals / Non-Goals

**Goals:** убрать sync subprocess при program resolution, сохранить выбор,
ошибки/ABORT и не применять результат к сменившемуся проекту.

**Non-Goals:** новый Cargo cache, backend, task runner, общая система root,
изменение build/toolchain policy и отказ от существующих native plugins.

## Decisions

Весь resolver — native coroutine option. `vim.system` получает реальные Cargo
аргументы/cwd и доставляет результат через vim.schedule; existing selection
правила используют один completion callback. Перед доставкой проверяется
захваченный cwd. Ошибки spawn/exit/JSON/отсутствия цели заканчиваются ABORT.
Отдельного менеджера процессов/сессий не добавляем.

Native E2E observer считает настоящий sync metadata и удерживает только
callback завершившегося настоящего async процесса. JSON/exit/stdout не
подменяются. Source c4e44b8 отказывает на sync path. Target использует реальный
F5/Current Rust file bin и отменяет native picker; producer stack отделяет
metadata program от независимых LSP запросов. IDE-DAP-7 отдельно сохраняет
настоящий build/launch/breakpoint/output.

## Risks / Trade-offs

Metadata дольше не останавливает клавиатуру; async результат требует guard cwd.
Native pending Cargo живёт до завершения процесса; lifecycle тестового профиля
остаётся под existing scope. Отмена запущенного debugger не меняется.
Mac/большой рабочий проект отложены явно. Пара маленьких reference cases
выполняется serial с готовыми SDK, без полного language suite или загрузок.
