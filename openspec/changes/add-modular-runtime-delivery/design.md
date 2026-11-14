## Context

См. proposal.md. Готовы native UI, private backend и упаковщик schema1 full runtime. Catalog ещё отсутствует, UI передаёт только явный RuntimePath/URL. Legacy macos-install spec описывает отдельный system API; он не меняется.

## Goals / Non-Goals

Goals: автоматическое получение selected частей и проверяемая сборка в существующем staging; runtime/parts manifests; реальные Windows/Ubuntu install/launch с готовым executable модуля.
Non-Goals: публикация assets, сборка всего SDK инвентаря, новые LSP, global package manager/WSL lifecycle, actual Mason readiness. Native Mac остаётся отдельным gate.

## Decisions

- Catalog scripts/runtime/artifacts.tsv: platform, component, URL, SHA256. Core первым, остальные по canonical closure из прежней TSV. Отсутствующий выбранный artifact — ошибка до backend; preview не требует каталога. Один full archive на все комбинации Custom отвергнут: лишний download и экспонента вариантов.
- Frontend сохраняет выбранные rows в собственном log directory после подтверждения, передаёт RuntimePlanPath существующему backend. PS/Bash читают простой TSV без jq/Python/добавления downloader dependencies Rust. Explicit runtime не использует plan.
- Shell transport переиспользует SHA/extraction cache для каждой части. Только Core bootstrap запускает native Neovim. Общий Lua проверяет component manifests и все деревья, объединяет без перекрывающихся файлов в private staging, проверяет probes тем же native путём. Предыдущий kit до setup/publication сохраняется.
- Full core forge-runtime.json schema1 остаётся прежним. Optional archive имеет forge-component.json schema1/kind component/один component/platform/paths/probes/files. Packager получает --component и создаёт receipt; shell не выдаёт успешный download за readiness.
- Получение/создание настоящих release language bundles — следующий продуктовый срез. Stand использует настоящий private Neovim и доступный Node executable; init/setup fixture явно обозначены.

## Risks / Trade-offs

- [Catalog пока без release rows] → localhost native stand и явный missing diagnostic; не объявлять public one-liner готовым.
- [Одинаковый файл в двух модулях] → конфликт до target, общие executable выносятся в dependency component.
- [Native Mac не доступен] → те же команды из репозитория, Linux не считается Mac PASS.

## Migration Plan

Explicit RuntimePath/URL и старые полные bundles не меняются. Новые optional archives можно публиковать независимо по platform/component. Catalog содержит только подготовленные проверенные артефакты; обратная совместимость проверяется targeted stand.
