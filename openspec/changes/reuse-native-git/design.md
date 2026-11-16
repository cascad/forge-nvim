# Design

## Context

См. proposal.md. sdks.rs уже содержит PATH discovery/bounded2s version probes; sdk_actions/sdk_install — меню/команды менеджеров и явные подтверждения. Core всегда выбран. Private runtime/launcher уже наследуют обычные HOME/GIT*/SSH* и сохраняют внешние fallback paths.

## Goals / Non-Goals

Goals: reuse native Git и ранний prerequisite gate, общий проверенный механизм действий, читаемый tool report.

Non-Goals: private Git/archive, изменение credentials/config/core.editor, реальные host installs в тестах, Terminal/full Default, обновление SDK/Neovim/locks.

## Decisions

- Git — обязательный Core tool, не языковой SDK. Его report/UI отделены; --check-sdks остаётся языковым, --check-tools проверяет Git. --tool-path — понятный alias существующего fallback механизма; внутреннее sdk-paths.txt сохраняется для совместимости.
- Discovery/version/manager код общий. Action context меняет подписи и убирает skip для Git; SDK flow сохраняет прежний контракт. Root/bin/cmd учитываются при выборе Git.
- Gate перед execute/download, preview и print-plan probe не выполняют. PATH приоритет сохраняется; явно выбранный fallback хранится только в owned kit и наследуется дочерним fride, user/system PATH не пишется.
- Recipes: Git.Git через WinGet, git через Homebrew/APT; no-upgrade и прежняя отдельная manager bootstrap confirmation. Native managers в E2E заменяются контролируемыми executable fixtures, реальный Git отдельно подтверждает configuration/launcher.
- На Mac /usr/bin/git shim предварительно проверяется read-only xcode-select --print-path с тем же bounded runner; Developer Tools installer не запускается. Native Mac остаётся owner gate.

## Risks / Trade-offs

- Новый обязательный tool меняет prerequisites чистого Core → обновить setup fixtures, скрывающие SDK PATH, чтобы они предоставляли Git отдельно; не обходить новый gate.
- Менеджер может изменить системные зависимости → команда видна/подтверждается пользователем; реальная установка не выполняется агентом в тестах.
- PATH содержит broken Git раньше выбранного fallback → приоритет пользователя сохраняется; recheck сообщает причину, PATH исправляется пользователем.
