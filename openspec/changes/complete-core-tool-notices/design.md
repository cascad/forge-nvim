# Design

## Context

Actual Core baseline:101 items, version_missing LuaLS и missing document StyLua. См. proposal и native Mason InstallReceipt:get_installed_package_version.

## Goals / Non-Goals

Закрыть эти два доказанных gaps. Не менять Mason/SDK/pins/installed roots и не выдавать metadata отчёт за release/юридическую полноту.

## Decisions

- Existing native catalog helper получает JSON список explicit receipt paths и возвращает read-only results через pinned Mason InstallReceipt. Никаких registry.setup/refresh/SDK/tool calls.
- Повторно использовать существующий bounded GitHub document fetch по source/revision и report cache. GitHub PURL передаёт точный source/version; неподдержанные source types остаются с gap, не угадываются.
- Bundled documents имеют приоритет. Cached docs проверяют source/version/SHA; относительные nested paths сохраняются. Existing output/input directories не изменяются.
- CLI regressions используют настоящие Neovim/Mason API и controlled metadata fixtures; отдельно network-opt-in case и actual publisher Core input report.

## Risks / Trade-offs

- Upstream release может не содержать требуемых материалов → конкретный gap; ни SPDX, ни transitive completeness не угадываются.
- Network unavailable → explicit fetch failure/gap; offline previous-report cache отдельно проверяется.

## Migration Plan

Пересоздать report в новом каталоге с явным fetch, дальше использовать его как offline cache. Installer/runtime не меняются; baseline specs не sync/archive.
