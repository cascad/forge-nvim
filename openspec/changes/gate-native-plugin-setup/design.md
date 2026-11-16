# Design

## Context

См. proposal: cold Windows Core оставил grug-far.nvim отсутствующим и потерял его pin. Lazy restore не ставит missing plugins, а native команды не бросают Lua exception при task errors.

## Goals / Non-Goals

Проверить actual Lazy результат и сохранить lock. Не заменять Lazy/Mason, не менять pins/SDKs, не расширять release catalog и не объявлять Default/Mac готовыми.

## Decisions

- Supported install.missing=false исключает startup install loop. Explicit plugins stage вызывает native install с lockfile=true, затем restore, проверяя задачи после каждого шага.
- Маленький forge.plugin_setup сохраняет исходный lock до native операций и возвращает байты после любых исходов. Проверка использует pinned Lazy task errors и Git.info HEAD; вывод содержит plugin/reason. Чтение stdout regex ненадёжно, только exit команды недостаточен.
- GIT_CONFIG_COUNT append с core.longpaths=true действует только во время explicit Windows prepare и восстанавливается через protected call; не используем git config --global и не меняем launcher SDK environment.
- Offline regression использует настоящий pinned Lazy, native Git repos/checkout/build и private profiles. Actual Core проверяется отдельно без подмен конфигурации/стадий.

## Risks / Trade-offs

- Pinned Lazy API меняется при upgrade → regression проверяет native install/errors и pins.
- Cold install зависит от сети → explicit preparation bounded, offline regression самостоятельный.
- Native Mac/Ubuntu acceptance зависит от готовых платформенных inputs → отдельный статус, не заменять fixture успехом.

## Migration Plan

Повторить явную установку из исправленного source; обычный запуск ничего не достраивает. Прежний kit остаётся защищён staging/rollback при отказе. Baseline specs не синхронизировать.
