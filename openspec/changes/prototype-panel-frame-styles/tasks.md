# Tasks

## 1. Native UI preview tooling

- [x] 1.1 Реализовать opt-in bounded raw UI capture и stdlib replay/SVG/HTML, проверить UTF8/wide/RGB/scroll/resize, cap failure без потери RPC и default off настоящими E2E Windows/Ubuntu; protocol vectors проверяются отдельно, ошибки не маскируются.
- [x] 1.2 Добавить явный test-only Locals preview и native DAP E2E: baseline/полная рамка/compact/active/dim/help/resize/restore, та же pause/stdout; Windows/Ubuntu artifacts и visual review, при stop восстановлены options/functions/highlights. Default style/SDK/pins прежние; placement fix отдельный IDE-PANEL-18.
- [x] 1.3 Проверить соседние debug/tool panels и quick/trace/strict; source/exit/scope/byte-prefix audit, документы/сравнение, FIXLOG/HISTORY/команды и самостоятельный commit. Windows temp на F:, Desktop/WSL не управлять.
- [ ] 1.4 Показать владельцу результат и отдельно выбрать реализацию постоянных рамок для обычных split; native Mac/physical GUI проверить на целевых машинах. До этих решений IDE-076 целиком не закрывать и change не архивировать.
