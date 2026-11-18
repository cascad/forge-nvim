# Design

## Context

См. proposal. Core acceptance уже различает installed kit и prepared native
config; подменять один результат другим или пропускать suite нельзя.

## Goals / Non-Goals

**Goals:** корректный argv, видимый режим Core проверки, быстрый отказ до
массового запуска при отсутствии входов, прежний состав полного regression.

**Non-Goals:** подготовка SDK/Core, скачивания, изменение Core acceptance,
тяжёлый полный regression, выбор порядка Core/frontend SDK preflight.

## Decisions

- FORGE_CORE_TEST_KIT + FORGE_CORE_TEST_PROFILE задают installed mode.
  FORGE_CORE_TEST_RUNTIME + existing FORGE_E2E_DEPS задают source mode.
  Приоритет installed mode; частично заданная пара считается ошибкой входов.
- Plan показывает core_mode, missing_inputs и ready. --plan остаётся read-only
  просмотром с exit0; actual run с missing inputs возвращает2 до любого command.
- Проверки файлов только предварительные. Истинные ownership/hash/LSP/workflow
  postconditions сохраняются в Core acceptance; source mode не называется
  доказательством готовности installed kit.

## Risks / Trade-offs

- Полный прогон требует подготовленных inputs → перечисляем их заранее вместо
  позднего argparse FAIL после длительного исполнения других suites.
