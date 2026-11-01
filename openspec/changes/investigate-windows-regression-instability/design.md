# Design

## Context

IDE-027 снова воспроизведён обоими existing IDE-BUF-1 сценариями на HEAD 25dfbab. Чистый Neovim без дополнительного resize прошёл 50 циклов; с scheduled resize во время завершения команды падает на первом цикле. Windows Debug API зафиксировал второе исключение 0xC0000005 в nvim.exe!pty_proc_resize+0x1a (нулевое чтение). Версия 0.12.5 также падала с Forge, обновление само по себе не доказало исправления.

## Goals / Non-Goals

**Goals:** воспроизводимый core probe, подтверждение границы ConPTY lifecycle и проверка кандидата в private SDK, диагностируемые CLI timeout, полная история и команды на F:.

**Non-Goals:** замена установленной программы/глобального PATH, Windows-only обходы в общем Lua UI, ослабление timeout/тестов, публикация сообщения upstream без поручения, объявление Mac/GUI проверенными.

## Decisions

- После A/B official/upstream red и candidate 50 циклов + 8 buffer E2E green владелец выбрал временный Windows SDK. IDE-BOOT-3 добавлен в delta. Официальные Linux/macOS SDK остаются без патча.
- SDK готовится только отдельной командой, исходники зафиксированы commit SHA, единственный patch проверяется. Build tools нужны builder-машине. Runtime в .tools/neovim/windows-x64; source/build/temp на диске checkout в .tests. Manifest содержит source/patch/binary hash, launcher сверяет их с lock. Нет сети/сборки на старте.
- nvim_forge.cmd и scripts/test.ps1 используют один проверяющий Windows resolver. Без подготовленного/валидного SDK — понятная ошибка с командой подготовки. FORGE_NVIM=system — явный диагностический запуск системного Neovim; по умолчанию скрытого fallback нет. Прямой nvim и установленный системный конфиг не перенастраиваются.
- Core probe использует настоящий --clean --embed Neovim с RPC UI, терминальную команду echo и public window resize во время её завершения. Пассивный режим — контроль; плагины не загружаются. Все пути/маркер cleanup берутся из общего editor_runtime.
- В ConPTY закрытие запускает отдельный поток, а main thread вызывает uv_run, пока ждёт финальный frame. Опубликованный conpty pointer должен стать недоступным resize до запуска free thread; поздний resize при NULL должен быть no-op. Проверить этот кандидат в отдельном source checkout/build, сохранив официальный binary в системе.
- Нативный debugger необходим только для расследования; attach менял timing и давал зелёные повторы, поэтому окончательный core probe выполняется без debugger. Неудачные варианты mappings/UI-плагинов/версии сохраняются как отвергнутые гипотезы, не как исправления.
- CLI timeout изучается с прежними 10 секундами. Добавлять артефакты времени/stdout/stderr/pid при повторе; отсутствие повтора не закрывает IDE-031.
- Полный Windows выявил независимые IDE-032 (E211/блокировка после удаления открытого worktree) и IDE-033 (старый ConPTY набор запускал source config с user plugins и менял lock). IDE-032 внесён в очередь с красным full и двумя отдельными зелёными повторами. IDE-033 исправляется здесь как необходимая граница полноценной проверки SDK: отдельный профиль с pinned plugins, actual child stdpath и инвариант исходного lock, SDK передаётся из runner явно.

## Risks / Trade-offs

- Сборка ядра может требовать внешних pinned dependencies → отдельный F: checkout/build и явные команды, без startup download IDE.
- Собственный SDK — стоимость поддержки → pinned patch и явная подготовка; после подтверждённого upstream исправления убрать Windows patch/SDK отдельным change. Полный Windows регресс выполняется выбранным SDK.
- Helper/debugger может менять timing → red/green только без attach, исходные сценарии сохраняются.
- Core probe должен ловить реальный crash → assert process exit и stderr/UI artifacts, не пропускать known failure как PASS.
