# Tasks

## 1. Диагностический инструментарий

- [x] 1.1 Добавить и запустить read-only ancestry audit: native metadata, unknown/kernel edges различены, output на F:, без signal/termination APIs.
- [x] 1.2 Добавить pinned-source native harness/build: valid upstream PASS, stale и query-failure source RED; guard prototype 4 PASS, все workers принадлежат private Job/allowlist, отчёты/creation times/SHA сохранены. ASCII/Unicode final runs по 8 executions/24 cleaned workers; SDK hash неизменен.
- [x] 1.3 Обновить WINDOWS_PROCESS_DIAGNOSTICS/README/ROADMAP/PROBLEMS, append-only FIXLOG §158 / HISTORY / AGENT_COMMANDS §70; разграничить conditional native proof, полный SDK E2E и неизвестный Docker caller, проверить prefix SHA.

## 2. Интеграция

- [x] 2.1 Strict OpenSpec 74/74 и diff check проходят, production Lua/SDK/pins неизменны, диагностический срез закоммичен; Windows ABI gates не приписываются Linux/macOS.
