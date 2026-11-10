# Tasks

## 1. Канал Output

- [x] 1.1 Добавить native dap-output-policy E2E, сохранить исходный Windows RED и источники до runtime fix.
- [x] 1.2 Перенести resolver, связать manual open/focus и passive PTY reuse; Windows: 19 новых/targeted checks PASS, включая Go/Rust/Python/Node, dap-output/debug-panels/test-runner и default language F5.
- [x] 1.3 Обновить руководство, review, PROBLEMS/ROADMAP, append-only FIXLOG §153/154 / HISTORY / AGENT_COMMANDS §67; проверить prefix SHA и diff, объяснить ошибочное имя Dv в прежнем обзоре.

## 2. Интеграция

- [x] 2.1 Windows quick, strict OpenSpec, native exit/API errors/scopes всех новых и targeted прогонов проверены, завершённый шаг закоммичен.
- [x] 2.2 Повторить те же 19 checks на Ubuntu при доступном Linux engine, проверить sources/exit/API errors/scopes: 19 PASS, 13 clean profiles. Первый unavailable run сохранён отдельно; после включения владельцем повтор прошёл. Desktop/WSL агент не перезапускает.
- [ ] 2.3 Native macOS E2E и физические клавиши WezTerm проверены владельцем; до результата change не архивировать.
